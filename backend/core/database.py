from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from backend.core.config import settings


# Engine global de SQLAlchemy. Usa la DATABASE_URL definida en .env.
# La estructura final de tablas/migraciones queda a cargo del companero de BD.
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

# Fabrica de sesiones: cada peticion recibe su propia sesion de BD.
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """Clase base de la que heredan todos los modelos ORM del backend."""

    pass


def get_db() -> Generator[Session, None, None]:
    """Abre una sesion de base de datos y la cierra al terminar la peticion."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
