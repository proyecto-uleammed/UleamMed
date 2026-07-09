from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.caregiving import CaregiverLinkStatus
from backend.core.database import Base


class PatientCaregiverLink(Base):
    __tablename__ = "patient_caregiver_links"
    __table_args__ = (
        UniqueConstraint(
            "patient_user_id",
            "caregiver_user_id",
            name="uq_patient_caregiver_links_users",
        ),
        CheckConstraint(
            "status IN ('pending', 'active', 'rejected', 'revoked')",
            name="ck_patient_caregiver_links_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    patient_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    caregiver_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(20),
        default=CaregiverLinkStatus.PENDING,
        server_default=CaregiverLinkStatus.PENDING.value,
        nullable=False,
        index=True,
    )
    requested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
