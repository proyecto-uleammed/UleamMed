# backend/models/detalle_examen.py
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class DetalleExamen(Base):
    __tablename__ = "detalle_examen"

    id_detalle: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_examen: Mapped[int] = mapped_column(ForeignKey("examen_medico.id_examen"), nullable=False)

    nombre_detalle: Mapped[str] = mapped_column(String(150), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(String(500), nullable=True)