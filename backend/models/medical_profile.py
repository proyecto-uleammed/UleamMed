from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicalProfile(Base):
    __tablename__ = "medical_profiles"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    older_adult_id: Mapped[int] = mapped_column(ForeignKey("older_adults.id"), nullable=False, unique=True)

    blood_type: Mapped[str | None] = mapped_column(String(10), nullable=True)
    allergies: Mapped[str | None] = mapped_column(String(500), nullable=True)
    chronic_diseases: Mapped[str | None] = mapped_column(String(500), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
