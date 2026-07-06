# backend/models/tratamiento_medicamento.py
from datetime import time
from sqlalchemy import ForeignKey, String, Time
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class TratamientoMedicamento(Base):
    __tablename__ = "tratamiento_medicamento"

    id_tratamiento_medicamento: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_tratamiento: Mapped[int] = mapped_column(ForeignKey("tratamiento.id_tratamiento"), nullable=False)
    id_medicamento: Mapped[int] = mapped_column(ForeignKey("medicamento.id_medicamento"), nullable=False)

    dosis: Mapped[str] = mapped_column(String(100), nullable=False)
    frecuencia: Mapped[str] = mapped_column(String(100), nullable=False)
    via_administracion: Mapped[str | None] = mapped_column(String(100), nullable=True)
    hora_inicio: Mapped[time | None] = mapped_column(Time, nullable=True)
    hora_fin: Mapped[time | None] = mapped_column(Time, nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String(500), nullable=True)