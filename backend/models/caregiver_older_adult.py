from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class CaregiverOlderAdult(Base):
    __tablename__ = "caregiver_older_adults"
    __table_args__ = (
        UniqueConstraint("caregiver_id", "older_adult_id", name="uq_caregiver_older_adults"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    caregiver_id: Mapped[int] = mapped_column(ForeignKey("caregivers.id"), nullable=False)
    older_adult_id: Mapped[int] = mapped_column(ForeignKey("older_adults.id"), nullable=False)
    linked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
