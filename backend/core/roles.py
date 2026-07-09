from enum import StrEnum


class UserRole(StrEnum):
    """Roles funcionales reconocidos por UleamMed."""

    PATIENT = "patient"
    CAREGIVER = "caregiver"
    PROFESSIONAL = "professional"
    ADMIN = "admin"
