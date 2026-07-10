from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicationSyncOperation(Base):
    """Operacion offline procesada de forma idempotente."""

    __tablename__ = "medication_sync_operations"
    __table_args__ = (
        UniqueConstraint(
            "patient_user_id",
            "client_operation_id",
            name="uq_medication_sync_operation_patient_client",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    patient_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    actor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    client_operation_id: Mapped[str] = mapped_column(String(100), nullable=False)
    client_medication_id: Mapped[str | None] = mapped_column(String(100), index=True, nullable=True)
    operation_type: Mapped[str] = mapped_column(String(40), nullable=False)
    result_status: Mapped[str] = mapped_column(String(40), nullable=False)
    medication_id: Mapped[int | None] = mapped_column(ForeignKey("medications.id"), nullable=True)
    conflict_id: Mapped[int | None] = mapped_column(
        ForeignKey("medication_sync_conflicts.id"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

