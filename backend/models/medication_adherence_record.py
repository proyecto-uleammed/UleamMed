from datetime import date, datetime, time

from sqlalchemy import Date, DateTime, ForeignKey, String, Time, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicationAdherenceRecord(Base):
    __tablename__ = "medication_adherence_records"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    treatment_medication_id: Mapped[int] = mapped_column(ForeignKey("treatment_medications.id"), nullable=False)

    scheduled_date: Mapped[date] = mapped_column(Date, nullable=False)
    scheduled_time: Mapped[time] = mapped_column(Time, nullable=False)
    actual_datetime: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    recorded_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    confirmed_by: Mapped[str | None] = mapped_column(String(100), nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
