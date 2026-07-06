# backend/models/cuidador_adulto_mayor.py
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column
from backend.core.database import Base

class CuidadorAdultoMayor(Base):
    __tablename__ = "cuidador_adulto_mayor"
    __table_args__ = (
        UniqueConstraint("id_cuidador", "id_adulto_mayor", name="uq_cuidador_adulto_mayor"),
    )

    id_relacion: Mapped[int] = mapped_column(primary_key=True, index=True)
    id_cuidador: Mapped[int] = mapped_column(ForeignKey("cuidador.id_cuidador"), nullable=False)
    id_adulto_mayor: Mapped[int] = mapped_column(ForeignKey("adulto_mayor.id_adulto_mayor"), nullable=False)
    fecha_vinculacion: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)