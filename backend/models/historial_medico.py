# backend/models/historial_medico.py
from datetime import date, datetime
from decimal import Decimal
from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class HistorialMedico(Base):
    __tablename__ = "historial_medico"

    id_historial: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_adulto_mayor: Mapped[int] = mapped_column(ForeignKey("adulto_mayor.id_adulto_mayor"), nullable=False)

    fecha_consulta: Mapped[date] = mapped_column(Date, nullable=False)
    motivo_consulta: Mapped[str | None] = mapped_column(String(255), nullable=True)
    peso: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    altura: Mapped[Decimal | None] = mapped_column(Numeric(4, 2), nullable=True)
    indice_masa_corporal: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    presion_arterial: Mapped[str | None] = mapped_column(String(20), nullable=True)
    frecuencia_cardiaca: Mapped[int | None] = mapped_column(Integer, nullable=True)
    temperatura: Mapped[Decimal | None] = mapped_column(Numeric(4, 1), nullable=True)
    saturacion_oxigeno: Mapped[int | None] = mapped_column(Integer, nullable=True)
    nivel_glucosa: Mapped[Decimal | None] = mapped_column(Numeric(6, 2), nullable=True)
    nivel_dolor: Mapped[int | None] = mapped_column(Integer, nullable=True)
    estado_general: Mapped[str | None] = mapped_column(String(255), nullable=True)
    diagnostico: Mapped[str | None] = mapped_column(String(500), nullable=True)
    tratamiento_indicado: Mapped[str | None] = mapped_column(String(500), nullable=True)
    recomendaciones: Mapped[str | None] = mapped_column(String(500), nullable=True)
    nombre_medico: Mapped[str | None] = mapped_column(String(150), nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String(500), nullable=True)
    fecha_creacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)