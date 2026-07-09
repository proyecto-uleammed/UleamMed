from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel, Field, model_validator


class MedicationScheduleMode(StrEnum):
    interval = "interval"
    fixed_times = "fixed_times"


class MedicationDoseStatus(StrEnum):
    taken = "taken"
    postponed = "postponed"
    omitted = "omitted"
    missed = "missed"


class MedicationSchedulePayload(BaseModel):
    mode: MedicationScheduleMode
    interval_hours: int | None = Field(default=None, ge=2, le=24)
    times: list[str] = Field(default_factory=list, max_length=12)
    weekdays: list[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5, 6, 7])
    start_date: date = Field(default_factory=date.today)
    end_date: date | None = None

    @model_validator(mode="after")
    def validate_schedule(self) -> "MedicationSchedulePayload":
        allowed_intervals = {2, 4, 6, 8, 12, 24}
        if sorted(set(self.weekdays)) != sorted(self.weekdays):
            raise ValueError("Los dias de la semana no pueden repetirse")
        if not self.weekdays or any(day < 1 or day > 7 for day in self.weekdays):
            raise ValueError("Selecciona al menos un dia valido")
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("La fecha final no puede ser anterior a la inicial")
        if self.mode == MedicationScheduleMode.interval:
            if self.interval_hours not in allowed_intervals:
                raise ValueError("Selecciona un intervalo de 2, 4, 6, 8, 12 o 24 horas")
            if len(self.times) != 1:
                raise ValueError("El modo por intervalo requiere una hora inicial")
        elif not self.times:
            raise ValueError("Selecciona al menos una hora")
        return self


class MedicationScheduleRead(BaseModel):
    mode: MedicationScheduleMode
    interval_hours: int | None = None
    times: list[str]
    weekdays: list[int]
    start_date: date
    end_date: date | None = None


class MedicationRead(BaseModel):
    """Medicamento programado para el usuario autenticado."""

    id: str
    name: str
    dose: str
    doseAmount: Decimal | None = None
    doseUnit: str | None = None
    time: str
    taken: bool
    frequency: str = "Diario"
    duration: str = ""
    instructions: str = ""
    isImportant: bool = True
    photoAvailable: bool = False
    schedule: MedicationScheduleRead


class MedicationCreate(BaseModel):
    """Datos para crear un medicamento del usuario autenticado."""

    name: str = Field(..., min_length=1, max_length=150)
    dose: str | None = Field(default=None, min_length=1, max_length=100)
    doseAmount: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    doseUnit: str | None = Field(default=None, max_length=30)
    time: str | None = Field(default=None, examples=["08:00"])
    frequency: str | None = Field(default="Diario", max_length=100)
    duration: str | None = Field(default="", max_length=100)
    instructions: str | None = Field(default="", max_length=500)
    isImportant: bool = True
    schedule: MedicationSchedulePayload | None = None

    @model_validator(mode="after")
    def validate_dose(self) -> "MedicationCreate":
        if self.doseAmount is None and not (self.dose or "").strip():
            raise ValueError("Ingresa la cantidad de la dosis")
        if self.doseAmount is not None and not (self.doseUnit or "").strip():
            raise ValueError("Selecciona la unidad de la dosis")
        if self.schedule is None and not (self.time or "").strip():
            raise ValueError("Selecciona un horario")
        return self


class MedicationUpdate(BaseModel):
    """Datos editables de un medicamento del usuario autenticado."""

    name: str | None = Field(default=None, min_length=1, max_length=150)
    dose: str | None = Field(default=None, min_length=1, max_length=100)
    doseAmount: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    doseUnit: str | None = Field(default=None, max_length=30)
    time: str | None = Field(default=None, examples=["08:00"])
    frequency: str | None = Field(default=None, max_length=100)
    duration: str | None = Field(default=None, max_length=100)
    instructions: str | None = Field(default=None, max_length=500)
    isImportant: bool | None = None
    taken: bool | None = None
    schedule: MedicationSchedulePayload | None = None


class MedicationListResponse(BaseModel):
    items: list[MedicationRead]


class MedicationMarkResponse(BaseModel):
    medication: MedicationRead
    taken_count: int
    total_count: int


class MedicationDoseEventCreate(BaseModel):
    client_event_id: str = Field(..., min_length=8, max_length=64)
    scheduled_at: datetime
    sequence_number: int = Field(..., ge=1, le=24)
    status: MedicationDoseStatus
    acted_at: datetime | None = None
    snoozed_until: datetime | None = None

    @model_validator(mode="after")
    def validate_snooze(self) -> "MedicationDoseEventCreate":
        if self.status == MedicationDoseStatus.postponed and self.snoozed_until is None:
            raise ValueError("Una toma pospuesta requiere nueva hora")
        return self


class MedicationDoseEventRead(BaseModel):
    id: int
    medication_id: str
    medication_name: str
    client_event_id: str
    scheduled_at: datetime
    sequence_number: int
    status: MedicationDoseStatus
    acted_at: datetime | None = None
    snoozed_until: datetime | None = None
