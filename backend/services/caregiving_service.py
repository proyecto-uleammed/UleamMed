from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import secrets
import string

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from backend.core.caregiving import CaregiverLinkStatus
from backend.core.config import settings
from backend.core.roles import UserRole
from backend.models.caregiver_invitation import CaregiverInvitation
from backend.models.caregiver_join_attempt import CaregiverJoinAttempt
from backend.models.patient_caregiver_link import PatientCaregiverLink
from backend.models.user import User
from backend.schemas.caregiving import (
    CaregiverInvitationRead,
    CaregiverLinkRead,
    CaregiverPatientRead,
)
from backend.schemas.appointment import (
    AppointmentCreate,
    AppointmentRead,
    AppointmentUpdate,
)
from backend.schemas.medication import (
    MedicationCreate,
    MedicationDoseEventCreate,
    MedicationDoseEventRead,
    MedicationRead,
    MedicationUpdate,
)
from backend.services.appointment_service import (
    create_user_appointment,
    delete_user_appointment,
    list_user_appointments,
    update_user_appointment,
)
from backend.services.medication_service import (
    create_user_medication,
    delete_user_medication,
    get_user_medication_model,
    list_deleted_user_medications,
    list_dose_events,
    list_user_medications,
    record_dose_event,
    restore_user_medication,
    update_user_medication,
)


_CODE_ALPHABET = string.ascii_uppercase.replace("I", "").replace("O", "") + "23456789"


class InvalidInvitationCodeError(ValueError):
    pass


class CaregiverRateLimitError(ValueError):
    pass


class CaregiverLinkNotFoundError(ValueError):
    pass


class CaregiverLinkStateError(ValueError):
    pass


def create_invitation(db: Session, patient: User) -> CaregiverInvitationRead:
    """Genera un codigo temporal y cancela codigos anteriores sin usar."""
    now = datetime.now(UTC)
    active_invitations = db.scalars(
        select(CaregiverInvitation).where(
            CaregiverInvitation.patient_user_id == patient.id,
            CaregiverInvitation.redeemed_at.is_(None),
            CaregiverInvitation.canceled_at.is_(None),
        )
    ).all()
    for invitation in active_invitations:
        invitation.canceled_at = now

    code = _generate_unique_code(db)
    invitation = CaregiverInvitation(
        patient_user_id=patient.id,
        code_digest=_digest_code(code),
        expires_at=now + timedelta(hours=settings.CAREGIVER_INVITATION_EXPIRE_HOURS),
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)
    return CaregiverInvitationRead(
        id=invitation.id,
        code=_display_code(code),
        expires_at=invitation.expires_at,
    )


def cancel_invitation(db: Session, patient_id: int, invitation_id: int) -> bool:
    """Cancela un codigo pendiente perteneciente al paciente."""
    invitation = db.scalar(
        select(CaregiverInvitation).where(
            CaregiverInvitation.id == invitation_id,
            CaregiverInvitation.patient_user_id == patient_id,
            CaregiverInvitation.redeemed_at.is_(None),
            CaregiverInvitation.canceled_at.is_(None),
        )
    )
    if invitation is None:
        return False

    invitation.canceled_at = datetime.now(UTC)
    db.add(invitation)
    db.commit()
    return True


