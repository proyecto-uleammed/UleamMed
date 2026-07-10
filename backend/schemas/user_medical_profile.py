import re

from pydantic import BaseModel, Field, model_validator

_BIRTH_DATE_PATTERN = re.compile(r"^\d{2}/\d{2}/\d{4}$")
_BLOOD_TYPE_PATTERN = re.compile(r"^(A|B|AB|O)[+-]$")
_PHONE_DIGITS = re.compile(r"\D")
_NAME_PATTERN = re.compile(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]+$")


class UserMedicalProfileRead(BaseModel):
    birthDate: str = ""
    bloodType: str = ""
    conditions: str = ""
    allergies: str = ""
    importantNotes: str = ""
    emergencyContactName: str = ""
    emergencyContactPhone: str = ""
    shareWithCaregivers: bool = False


class UserMedicalProfileUpdate(BaseModel):
    birthDate: str = Field(default="", max_length=10)
    bloodType: str = Field(default="", max_length=3)
    conditions: str = Field(default="", max_length=1000)
    allergies: str = Field(default="", max_length=1000)
    importantNotes: str = Field(default="", max_length=1000)
    emergencyContactName: str = Field(default="", max_length=80)
    emergencyContactPhone: str = Field(default="", max_length=20)
    shareWithCaregivers: bool = False

    @model_validator(mode="after")
    def validate_profile(self) -> "UserMedicalProfileUpdate":
        birth_date = self.birthDate.strip()
        if birth_date and not _BIRTH_DATE_PATTERN.match(birth_date):
            raise ValueError("La fecha de nacimiento debe usar DD/MM/AAAA")

        blood_type = self.bloodType.strip().upper()
        if blood_type and not _BLOOD_TYPE_PATTERN.match(blood_type):
            raise ValueError("Tipo de sangre invalido. Ejemplo: O+ o AB-")

        contact_name = self.emergencyContactName.strip()
        contact_phone = self.emergencyContactPhone.strip()
        if contact_name and len(contact_name) < 3:
            raise ValueError("El nombre del contacto debe tener al menos 3 caracteres")
        if contact_name and not _NAME_PATTERN.match(contact_name):
            raise ValueError("El nombre del contacto solo puede contener letras")

        digits = _PHONE_DIGITS.sub("", contact_phone)
        if contact_name and not digits:
            raise ValueError("Ingresa el telefono del contacto de emergencia")
        if digits and (len(digits) < 7 or len(digits) > 15):
            raise ValueError("Telefono de emergencia invalido")
        if digits and not contact_name:
            raise ValueError("Ingresa el nombre del contacto de emergencia")

        return self
