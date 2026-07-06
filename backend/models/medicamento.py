# backend/models/medicamento.py
from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class Medicamento(Base):
    __tablename__ = "medicamento"

    id_medicamento: Mapped[int] = mapped_column(primary_key=True, index=True)
    nombre: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(String(500), nullable=True)
    presentacion: Mapped[str | None] = mapped_column(String(100), nullable=True)
    fabricante: Mapped[str | None] = mapped_column(String(150), nullable=True)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)