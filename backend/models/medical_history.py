from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicalHistory(Base):
    __tablename__ = "medical_histories"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    older_adult_id: Mapped[int] = mapped_column(ForeignKey("older_adults.id"), nullable=False)

    visit_date: Mapped[date] = mapped_column(Date, nullable=False)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    weight: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    height: Mapped[Decimal | None] = mapped_column(Numeric(4, 2), nullable=True)
    body_mass_index: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    blood_pressure: Mapped[str | None] = mapped_column(String(20), nullable=True)
    heart_rate: Mapped[int | None] = mapped_column(Integer, nullable=True)
    temperature: Mapped[Decimal | None] = mapped_column(Numeric(4, 1), nullable=True)
    oxygen_saturation: Mapped[int | None] = mapped_column(Integer, nullable=True)
    glucose_level: Mapped[Decimal | None] = mapped_column(Numeric(6, 2), nullable=True)
    pain_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    general_condition: Mapped[str | None] = mapped_column(String(255), nullable=True)
    diagnosis: Mapped[str | None] = mapped_column(String(500), nullable=True)
    indicated_treatment: Mapped[str | None] = mapped_column(String(500), nullable=True)
    recommendations: Mapped[str | None] = mapped_column(String(500), nullable=True)
    doctor_name: Mapped[str | None] = mapped_column(String(150), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
