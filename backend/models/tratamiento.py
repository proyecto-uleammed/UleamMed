# backend/models/tratamiento.py
from datetime import date, datetime
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class Tratamiento(Base):
    __tablename__ = "tratamiento"

    id_tratamiento: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_adulto_mayor: Mapped[int] = mapped_column(ForeignKey("adulto_mayor.id_adulto_mayor"), nullable=False)

    nombre_tratamiento: Mapped[str] = mapped_column(String(150), nullable=False)
    objetivo: Mapped[str | None] = mapped_column(String(500), nullable=True)
    fecha_inicio: Mapped[date] = mapped_column(Date, nullable=False)
    fecha_fin: Mapped[date | None] = mapped_column(Date, nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String(500), nullable=True)
    fecha_creacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    fecha_actualizacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)