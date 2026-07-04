# backend/models/notificacion.py
from datetime import datetime
from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class Notificacion(Base):
    __tablename__ = "notificacion"

    id_notificacion: Mapped[int] = mapped_column(primary_key=True, index=True)
    titulo: Mapped[str] = mapped_column(String(150), nullable=False)
    mensaje: Mapped[str] = mapped_column(String(500), nullable=False)
    fecha_envio: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    tipo: Mapped[str | None] = mapped_column(String(50), nullable=True)
    prioridad: Mapped[str | None] = mapped_column(String(50), nullable=True)
    enviada: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)