def redeem_invitation(
    db: Session,
    caregiver: User,
    code: str,
) -> CaregiverLinkRead:
    """Consume un codigo valido y crea una solicitud pendiente."""
    now = datetime.now(UTC)
    _enforce_attempt_limit(db, caregiver.id, now)

    normalized_code = _normalize_code(code)
    invitation = db.scalar(
        select(CaregiverInvitation)
        .where(CaregiverInvitation.code_digest == _digest_code(normalized_code))
        .with_for_update()
    )
    if invitation is None or not _invitation_is_available(invitation, now):
        _record_attempt(db, caregiver.id, successful=False)
        raise InvalidInvitationCodeError("Codigo invalido o expirado")

    patient = db.get(User, invitation.patient_user_id)
    if patient is None or not patient.is_active or patient.role != UserRole.PATIENT:
        _record_attempt(db, caregiver.id, successful=False)
        raise InvalidInvitationCodeError("Codigo invalido o expirado")

    if patient.id == caregiver.id:
        _record_attempt(db, caregiver.id, successful=False)
        raise InvalidInvitationCodeError("Codigo invalido o expirado")

    link = db.scalar(
        select(PatientCaregiverLink).where(
            PatientCaregiverLink.patient_user_id == patient.id,
            PatientCaregiverLink.caregiver_user_id == caregiver.id,
        )
    )
    if link is not None and link.status == CaregiverLinkStatus.ACTIVE:
        invitation.canceled_at = now
        db.add(invitation)
        db.commit()
        raise CaregiverLinkStateError("Ya tienes acceso activo a este paciente")

    if link is None:
        link = PatientCaregiverLink(
            patient_user_id=patient.id,
            caregiver_user_id=caregiver.id,
            status=CaregiverLinkStatus.PENDING,
            requested_at=now,
        )
    else:
        link.status = CaregiverLinkStatus.PENDING
        link.requested_at = now
        link.decided_at = None
        link.revoked_at = None

    invitation.redeemed_at = now
    invitation.redeemed_by_user_id = caregiver.id
    db.add(invitation)
    db.add(link)
    db.add(
        CaregiverJoinAttempt(
            caregiver_user_id=caregiver.id,
            attempted_at=now,
            successful=True,
        )
    )
    db.commit()
    db.refresh(link)
    return _link_to_read(link, patient)


def list_links(db: Session, current_user: User) -> list[CaregiverLinkRead]:
    """Lista solicitudes y vinculos desde la perspectiva del usuario."""
    if current_user.role == UserRole.PATIENT:
        statement = (
            select(PatientCaregiverLink, User)
            .join(User, User.id == PatientCaregiverLink.caregiver_user_id)
            .where(PatientCaregiverLink.patient_user_id == current_user.id)
        )
    elif current_user.role == UserRole.CAREGIVER:
        statement = (
            select(PatientCaregiverLink, User)
            .join(User, User.id == PatientCaregiverLink.patient_user_id)
            .where(PatientCaregiverLink.caregiver_user_id == current_user.id)
        )
    else:
        return []

    statement = statement.order_by(PatientCaregiverLink.requested_at.desc())
    return [_link_to_read(link, counterpart) for link, counterpart in db.execute(statement)]


def approve_link(
    db: Session,
    patient_id: int,
    link_id: int,
) -> CaregiverLinkRead:
    """Activa una solicitud pendiente propiedad del paciente."""
    link = _get_patient_link(db, patient_id, link_id)
    if link is None:
        raise CaregiverLinkNotFoundError("Solicitud no encontrada")
    if link.status != CaregiverLinkStatus.PENDING:
        raise CaregiverLinkStateError("La solicitud ya fue procesada")

    caregiver = db.get(User, link.caregiver_user_id)
    if caregiver is None or not caregiver.is_active or caregiver.role != UserRole.CAREGIVER:
        raise CaregiverLinkStateError("La cuenta del cuidador no esta disponible")

    link.status = CaregiverLinkStatus.ACTIVE
    link.decided_at = datetime.now(UTC)
    link.revoked_at = None
    db.add(link)
    db.commit()
    db.refresh(link)
    return _link_to_read(link, caregiver)


def reject_link(
    db: Session,
    patient_id: int,
    link_id: int,
) -> CaregiverLinkRead:
    """Rechaza una solicitud pendiente propiedad del paciente."""
    link = _get_patient_link(db, patient_id, link_id)
    if link is None:
        raise CaregiverLinkNotFoundError("Solicitud no encontrada")
    if link.status != CaregiverLinkStatus.PENDING:
        raise CaregiverLinkStateError("La solicitud ya fue procesada")

    caregiver = db.get(User, link.caregiver_user_id)
    if caregiver is None:
        raise CaregiverLinkNotFoundError("Solicitud no encontrada")

    link.status = CaregiverLinkStatus.REJECTED
    link.decided_at = datetime.now(UTC)
    link.revoked_at = None
    db.add(link)
    db.commit()
    db.refresh(link)
    return _link_to_read(link, caregiver)


