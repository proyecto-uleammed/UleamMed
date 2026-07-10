import re
from enum import StrEnum

from pydantic import BaseModel, Field, field_validator


class HealthEntryKind(StrEnum):
    condition = "condition"
    allergy = "allergy"


class HealthEntrySeverity(StrEnum):
    low = "low"
    medium = "medium"
    high = "high"


_NAME_PATTERN = re.compile(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]+$")
_APPROX_DATE_PATTERN = re.compile(r"^[0-9A-Za-záéíóúÁÉÍÓÚñÑüÜ\s./-]+$")


class HealthEntryRead(BaseModel):
    id: str
    kind: HealthEntryKind
    name: str
    severity: HealthEntrySeverity = HealthEntrySeverity.low
    detail: str = ""
    date: str = ""
    active: bool = True


class HealthEntryCreate(BaseModel):
    kind: HealthEntryKind
    name: str = Field(..., min_length=3, max_length=150)
    severity: HealthEntrySeverity = HealthEntrySeverity.low
    detail: str = Field(default="", max_length=500)
    date: str = Field(default="", max_length=30)
    active: bool = True

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not _NAME_PATTERN.match(cleaned):
            raise ValueError("El nombre solo puede contener letras y espacios")
        return cleaned

    @field_validator("date")
    @classmethod
    def validate_date(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            return ""
        if not _APPROX_DATE_PATTERN.match(cleaned):
            raise ValueError("Fecha aproximada invalida")
        return cleaned


class HealthEntryUpdate(BaseModel):
    kind: HealthEntryKind | None = None
    name: str | None = Field(default=None, min_length=3, max_length=150)
    severity: HealthEntrySeverity | None = None
    detail: str | None = Field(default=None, max_length=500)
    date: str | None = Field(default=None, max_length=30)
    active: bool | None = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not _NAME_PATTERN.match(cleaned):
            raise ValueError("El nombre solo puede contener letras y espacios")
        return cleaned

    @field_validator("date")
    @classmethod
    def validate_date(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            return ""
        if not _APPROX_DATE_PATTERN.match(cleaned):
            raise ValueError("Fecha aproximada invalida")
        return cleaned


class HealthEntryListResponse(BaseModel):
    items: list[HealthEntryRead]
