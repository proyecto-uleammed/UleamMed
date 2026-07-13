import re

from pydantic import BaseModel, Field, field_validator

from backend.utils.phone_numbers import normalize_ecuador_phone

_NAME_PATTERN = re.compile(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]+$")


class EmergencyContactRead(BaseModel):
    id: str
    name: str
    phone: str
    relationship: str = ""
    isPrimary: bool = False


class EmergencyContactCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=80)
    phone: str = Field(..., min_length=7, max_length=20)
    relationship: str = Field(default="", max_length=50)
    isPrimary: bool = False

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not _NAME_PATTERN.match(cleaned):
            raise ValueError("El nombre solo puede contener letras")
        return cleaned

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        return normalize_ecuador_phone(value)


class EmergencyContactUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=3, max_length=80)
    phone: str | None = Field(default=None, min_length=7, max_length=20)
    relationship: str | None = Field(default=None, max_length=50)
    isPrimary: bool | None = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not _NAME_PATTERN.match(cleaned):
            raise ValueError("El nombre solo puede contener letras")
        return cleaned

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return normalize_ecuador_phone(value)


class EmergencyContactListResponse(BaseModel):
    items: list[EmergencyContactRead]