def revoke_link(db: Session, patient_id: int, link_id: int) -> bool:
    """Revoca una solicitud pendiente o un vinculo activo."""
    link = _get_patient_link(db, patient_id, link_id)
    if link is None:
        return False
    if link.status not in {
        CaregiverLinkStatus.PENDING,
        CaregiverLinkStatus.ACTIVE,
    }:
        raise CaregiverLinkStateError("El vinculo ya no esta activo")

    now = datetime.now(UTC)
    link.status = CaregiverLinkStatus.REVOKED
    link.decided_at = link.decided_at or now
    link.revoked_at = now
    db.add(link)
    db.commit()
    return True


def list_caregiver_patients(
    db: Session,
    caregiver_id: int,
) -> list[CaregiverPatientRead]:
    """Lista pacientes activos vinculados al cuidador."""
    statement = (
        select(User)
        .join(
            PatientCaregiverLink,
            PatientCaregiverLink.patient_user_id == User.id,
        )
        .where(
            PatientCaregiverLink.caregiver_user_id == caregiver_id,
            PatientCaregiverLink.status == CaregiverLinkStatus.ACTIVE,
            User.is_active.is_(True),
            User.role == UserRole.PATIENT,
        )
        .order_by(User.full_name.asc().nulls_last(), User.email.asc())
    )
    return [
        CaregiverPatientRead(id=user.id, full_name=_display_name(user))
        for user in db.scalars(statement)
    ]


def list_linked_patient_medications(
    db: Session,
    caregiver_id: int,
    patient_id: int,
) -> list[MedicationRead] | None:
    """Devuelve medicamentos solo cuando el vinculo sigue activo."""
    link = db.scalar(
        select(PatientCaregiverLink.id).where(
            PatientCaregiverLink.patient_user_id == patient_id,
            PatientCaregiverLink.caregiver_user_id == caregiver_id,
            PatientCaregiverLink.status == CaregiverLinkStatus.ACTIVE,
        )
    )
    if link is None:
        return None

    patient = db.get(User, patient_id)
    if patient is None or not patient.is_active or patient.role != UserRole.PATIENT:
        return None
    return list_user_medications(db, patient_id)


def _active_link_exists(db: Session, caregiver_id: int, patient_id: int) -> bool:
    link = db.scalar(
        select(PatientCaregiverLink.id).where(
            PatientCaregiverLink.patient_user_id == patient_id,
            PatientCaregiverLink.caregiver_user_id == caregiver_id,
            PatientCaregiverLink.status == CaregiverLinkStatus.ACTIVE,
        )
    )
    if link is None:
        return False
    patient = db.get(User, patient_id)
    return (
        patient is not None
        and patient.is_active
        and patient.role == UserRole.PATIENT
    )


def create_linked_patient_medication(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    payload: MedicationCreate,
) -> MedicationRead | None:
    """Crea un medicamento para un paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return create_user_medication(db, patient_id, payload)


def update_linked_patient_medication(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    medication_id: int,
    payload: MedicationUpdate,
) -> MedicationRead | None:
    """Actualiza un medicamento del paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    if get_user_medication_model(db, patient_id, medication_id) is None:
        return None
    return update_user_medication(db, patient_id, medication_id, payload)


def delete_linked_patient_medication(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    medication_id: int,
) -> bool | None:
    """Elimina un medicamento del paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return delete_user_medication(db, patient_id, medication_id)


def get_linked_patient_medication(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    medication_id: int,
):
    """Obtiene el modelo de medicamento si el vinculo sigue activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return get_user_medication_model(db, patient_id, medication_id)


def list_linked_patient_dose_events(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    *,
    start: datetime | None = None,
    end: datetime | None = None,
) -> list[MedicationDoseEventRead] | None:
    """Lista eventos de toma del paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return list_dose_events(db, patient_id, start=start, end=end)


def record_linked_patient_dose_event(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    medication_id: int,
    payload: MedicationDoseEventCreate,
) -> MedicationDoseEventRead | None:
    """Registra una toma del paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    try:
        return record_dose_event(db, patient_id, medication_id, payload)
    except ValueError as exc:
        raise ValueError(str(exc)) from exc


