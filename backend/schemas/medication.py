from pydantic import BaseModel, Field


class MedicationRead(BaseModel):
    """Medicamento programado para el usuario autenticado."""

    id: str = Field(..., examples=["metformina"])
    name: str = Field(..., examples=["Metformina"])
    dose: str = Field(..., examples=["500 mg"])
    time: str = Field(..., examples=["08:00"])
    taken: bool = Field(..., examples=[True])


class MedicationListResponse(BaseModel):
    """Lista de medicamentos programados del dia."""

    items: list[MedicationRead]


class MedicationMarkResponse(BaseModel):
    """Respuesta al marcar un medicamento como tomado."""

    medication: MedicationRead
    taken_count: int
    total_count: int
