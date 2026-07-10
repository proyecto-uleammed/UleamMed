from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class Appointment(Base):
    """Consulta medica programada para un paciente."""

    __tablename__ = "appointments"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)

    doctor: Mapped[str] = mapped_column(String(150), nullable=False)
    specialty: Mapped[str] = mapped_column(String(150), nullable=False)
    location: Mapped[str] = mapped_column(String(250), nullable=False, default="", server_default="")
    notes: Mapped[str] = mapped_column(String(1000), nullable=False, default="", server_default="")
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    reminder: Mapped[str] = mapped_column(String(30), nullable=False, default="none", server_default="none")
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
