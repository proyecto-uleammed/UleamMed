from fastapi import APIRouter, Depends, HTTPException, Response, status
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
from backend.schemas.medication import MedicationListResponse
from backend.services.caregiving_service import (
    CaregiverLinkNotFoundError,
    CaregiverLinkStateError,
    CaregiverRateLimitError,
    InvalidInvitationCodeError,
    approve_link,
    cancel_invitation,
    create_invitation,
    list_caregiver_patients,
    list_linked_patient_medications,
    list_links,
    redeem_invitation,
    reject_link,
    revoke_link,
)


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
    """Consulta medicamentos sin permitir cambios del cuidador."""
    medications = list_linked_patient_medications(db, caregiver.id, patient_id)
    if medications is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paciente no encontrado",
        )
    return MedicationListResponse(items=medications)
