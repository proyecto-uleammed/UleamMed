from fastapi import APIRouter, Depends, HTTPException, status

from backend.api.deps import get_current_user
from backend.models.user import User
from backend.schemas.medication import MedicationListResponse, MedicationMarkResponse
from backend.services.medication_service import (
    contar_medicamentos_tomados,
    listar_medicamentos_usuario,
    marcar_medicamento_tomado,
)


router = APIRouter(prefix="/medications", tags=["medicamentos"])


@router.get("", response_model=MedicationListResponse)
def listar_mis_medicamentos(usuario_actual: User = Depends(get_current_user)) -> MedicationListResponse:
    """Lista los medicamentos programados para el usuario autenticado."""
    return MedicationListResponse(items=listar_medicamentos_usuario(usuario_actual.id))


@router.post("/{medication_id}/take", response_model=MedicationMarkResponse)
def marcar_mi_medicamento(
    medication_id: str,
    usuario_actual: User = Depends(get_current_user),
) -> MedicationMarkResponse:
    """Marca un medicamento como tomado para el usuario autenticado."""
    medicamento = marcar_medicamento_tomado(usuario_actual.id, medication_id)
    if medicamento is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )

    tomados, total = contar_medicamentos_tomados(usuario_actual.id)
    return MedicationMarkResponse(
        medication=medicamento,
        taken_count=tomados,
        total_count=total,
    )
