# backend/models/examen_medico.py
from datetime import date
from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class ExamenMedico(Base):
    __tablename__ = "examen_medico"

    id_examen: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_historial: Mapped[int] = mapped_column(ForeignKey("historial_medico.id_historial"), nullable=False)

    nombre_examen: Mapped[str] = mapped_column(String(150), nullable=False)
    fecha_examen: Mapped[date | None] = mapped_column(Date, nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String(500), nullable=True)
    archivo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    tipo_archivo: Mapped[str | None] = mapped_column(String(50), nullable=True)
    fecha_subida: Mapped[date | None] = mapped_column(Date, nullable=True)