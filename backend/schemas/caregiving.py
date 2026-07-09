from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from backend.core.caregiving import CaregiverLinkStatus


class CaregiverInvitationRead(BaseModel):
    id: int
    code: str
    expires_at: datetime


class CaregiverInvitationRedeem(BaseModel):
    code: str = Field(..., min_length=8, max_length=12)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        normalized = value.strip().upper().replace("-", "").replace(" ", "")
        if len(normalized) != 8 or not normalized.isalnum():
            raise ValueError("El codigo debe tener 8 caracteres")
        return normalized


class CaregiverLinkRead(BaseModel):
    id: int
    status: CaregiverLinkStatus
    counterpart_user_id: int
    counterpart_name: str
    counterpart_email_masked: str
    requested_at: datetime
    decided_at: datetime | None = None
    revoked_at: datetime | None = None


class CaregiverLinkListResponse(BaseModel):
    items: list[CaregiverLinkRead]


class CaregiverPatientRead(BaseModel):
    id: int
    full_name: str


class CaregiverPatientListResponse(BaseModel):
    items: list[CaregiverPatientRead]
