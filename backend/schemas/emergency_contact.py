import re

from pydantic import BaseModel, Field, field_validator

_NAME_PATTERN = re.compile(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]+$")
_PHONE_DIGITS = re.compile(r"\D")


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
        digits = _PHONE_DIGITS.sub("", value.strip())
        if len(digits) < 7 or len(digits) > 15:
            raise ValueError("Telefono invalido")
        return value.strip()


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
        digits = _PHONE_DIGITS.sub("", value.strip())
        if len(digits) < 7 or len(digits) > 15:
            raise ValueError("Telefono invalido")
        return value.strip()


class EmergencyContactListResponse(BaseModel):
    items: list[EmergencyContactRead]
