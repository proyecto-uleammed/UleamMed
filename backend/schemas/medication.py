from pydantic import BaseModel, Field


class MedicationRead(BaseModel):
    """Medicamento programado para el usuario autenticado."""

    id: str = Field(..., examples=["metformina"])
    name: str = Field(..., examples=["Metformina"])
    dose: str = Field(..., examples=["500 mg"])
    time: str = Field(..., examples=["08:00"])
    taken: bool = Field(..., examples=[True])
    frequency: str = Field(default="Diario", examples=["Diario"])
    duration: str = Field(default="", examples=["30 dias"])
    instructions: str = Field(default="", examples=["Tomar despues del desayuno"])
    isImportant: bool = Field(default=True, examples=[True])


class MedicationCreate(BaseModel):
    """Datos para crear un medicamento del usuario autenticado."""

    name: str = Field(..., min_length=1, max_length=150)
    dose: str = Field(..., min_length=1, max_length=100)
    time: str = Field(..., examples=["08:00"])
    frequency: str | None = Field(default="Diario", max_length=100)
    duration: str | None = Field(default="", max_length=100)
    instructions: str | None = Field(default="", max_length=500)
    isImportant: bool = True


class MedicationUpdate(BaseModel):
    """Datos editables de un medicamento del usuario autenticado."""

    name: str | None = Field(default=None, min_length=1, max_length=150)
    dose: str | None = Field(default=None, min_length=1, max_length=100)
    time: str | None = Field(default=None, examples=["08:00"])
    frequency: str | None = Field(default=None, max_length=100)
    duration: str | None = Field(default=None, max_length=100)
    instructions: str | None = Field(default=None, max_length=500)
    isImportant: bool | None = None
    taken: bool | None = None


class MedicationListResponse(BaseModel):
    """Lista de medicamentos programados del dia."""

    items: list[MedicationRead]


class MedicationMarkResponse(BaseModel):
    """Respuesta al marcar un medicamento como tomado."""

    medication: MedicationRead
    taken_count: int
    total_count: int
