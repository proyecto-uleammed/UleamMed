# backend/models/parametro_examen.py
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class ParametroExamen(Base):
    __tablename__ = "parametro_examen"

    id_parametro: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_detalle: Mapped[int] = mapped_column(ForeignKey("detalle_examen.id_detalle"), nullable=False)

    nombre_parametro: Mapped[str] = mapped_column(String(150), nullable=False)
    valor_obtenido: Mapped[str | None] = mapped_column(String(100), nullable=True)
    valor_referencia: Mapped[str | None] = mapped_column(String(100), nullable=True)
    unidad_medida: Mapped[str | None] = mapped_column(String(50), nullable=True)
    estado: Mapped[str | None] = mapped_column(String(50), nullable=True)