import logging
from datetime import datetime

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from backend.api.deps import (
    get_current_caregiver,
    get_current_caregiving_user,
    get_current_patient,
)
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.appointment import (
    AppointmentCreate,
    AppointmentListResponse,
    AppointmentRead,
    AppointmentUpdate,
)
from backend.schemas.caregiving import (
    CaregiverInvitationRead,
    CaregiverInvitationRedeem,
    CaregiverLinkListResponse,
    CaregiverLinkRead,
    CaregiverPatientListResponse,
)
from backend.schemas.emergency_contact import EmergencyContactListResponse
from backend.schemas.health_entry import (
    HealthEntryCreate,
    HealthEntryListResponse,
    HealthEntryRead,
    HealthEntryUpdate,
)
from backend.schemas.medication import (
    MedicationCreate,
    MedicationDoseEventCreate,
    MedicationDoseEventRead,
    MedicationListResponse,
    MedicationRead,
    MedicationSyncRequest,
    MedicationSyncResponse,
    MedicationUpdate,
)
from backend.schemas.user_medical_profile import UserMedicalProfileRead
from backend.services.caregiving_service import (
    CaregiverLinkNotFoundError,
    CaregiverLinkStateError,
    CaregiverRateLimitError,
    InvalidInvitationCodeError,
    approve_link,
    cancel_invitation,
    clear_linked_patient_dose_events,
    create_invitation,
    create_linked_patient_appointment,
    create_linked_patient_health_entry,
    create_linked_patient_medication,
    delete_linked_patient_appointment,
    delete_linked_patient_health_entry,
    delete_linked_patient_medication,
    get_linked_patient_medical_profile,
    get_linked_patient_medication,
    list_caregiver_patients,
    list_linked_patient_appointments,
    list_linked_patient_deleted_medications,
    list_linked_patient_dose_events,
    list_linked_patient_emergency_contacts,
    list_linked_patient_health_entries,
    list_linked_patient_medications,
    list_links,
    record_linked_patient_dose_event,
    redeem_invitation,
    reject_link,
    restore_linked_patient_medication,
    revoke_link,
    sync_linked_patient_medication_actions,
    update_linked_patient_appointment,
    update_linked_patient_health_entry,
    update_linked_patient_medication,
)
from backend.services.medication_photo_service import (
    MAX_PHOTO_BYTES,
    MedicationPhotoConfigurationError,
    MedicationPhotoNotFoundError,
    delete_medication_photo,
    download_medication_photo,
    upload_medication_photo,
)
from backend.services.medication_service import medication_to_read
from backend.services.user_medical_profile_service import patient_shares_health_data

router = APIRouter(prefix="/caregiving", tags=["caregiving"])
logger = logging.getLogger(__name__)