def list_linked_patient_deleted_medications(
    db: Session,
    caregiver_id: int,
    patient_id: int,
) -> list[MedicationRead] | None:
    """Lista medicamentos eliminados del paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return list_deleted_user_medications(db, patient_id)


def restore_linked_patient_medication(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    medication_id: int,
) -> MedicationRead | None:
    """Restaura un medicamento eliminado del paciente vinculado activo."""
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return restore_user_medication(db, patient_id, medication_id)


def _get_patient_link(
    db: Session,
    patient_id: int,
    link_id: int,
) -> PatientCaregiverLink | None:
    return db.scalar(
        select(PatientCaregiverLink).where(
            PatientCaregiverLink.id == link_id,
            PatientCaregiverLink.patient_user_id == patient_id,
        )
    )


def _enforce_attempt_limit(db: Session, caregiver_id: int, now: datetime) -> None:
    cutoff = now - timedelta(minutes=settings.CAREGIVER_JOIN_WINDOW_MINUTES)
    failed_attempts = db.scalar(
        select(func.count())
        .select_from(CaregiverJoinAttempt)
        .where(
            CaregiverJoinAttempt.caregiver_user_id == caregiver_id,
            CaregiverJoinAttempt.successful.is_(False),
            CaregiverJoinAttempt.attempted_at >= cutoff,
        )
    )
    if (failed_attempts or 0) >= settings.CAREGIVER_JOIN_MAX_ATTEMPTS:
        raise CaregiverRateLimitError(
            "Demasiados intentos. Espera antes de probar otro codigo"
        )


def _record_attempt(db: Session, caregiver_id: int, *, successful: bool) -> None:
    db.add(
        CaregiverJoinAttempt(
            caregiver_user_id=caregiver_id,
            attempted_at=datetime.now(UTC),
            successful=successful,
        )
    )
    db.commit()


def _generate_unique_code(db: Session) -> str:
    for _ in range(10):
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(8))
        exists = db.scalar(
            select(CaregiverInvitation.id).where(
                CaregiverInvitation.code_digest == _digest_code(code)
            )
        )
        if exists is None:
            return code
    raise RuntimeError("No se pudo generar un codigo de vinculacion unico")


def _normalize_code(code: str) -> str:
    return code.strip().upper().replace("-", "").replace(" ", "")


def _display_code(code: str) -> str:
    return f"{code[:4]}-{code[4:]}"


def _digest_code(code: str) -> str:
    return hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        _normalize_code(code).encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _invitation_is_available(
    invitation: CaregiverInvitation,
    now: datetime,
) -> bool:
    expires_at = invitation.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    return (
        invitation.redeemed_at is None
        and invitation.canceled_at is None
        and expires_at >= now
    )


def _link_to_read(
    link: PatientCaregiverLink,
    counterpart: User,
) -> CaregiverLinkRead:
    return CaregiverLinkRead(
        id=link.id,
        status=CaregiverLinkStatus(link.status),
        counterpart_user_id=counterpart.id,
        counterpart_name=_display_name(counterpart),
        counterpart_email_masked=_mask_email(counterpart.email),
        requested_at=link.requested_at,
        decided_at=link.decided_at,
        revoked_at=link.revoked_at,
    )


def _display_name(user: User) -> str:
    return (user.full_name or "").strip() or "Usuario UleamMed"


def list_linked_patient_appointments(
    db: Session,
    caregiver_id: int,
    patient_id: int,
) -> list[AppointmentRead] | None:
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return list_user_appointments(db, patient_id)


def create_linked_patient_appointment(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    payload: AppointmentCreate,
) -> AppointmentRead | None:
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return create_user_appointment(db, patient_id, payload)


def update_linked_patient_appointment(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    appointment_id: int,
    payload: AppointmentUpdate,
) -> AppointmentRead | None:
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return update_user_appointment(db, patient_id, appointment_id, payload)


def delete_linked_patient_appointment(
    db: Session,
    caregiver_id: int,
    patient_id: int,
    appointment_id: int,
) -> bool | None:
    if not _active_link_exists(db, caregiver_id, patient_id):
        return None
    return delete_user_appointment(db, patient_id, appointment_id)


def _mask_email(email: str) -> str:
    local, separator, domain = email.partition("@")
    if not separator:
        return "***"
    visible = local[:1]
    return f"{visible}***@{domain}"
