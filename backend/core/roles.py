from enum import StrEnum


class UserRole(StrEnum):
    """Roles funcionales reconocidos por UleamMed."""

    PATIENT = "patient"
    CAREGIVER = "caregiver"
    PROFESSIONAL = "professional"
    ADMIN = "admin"


class PublicAccountType(StrEnum):
    """Roles que una persona puede elegir durante el registro publico."""

    PATIENT = UserRole.PATIENT
    CAREGIVER = UserRole.CAREGIVER
