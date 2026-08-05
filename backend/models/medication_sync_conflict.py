from datetime import datetime

from sqlalchemy import JSON, DateTime, Float, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicationSyncConflict(Base):
    """Posible duplicado que debe decidir el paciente."""

    __tablename__ = "medication_sync_conflicts"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    patient_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    actor_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    candidate_medication_id: Mapped[int | None] = mapped_column(
        ForeignKey("medications.id"),
        nullable=True,
    )
    resolved_medication_id: Mapped[int | None] = mapped_column(
        ForeignKey("medications.id"),
        nullable=True,
    )
    incoming_client_medication_id: Mapped[str | None] = mapped_column(
        String(100),
        index=True,
        nullable=True,
    )
    incoming_payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    similarity_score: Mapped[float] = mapped_column(Float, nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="pending", server_default="pending", nullable=False)
    resolution: Mapped[str | None] = mapped_column(String(30), nullable=True)
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
