from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class UserMedicalProfile(Base):
    """Perfil medico del paciente en la app movil."""

    __tablename__ = "user_medical_profiles"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        index=True,
        nullable=False,
        unique=True,
    )

    birth_date: Mapped[str] = mapped_column(String(10), nullable=False, default="", server_default="")
    blood_type: Mapped[str] = mapped_column(String(3), nullable=False, default="", server_default="")
    conditions: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default="")
    allergies: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default="")
    important_notes: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default="")
    emergency_contact_name: Mapped[str] = mapped_column(String(80), nullable=False, default="", server_default="")
    emergency_contact_phone: Mapped[str] = mapped_column(String(20), nullable=False, default="", server_default="")
    share_with_caregivers: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )
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
