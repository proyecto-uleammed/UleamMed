from datetime import datetime, time
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, Time, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.core.database import Base

if TYPE_CHECKING:
    from backend.models.medication_schedule import MedicationSchedule


class Medication(Base):
    """Medicamento personal registrado por un usuario de la app."""

    __tablename__ = "medications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    last_modified_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    client_medication_id: Mapped[str | None] = mapped_column(String(100), index=True, nullable=True)
    sync_fingerprint: Mapped[str | None] = mapped_column(String(160), index=True, nullable=True)
    dose: Mapped[str] = mapped_column(String(100), nullable=False)
    dose_amount: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    dose_unit: Mapped[str | None] = mapped_column(String(30), nullable=True)
    frequency: Mapped[str | None] = mapped_column(String(100), nullable=True)
    duration: Mapped[str | None] = mapped_column(String(100), nullable=True)
    schedule_time: Mapped[time | None] = mapped_column(Time(timezone=False), nullable=True)
    instructions: Mapped[str | None] = mapped_column(String(500), nullable=True)
    photo_path: Mapped[str | None] = mapped_column(String(500), nullable=True)

    taken: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    is_important: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    schedule: Mapped["MedicationSchedule | None"] = relationship(
        back_populates="medication",
        cascade="all, delete-orphan",
        uselist=False,
    )
