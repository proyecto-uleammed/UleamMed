from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicationCatalog(Base):
    __tablename__ = "medication_catalog"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    presentation: Mapped[str | None] = mapped_column(String(100), nullable=True)
    manufacturer: Mapped[str | None] = mapped_column(String(150), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
