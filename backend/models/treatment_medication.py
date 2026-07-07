from datetime import time

from sqlalchemy import ForeignKey, String, Time
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class TreatmentMedication(Base):
    __tablename__ = "treatment_medications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    treatment_id: Mapped[int] = mapped_column(ForeignKey("treatments.id"), nullable=False)
    medication_catalog_id: Mapped[int] = mapped_column(ForeignKey("medication_catalog.id"), nullable=False)

    dose: Mapped[str] = mapped_column(String(100), nullable=False)
    frequency: Mapped[str] = mapped_column(String(100), nullable=False)
    administration_route: Mapped[str | None] = mapped_column(String(100), nullable=True)
    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    end_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
