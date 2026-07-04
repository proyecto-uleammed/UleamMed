# backend/models/cumplimiento_medicacion.py
from datetime import date, datetime, time
from sqlalchemy import Date, DateTime, ForeignKey, String, Time, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class CumplimientoMedicacion(Base):
    __tablename__ = "cumplimiento_medicacion"

    id_cumplimiento: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_tratamiento_medicamento: Mapped[int] = mapped_column(ForeignKey("tratamiento_medicamento.id_tratamiento_medicamento"), nullable=False)

    fecha_programada: Mapped[date] = mapped_column(Date, nullable=False)
    hora_programada: Mapped[time] = mapped_column(Time, nullable=False)
    fecha_hora_real: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    estado: Mapped[str] = mapped_column(String(50), nullable=False)
    observacion: Mapped[str | None] = mapped_column(String(500), nullable=True)
    registrado_por: Mapped[str | None] = mapped_column(String(100), nullable=True)
    confirmado_por: Mapped[str | None] = mapped_column(String(100), nullable=True)
    fecha_registro: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)