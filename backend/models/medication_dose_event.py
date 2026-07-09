from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicationDoseEvent(Base):
    __tablename__ = "medication_dose_events"
    __table_args__ = (
        UniqueConstraint("client_event_id", name="uq_medication_dose_event_client"),
        UniqueConstraint(
            "medication_id",
            "scheduled_at",
            name="uq_medication_dose_event_schedule",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    medication_id: Mapped[int] = mapped_column(
        ForeignKey("medications.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    client_event_id: Mapped[str] = mapped_column(String(64), nullable=False)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False)
    acted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    snoozed_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
