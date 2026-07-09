from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_patient
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.medication import (
    MedicationCreate,
    MedicationListResponse,
    MedicationMarkResponse,
    MedicationRead,
    MedicationUpdate,
)
from backend.services.medication_service import (
    count_taken_medications,
    create_user_medication,
    delete_user_medication,
    list_user_medications,
    mark_user_medication_taken,
    update_user_medication,
)


router = APIRouter(prefix="/medications", tags=["medications"])


@router.get("", response_model=MedicationListResponse)
def list_my_medications(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationListResponse:
    """Lista los medicamentos programados para el usuario autenticado."""
    return MedicationListResponse(items=list_user_medications(db, current_user.id))


@router.post("", response_model=MedicationRead, status_code=status.HTTP_201_CREATED)
def create_my_medication(
    payload: MedicationCreate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Crea un medicamento para el usuario autenticado."""
    try:
        return create_user_medication(db, current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc


@router.patch("/{medication_id}", response_model=MedicationRead)
def update_my_medication(
    medication_id: int,
    payload: MedicationUpdate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Actualiza un medicamento del usuario autenticado."""
    try:
        medication = update_user_medication(db, current_user.id, medication_id, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    if medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicamento no encontrado")
    return medication


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_medication(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> None:
    """Elimina logicamente un medicamento del usuario autenticado."""
    removed = delete_user_medication(db, current_user.id, medication_id)
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicamento no encontrado")


@router.post("/{medication_id}/take", response_model=MedicationMarkResponse)
def mark_my_medication(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationMarkResponse:
    """Marca un medicamento como tomado para el usuario autenticado."""
    medication = mark_user_medication_taken(db, current_user.id, medication_id)
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )

    taken_count, total_count = count_taken_medications(db, current_user.id)
    return MedicationMarkResponse(
        medication=medication,
        taken_count=taken_count,
        total_count=total_count,
    )
