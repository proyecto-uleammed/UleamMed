from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_patient
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.emergency_contact import (
    EmergencyContactCreate,
    EmergencyContactListResponse,
    EmergencyContactRead,
    EmergencyContactUpdate,
)
from backend.services.emergency_contact_service import (
    create_user_emergency_contact,
    delete_user_emergency_contact,
    list_user_emergency_contacts,
    update_user_emergency_contact,
)

router = APIRouter(prefix="/emergency-contacts", tags=["emergency-contacts"])


@router.get("", response_model=EmergencyContactListResponse)
def list_my_emergency_contacts(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> EmergencyContactListResponse:
    return EmergencyContactListResponse(
        items=list_user_emergency_contacts(db, current_user.id),
    )


@router.post("", response_model=EmergencyContactRead, status_code=status.HTTP_201_CREATED)
def create_my_emergency_contact(
    payload: EmergencyContactCreate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> EmergencyContactRead:
    try:
        return create_user_emergency_contact(db, current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc


@router.patch("/{contact_id}", response_model=EmergencyContactRead)
def update_my_emergency_contact(
    contact_id: int,
    payload: EmergencyContactUpdate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> EmergencyContactRead:
    try:
        contact = update_user_emergency_contact(
            db,
            current_user.id,
            contact_id,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    if contact is None:
        raise HTTPException(status_code=404, detail="Contacto no encontrado")
    return contact


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_emergency_contact(
    contact_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> None:
    removed = delete_user_emergency_contact(db, current_user.id, contact_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Contacto no encontrado")
