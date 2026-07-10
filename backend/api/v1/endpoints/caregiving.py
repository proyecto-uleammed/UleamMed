from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy.orm import Session

from backend.api.deps import (
    get_current_caregiving_user,
    get_current_caregiver,
    get_current_patient,
)
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.caregiving import (
    CaregiverInvitationRead,
    CaregiverInvitationRedeem,
    CaregiverLinkListResponse,
    CaregiverLinkRead,
    CaregiverPatientListResponse,
)
from backend.schemas.medication import (
    MedicationCreate,
    MedicationListResponse,
    MedicationRead,
    MedicationUpdate,
)
from backend.services.caregiving_service import (
    CaregiverLinkNotFoundError,
    CaregiverLinkStateError,
    CaregiverRateLimitError,
    InvalidInvitationCodeError,
    approve_link,
    cancel_invitation,
    create_invitation,
    create_linked_patient_medication,
    delete_linked_patient_medication,
    get_linked_patient_medication,
    list_caregiver_patients,
    list_linked_patient_medications,
    list_links,
    redeem_invitation,
    reject_link,
    revoke_link,
    update_linked_patient_medication,
)
from backend.services.medication_photo_service import (
    MAX_PHOTO_BYTES,
    MedicationPhotoConfigurationError,
    delete_medication_photo,
    upload_medication_photo,
)
from backend.services.medication_service import medication_to_read


router = APIRouter(prefix="/caregiving", tags=["caregiving"])


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
            pass
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
        pass
    return medication_to_read(db, patient_id, medication.id)
