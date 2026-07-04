# backend/models/adulto_mayor.py
from datetime import date, datetime
from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class AdultoMayor(Base):
    __tablename__ = "adulto_mayor"

    id_adulto_mayor: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_usuario: Mapped[int] = mapped_column(ForeignKey("usuario.id_usuario"), nullable=False, unique=True)
    id_encargado: Mapped[int] = mapped_column(ForeignKey("encargado.id_encargado"), nullable=False)

    nombres: Mapped[str] = mapped_column(String(100), nullable=False)
    apellidos: Mapped[str] = mapped_column(String(100), nullable=False)
    cedula: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    fecha_nacimiento: Mapped[date] = mapped_column(Date, nullable=False)
    telefono: Mapped[str | None] = mapped_column(String(20), nullable=True)
    direccion: Mapped[str | None] = mapped_column(String(255), nullable=True)

    fecha_creacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    fecha_actualizacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)