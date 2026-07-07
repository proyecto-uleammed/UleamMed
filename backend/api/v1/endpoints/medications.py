from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_user
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
    actualizar_medicamento_usuario,
    contar_medicamentos_tomados,
    crear_medicamento_usuario,
    eliminar_medicamento_usuario,
    listar_medicamentos_usuario,
    marcar_medicamento_tomado,
)


router = APIRouter(prefix="/medications", tags=["medicamentos"])


@router.get("", response_model=MedicationListResponse)
def listar_mis_medicamentos(
    usuario_actual: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MedicationListResponse:
    """Lista los medicamentos programados para el usuario autenticado."""
    return MedicationListResponse(items=listar_medicamentos_usuario(db, usuario_actual.id))


@router.post("", response_model=MedicationRead, status_code=status.HTTP_201_CREATED)
def crear_mi_medicamento(
    datos: MedicationCreate,
    usuario_actual: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Crea un medicamento para el usuario autenticado."""
    try:
        return crear_medicamento_usuario(db, usuario_actual.id, datos)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc


@router.patch("/{medication_id}", response_model=MedicationRead)
def actualizar_mi_medicamento(
    medication_id: int,
    datos: MedicationUpdate,
    usuario_actual: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Actualiza un medicamento del usuario autenticado."""
    try:
        medicamento = actualizar_medicamento_usuario(db, usuario_actual.id, medication_id, datos)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    if medicamento is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicamento no encontrado")
    return medicamento


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_mi_medicamento(
    medication_id: int,
    usuario_actual: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Elimina logicamente un medicamento del usuario autenticado."""
    eliminado = eliminar_medicamento_usuario(db, usuario_actual.id, medication_id)
    if not eliminado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicamento no encontrado")


@router.post("/{medication_id}/take", response_model=MedicationMarkResponse)
def marcar_mi_medicamento(
    medication_id: int,
    usuario_actual: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MedicationMarkResponse:
    """Marca un medicamento como tomado para el usuario autenticado."""
    medicamento = marcar_medicamento_tomado(db, usuario_actual.id, medication_id)
    if medicamento is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )

    tomados, total = contar_medicamentos_tomados(db, usuario_actual.id)
    return MedicationMarkResponse(
        medication=medicamento,
        taken_count=tomados,
        total_count=total,
    )
