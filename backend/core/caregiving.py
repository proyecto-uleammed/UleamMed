from enum import StrEnum


class CaregiverLinkStatus(StrEnum):
    """Estados posibles de una vinculacion paciente-cuidador."""

    PENDING = "pending"
    ACTIVE = "active"
    REJECTED = "rejected"
    REVOKED = "revoked"
