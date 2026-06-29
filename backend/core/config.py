from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuracion global del backend cargada desde variables de entorno."""

    # Datos visibles de la API en Swagger/ReDoc.
    PROJECT_NAME: str = "UleamMed API"
    VERSION: str = "0.1.0"
    API_V1_PREFIX: str = "/api/v1"

    # Conexion preparada para PostgreSQL. El modelado y migraciones los maneja
    # el companero encargado de base de datos.
    DATABASE_URL: str = Field(
        default="postgresql+psycopg://user:pass@localhost:5432/uleammed",
        description="Cadena de conexion de PostgreSQL utilizada por SQLAlchemy.",
    )

    # Valores usados para firmar y configurar los tokens JWT.
    SECRET_KEY: str = Field(
        default="change-this-secret-key",
        description="Clave secreta utilizada para firmar tokens JWT.",
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    FIREBASE_CREDENTIALS: str | None = None
    ENVIRONMENT: str = "development"

    # Pydantic Settings lee el archivo .env local, que no se sube a Git.
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Devuelve una unica instancia cacheada de configuracion."""
    return Settings()


# Instancia compartida que usa el resto del backend.
settings = get_settings()
