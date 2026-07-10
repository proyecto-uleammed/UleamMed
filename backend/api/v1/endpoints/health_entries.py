from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_patient
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.health_entry import (
    HealthEntryCreate,
    HealthEntryListResponse,
    HealthEntryRead,
    HealthEntryUpdate,
)
from backend.services.health_entry_service import (
    create_user_health_entry,
    delete_user_health_entry,
    list_user_health_entries,
    update_user_health_entry,
)

router = APIRouter(prefix="/health-entries", tags=["health-entries"])


@router.get("", response_model=HealthEntryListResponse)
def list_my_health_entries(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> HealthEntryListResponse:
    """Lista enfermedades y alergias del paciente autenticado."""
    return HealthEntryListResponse(items=list_user_health_entries(db, current_user.id))


@router.post("", response_model=HealthEntryRead, status_code=status.HTTP_201_CREATED)
def create_my_health_entry(
    payload: HealthEntryCreate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> HealthEntryRead:
    """Crea una enfermedad o alergia para el paciente autenticado."""
    try:
        return create_user_health_entry(db, current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc


@router.patch("/{entry_id}", response_model=HealthEntryRead)
def update_my_health_entry(
    entry_id: int,
    payload: HealthEntryUpdate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> HealthEntryRead:
    """Actualiza una enfermedad o alergia del paciente autenticado."""
    try:
        entry = update_user_health_entry(db, current_user.id, entry_id, payload)
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


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_health_entry(
    entry_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> None:
    """Elimina una enfermedad o alergia del paciente autenticado."""
    removed = delete_user_health_entry(db, current_user.id, entry_id)
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registro no encontrado",
        )