@router.post(
    "/invitations",
    response_model=CaregiverInvitationRead,
    status_code=status.HTTP_201_CREATED,
)
def generate_invitation(
    patient: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> CaregiverInvitationRead:
    """Genera un codigo de vinculacion para el paciente autenticado."""
    return create_invitation(db, patient)


@router.delete("/invitations/{invitation_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_invitation(
    invitation_id: int,
    patient: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> Response:
    """Cancela una invitacion pendiente del paciente."""
    if not cancel_invitation(db, patient.id, invitation_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invitacion no encontrada",
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/invitations/redeem", response_model=CaregiverLinkRead)
def use_invitation(
    payload: CaregiverInvitationRedeem,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> CaregiverLinkRead:
    """Registra una solicitud pendiente usando un codigo valido."""
    try:
        return redeem_invitation(db, caregiver, payload.code)
    except CaregiverRateLimitError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc
    except InvalidInvitationCodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except CaregiverLinkStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.get("/links", response_model=CaregiverLinkListResponse)
def get_links(
    current_user: User = Depends(get_current_caregiving_user),
    db: Session = Depends(get_db),
) -> CaregiverLinkListResponse:
    """Lista los vinculos visibles para el paciente o cuidador."""
    return CaregiverLinkListResponse(items=list_links(db, current_user))


@router.post("/links/{link_id}/approve", response_model=CaregiverLinkRead)
def approve_caregiver(
    link_id: int,
    patient: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> CaregiverLinkRead:
    """Aprueba una solicitud pendiente."""
    try:
        return approve_link(db, patient.id, link_id)
    except CaregiverLinkNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except CaregiverLinkStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.post("/links/{link_id}/reject", response_model=CaregiverLinkRead)
def reject_caregiver(
    link_id: int,
    patient: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> CaregiverLinkRead:
    """Rechaza una solicitud pendiente."""
    try:
        return reject_link(db, patient.id, link_id)
    except CaregiverLinkNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except CaregiverLinkStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.delete("/links/{link_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_caregiver(
    link_id: int,
    patient: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> Response:
    """Revoca una solicitud o un vinculo del paciente."""
    try:
        removed = revoke_link(db, patient.id, link_id)
    except CaregiverLinkStateError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vinculo no encontrado",
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/patients", response_model=CaregiverPatientListResponse)
def get_patients(
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> CaregiverPatientListResponse:
    """Lista pacientes que aprobaron al cuidador."""
    return CaregiverPatientListResponse(
        items=list_caregiver_patients(db, caregiver.id)
    )


@router.get(
    "/patients/{patient_id}/medications",
    response_model=MedicationListResponse,
)
def get_patient_medications(
    patient_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationListResponse:
    """Consulta medicamentos del paciente vinculado."""
    medications = list_linked_patient_medications(db, caregiver.id, patient_id)
    if medications is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return MedicationListResponse(items=medications)


@router.post(
    "/patients/{patient_id}/medications/sync",
    response_model=MedicationSyncResponse,
)
def sync_patient_medications(
    patient_id: int,
    payload: MedicationSyncRequest,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationSyncResponse:
    """Sincroniza operaciones offline del cuidador sobre un paciente vinculado."""
    result = sync_linked_patient_medication_actions(
        db,
        caregiver.id,
        patient_id,
        payload,
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return result


@router.get(
    "/patients/{patient_id}/medications/dose-events",
    response_model=list[MedicationDoseEventRead],
)
def get_patient_medication_dose_events(
    patient_id: int,
    start: datetime | None = None,
    end: datetime | None = None,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> list[MedicationDoseEventRead]:
    """Consulta el historial de tomas del paciente vinculado activo."""
    events = list_linked_patient_dose_events(
        db,
        caregiver.id,
        patient_id,
        start=start,
        end=end,
    )
    if events is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return events


@router.get(
    "/patients/{patient_id}/medications/trash",
    response_model=MedicationListResponse,
)
def get_patient_deleted_medications(
    patient_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationListResponse:
    """Lista medicamentos eliminados del paciente vinculado activo."""
    medications = list_linked_patient_deleted_medications(
        db,
        caregiver.id,
        patient_id,
    )
    if medications is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return MedicationListResponse(items=medications)


@router.post(
    "/patients/{patient_id}/medications/{medication_id}/dose-events",
    response_model=MedicationDoseEventRead,
)
def record_patient_medication_dose_event(
    patient_id: int,
    medication_id: int,
    payload: MedicationDoseEventCreate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationDoseEventRead:
    """Registra una toma del paciente vinculado activo."""
    try:
        event = record_linked_patient_dose_event(
            db,
            caregiver.id,
            patient_id,
            medication_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )
    return event


@router.post(
    "/patients/{patient_id}/medications/{medication_id}/restore",
    response_model=MedicationRead,
)
def restore_patient_medication(
    patient_id: int,
    medication_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Restaura un medicamento eliminado del paciente vinculado activo."""
    medication = restore_linked_patient_medication(
        db,
        caregiver.id,
        patient_id,
        medication_id,
    )
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado en la papelera",
        )
    return medication


@router.post(
    "/patients/{patient_id}/medications",
    response_model=MedicationRead,
    status_code=status.HTTP_201_CREATED,
)
def create_patient_medication(
    patient_id: int,
    payload: MedicationCreate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Crea un medicamento para un paciente vinculado activo."""
    try:
        medication = create_linked_patient_medication(
            db,
            caregiver.id,
            patient_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return medication


@router.patch(
    "/patients/{patient_id}/medications/{medication_id}",
    response_model=MedicationRead,
)
def update_patient_medication(
    patient_id: int,
    medication_id: int,
    payload: MedicationUpdate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Actualiza un medicamento del paciente vinculado activo."""
    try:
        medication = update_linked_patient_medication(
            db,
            caregiver.id,
            patient_id,
            medication_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )
    return medication


@router.delete(
    "/patients/{patient_id}/medications/{medication_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_patient_medication(
    patient_id: int,
    medication_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> None:
    """Elimina un medicamento del paciente vinculado activo."""
    medication = get_linked_patient_medication(
        db,
        caregiver.id,
        patient_id,
        medication_id,
    )
    if medication is not None and medication.photo_path:
        try:
            delete_medication_photo(medication.photo_path)
        except Exception:
            logger.exception(
                "No se pudo borrar la foto del medicamento %s",
                medication_id,
            )
    removed = delete_linked_patient_medication(
        db,
        caregiver.id,
        patient_id,
        medication_id,
    )
    if removed is None or not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )


@router.post(
    "/patients/{patient_id}/medications/{medication_id}/photo",
    response_model=MedicationRead,
)
def upload_patient_medication_photo(
    patient_id: int,
    medication_id: int,
    photo: UploadFile = File(...),
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Sube la foto de un medicamento del paciente vinculado activo."""
    medication = get_linked_patient_medication(
        db,
        caregiver.id,
        patient_id,
        medication_id,
    )
    if medication is None:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    previous_path = medication.photo_path
    try:
        new_path = upload_medication_photo(
            user_id=patient_id,
            medication_id=medication.id,
            content=photo.file.read(MAX_PHOTO_BYTES + 1),
            content_type=photo.content_type or "",
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except MedicationPhotoConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    medication.photo_path = new_path
    db.add(medication)
    db.commit()
    try:
        delete_medication_photo(previous_path)
    except Exception:
        logger.exception(
            "No se pudo borrar la foto anterior del medicamento %s",
            medication_id,
        )
    return medication_to_read(db, patient_id, medication.id)


@router.get("/patients/{patient_id}/medications/{medication_id}/photo")
def download_patient_medication_photo(
    patient_id: int,
    medication_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> Response:
    """Descarga la foto de un medicamento del paciente vinculado activo."""
    medication = get_linked_patient_medication(
        db,
        caregiver.id,
        patient_id,
        medication_id,
    )
    if medication is None or not medication.photo_path:
        raise HTTPException(status_code=404, detail="Foto no encontrada")
    try:
        content = download_medication_photo(medication.photo_path)
    except MedicationPhotoConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except MedicationPhotoNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    path = medication.photo_path.lower()
    media_type = (
        "image/png"
        if path.endswith(".png")
        else "image/webp"
        if path.endswith(".webp")
        else "image/jpeg"
    )
    return Response(content=content, media_type=media_type)


@router.delete(
    "/patients/{patient_id}/medications/{medication_id}/photo",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_patient_medication_photo(
    patient_id: int,
    medication_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> Response:
    """Elimina la foto de un medicamento del paciente vinculado activo."""
    medication = get_linked_patient_medication(
        db,
        caregiver.id,
        patient_id,
        medication_id,
    )
    if medication is None:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    if not medication.photo_path:
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    try:
        delete_medication_photo(medication.photo_path)
    except MedicationPhotoConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    medication.photo_path = None
    db.add(medication)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/patients/{patient_id}/appointments",
    response_model=AppointmentListResponse,
)
def get_patient_appointments(
    patient_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> AppointmentListResponse:
    """Consulta citas del paciente vinculado activo."""
    appointments = list_linked_patient_appointments(db, caregiver.id, patient_id)
    if appointments is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return AppointmentListResponse(items=appointments)


@router.post(
    "/patients/{patient_id}/appointments",
    response_model=AppointmentRead,
    status_code=status.HTTP_201_CREATED,
)
def create_patient_appointment(
    patient_id: int,
    payload: AppointmentCreate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> AppointmentRead:
    """Crea una consulta para el paciente vinculado activo."""
    try:
        appointment = create_linked_patient_appointment(
            db,
            caregiver.id,
            patient_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if appointment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return appointment


@router.patch(
    "/patients/{patient_id}/appointments/{appointment_id}",
    response_model=AppointmentRead,
)
def update_patient_appointment(
    patient_id: int,
    appointment_id: int,
    payload: AppointmentUpdate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> AppointmentRead:
    """Actualiza una consulta del paciente vinculado activo."""
    try:
        appointment = update_linked_patient_appointment(
            db,
            caregiver.id,
            patient_id,
            appointment_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if appointment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Consulta no encontrada",
        )
    return appointment


@router.delete(
    "/patients/{patient_id}/appointments/{appointment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_patient_appointment(
    patient_id: int,
    appointment_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> None:
    """Elimina una consulta del paciente vinculado activo."""
    removed = delete_linked_patient_appointment(
        db,
        caregiver.id,
        patient_id,
        appointment_id,
    )
    if removed is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Consulta no encontrada",
        )


def _ensure_linked_health_write_access(
    db: Session,
    caregiver_id: int,
    patient_id: int,
) -> None:
    entries = list_linked_patient_health_entries(db, caregiver_id, patient_id)
    if entries is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    if not patient_shares_health_data(db, patient_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El paciente no comparte informacion medica",
        )


@router.get(
    "/patients/{patient_id}/medical-profile",
    response_model=UserMedicalProfileRead,
)
def get_patient_medical_profile(
    patient_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> UserMedicalProfileRead:
    """Consulta el perfil medico compartido del paciente vinculado."""
    profile = get_linked_patient_medical_profile(db, caregiver.id, patient_id)
    if profile is None:
        if list_linked_patient_health_entries(db, caregiver.id, patient_id) is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paciente no encontrado",
            )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El paciente no comparte informacion medica",
        )
    return profile


@router.get(
    "/patients/{patient_id}/health-entries",
    response_model=HealthEntryListResponse,
)
def get_patient_health_entries(
    patient_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> HealthEntryListResponse:
    """Consulta enfermedades y alergias del paciente vinculado activo."""
    entries = list_linked_patient_health_entries(db, caregiver.id, patient_id)
    if entries is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return HealthEntryListResponse(items=entries)


@router.post(
    "/patients/{patient_id}/health-entries",
    response_model=HealthEntryRead,
    status_code=status.HTTP_201_CREATED,
)
def create_patient_health_entry(
    patient_id: int,
    payload: HealthEntryCreate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> HealthEntryRead:
    """Crea una enfermedad o alergia para el paciente vinculado activo."""
    _ensure_linked_health_write_access(db, caregiver.id, patient_id)
    try:
        entry = create_linked_patient_health_entry(
            db,
            caregiver.id,
            patient_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return entry


@router.patch(
    "/patients/{patient_id}/health-entries/{entry_id}",
    response_model=HealthEntryRead,
)
def update_patient_health_entry(
    patient_id: int,
    entry_id: int,
    payload: HealthEntryUpdate,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> HealthEntryRead:
    """Actualiza una enfermedad o alergia del paciente vinculado activo."""
    _ensure_linked_health_write_access(db, caregiver.id, patient_id)
    try:
        entry = update_linked_patient_health_entry(
            db,
            caregiver.id,
            patient_id,
            entry_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registro no encontrado",
        )
    return entry


@router.delete(
    "/patients/{patient_id}/health-entries/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_patient_health_entry(
    patient_id: int,
    entry_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> None:
    """Elimina una enfermedad o alergia del paciente vinculado activo."""
    _ensure_linked_health_write_access(db, caregiver.id, patient_id)
    removed = delete_linked_patient_health_entry(
        db,
        caregiver.id,
        patient_id,
        entry_id,
    )
    if removed is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registro no encontrado",
        )


@router.get(
    "/patients/{patient_id}/emergency-contacts",
    response_model=EmergencyContactListResponse,
)
def get_patient_emergency_contacts(
    patient_id: int,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> EmergencyContactListResponse:
    """Consulta contactos de emergencia compartidos del paciente vinculado."""
    contacts = list_linked_patient_emergency_contacts(db, caregiver.id, patient_id)
    if contacts is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return EmergencyContactListResponse(items=contacts)


@router.delete("/patients/{patient_id}/medications/dose-events")
def clear_patient_medication_dose_events(
    patient_id: int,
    before: datetime | None = None,
    caregiver: User = Depends(get_current_caregiver),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    """Elimina eventos antiguos del historial de tomas del paciente vinculado."""
    deleted = clear_linked_patient_dose_events(
        db,
        caregiver.id,
        patient_id,
        before=before,
    )
    if deleted is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return {"deleted": deleted}
