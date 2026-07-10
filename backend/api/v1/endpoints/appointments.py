from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_patient
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.appointment import (
    AppointmentCreate,
    AppointmentListResponse,
    AppointmentRead,
    AppointmentUpdate,
)
from backend.services.appointment_service import (
    create_user_appointment,
    delete_user_appointment,
    list_user_appointments,
    update_user_appointment,
)

router = APIRouter(prefix="/appointments", tags=["appointments"])


@router.get("", response_model=AppointmentListResponse)
def list_my_appointments(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> AppointmentListResponse:
    """Lista consultas del paciente autenticado."""
    return AppointmentListResponse(items=list_user_appointments(db, current_user.id))


@router.post("", response_model=AppointmentRead, status_code=status.HTTP_201_CREATED)
def create_my_appointment(
    payload: AppointmentCreate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> AppointmentRead:
    """Crea una consulta para el paciente autenticado."""
    try:
        return create_user_appointment(db, current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc


@router.patch("/{appointment_id}", response_model=AppointmentRead)
def update_my_appointment(
    appointment_id: int,
    payload: AppointmentUpdate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> AppointmentRead:
    """Actualiza una consulta del paciente autenticado."""
    try:
        appointment = update_user_appointment(
            db,
            current_user.id,
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


@router.delete("/{appointment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_appointment(
    appointment_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> None:
    """Elimina una consulta del paciente autenticado."""
    removed = delete_user_appointment(db, current_user.id, appointment_id)
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Consulta no encontrada",
        )
