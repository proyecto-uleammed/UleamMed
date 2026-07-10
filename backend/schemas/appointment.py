from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, Field, model_validator


class AppointmentReminder(StrEnum):
    none = "none"
    one_day_before = "oneDayBefore"
    two_hours_before = "twoHoursBefore"


class AppointmentRead(BaseModel):
    id: str
    doctor: str
    specialty: str
    location: str = ""
    notes: str = ""
    completed: bool = False
    reminder: AppointmentReminder = AppointmentReminder.none
    scheduledAt: datetime


class AppointmentCreate(BaseModel):
    doctor: str = Field(..., min_length=3, max_length=150)
    specialty: str = Field(..., min_length=1, max_length=150)
    location: str = Field(default="", max_length=250)
    notes: str = Field(default="", max_length=1000)
    completed: bool = False
    reminder: AppointmentReminder = AppointmentReminder.none
    scheduledAt: datetime

    @model_validator(mode="after")
    def validate_schedule(self) -> "AppointmentCreate":
        scheduled = self.scheduledAt
        if scheduled.tzinfo is None:
            scheduled = scheduled.replace(tzinfo=UTC)
        if not self.completed and scheduled <= datetime.now(UTC):
            raise ValueError("La consulta debe programarse en el futuro")
        return self


class AppointmentUpdate(BaseModel):
    doctor: str | None = Field(default=None, min_length=3, max_length=150)
    specialty: str | None = Field(default=None, min_length=1, max_length=150)
    location: str | None = Field(default=None, max_length=250)
    notes: str | None = Field(default=None, max_length=1000)
    completed: bool | None = None
    reminder: AppointmentReminder | None = None
    scheduledAt: datetime | None = None

    @model_validator(mode="after")
    def validate_schedule(self) -> "AppointmentUpdate":
        if self.scheduledAt is None:
            return self
        scheduled = self.scheduledAt
        if scheduled.tzinfo is None:
            scheduled = scheduled.replace(tzinfo=UTC)
        completed = self.completed if self.completed is not None else False
        if not completed and scheduled <= datetime.now(UTC):
            raise ValueError("La consulta debe programarse en el futuro")
        return self


class AppointmentListResponse(BaseModel):
    items: list[AppointmentRead]
