from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class CaregiverJoinAttempt(Base):
    __tablename__ = "caregiver_join_attempts"
    __table_args__ = (
        Index(
            "ix_caregiver_join_attempts_user_time",
            "caregiver_user_id",
            "attempted_at",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    caregiver_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )
    attempted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    successful: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
