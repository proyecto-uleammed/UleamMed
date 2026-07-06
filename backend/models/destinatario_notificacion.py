# backend/models/destinatario_notificacion.py
from datetime import datetime
from sqlalchemy import Boolean, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class DestinatarioNotificacion(Base):
    __tablename__ = "destinatario_notificacion"

    id_destinatario: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_notificacion: Mapped[int] = mapped_column(ForeignKey("notificacion.id_notificacion"), nullable=False)
    id_usuario: Mapped[int] = mapped_column(ForeignKey("usuario.id_usuario"), nullable=False)

    leida: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    fecha_lectura: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)