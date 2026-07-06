# backend/models/perfil_medico.py
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class PerfilMedico(Base):
    __tablename__ = "perfil_medico"

    id_perfil: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_adulto_mayor: Mapped[int] = mapped_column(ForeignKey("adulto_mayor.id_adulto_mayor"), nullable=False, unique=True)

    tipo_sangre: Mapped[str | None] = mapped_column(String(10), nullable=True)
    alergias: Mapped[str | None] = mapped_column(String(500), nullable=True)
    enfermedades_cronicas: Mapped[str | None] = mapped_column(String(500), nullable=True)
    observaciones: Mapped[str | None] = mapped_column(String(500), nullable=True)
    fecha_actualizacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)