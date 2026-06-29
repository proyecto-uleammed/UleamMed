from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class User(Base):
    """Modelo ORM del usuario que consume el backend.

    La tabla real y sus migraciones deben coordinarse con el companero que
    administra PostgreSQL/Alembic. Este modelo define el contrato que usa la API.
    """

    __tablename__ = "users"

    # Identificador interno del usuario.
    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Correo unico para login y busqueda de usuario.
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)

    # Nombre visible que puede editar el usuario desde su perfil.
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Hash de la contrasena. Nunca se guarda la contrasena en texto plano.
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)

    # Permite bloquear cuentas sin borrar sus datos.
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Fecha en que la base de datos crea el registro.
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # Fecha que se actualiza cuando cambia el usuario.
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
