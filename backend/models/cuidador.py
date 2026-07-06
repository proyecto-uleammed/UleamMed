from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class Cuidador(Base):
    __tablename__ = "cuidador"

    id_cuidador: Mapped[int] = mapped_column(primary_key=True, index=True)

    id_usuario: Mapped[int] = mapped_column(
        ForeignKey("usuario.id_usuario"),
        nullable=False,
        unique=True,
    )

    nombres: Mapped[str] = mapped_column(String(100), nullable=False)
    apellidos: Mapped[str] = mapped_column(String(100), nullable=False)
    telefono: Mapped[str | None] = mapped_column(String(20), nullable=True)
    especialidad: Mapped[str | None] = mapped_column(String(100), nullable=True)

    fecha_creacion: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    fecha_actualizacion: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)