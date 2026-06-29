from datetime import UTC, datetime, timedelta
import hashlib
from typing import Any

import bcrypt
from jose import JWTError, jwt

from backend.core.config import settings


# Prefijo para reconocer hashes generados por esta implementacion.
HASH_PREFIX = "bcrypt-sha256$"


def _normalizar_password(password: str) -> bytes:
    """Convierte la contrasena a SHA-256 antes de enviarla a bcrypt."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest().encode("ascii")


def verificar_password(password_plano: str, password_hash: str) -> bool:
    """Compara una contrasena enviada por el usuario contra el hash guardado."""
    if not password_hash.startswith(HASH_PREFIX):
        return False

    hash_guardado = password_hash.removeprefix(HASH_PREFIX).encode("utf-8")
    password_normalizado = _normalizar_password(password_plano)
    return bcrypt.checkpw(password_normalizado, hash_guardado)


def generar_password_hash(password: str) -> str:
    """Genera el hash seguro que se guarda en la tabla de usuarios."""
    password_normalizado = _normalizar_password(password)
    return HASH_PREFIX + bcrypt.hashpw(password_normalizado, bcrypt.gensalt()).decode("utf-8")


def crear_token(
    subject: str,
    expires_delta: timedelta,
    tipo: str,
    datos_extra: dict[str, Any] | None = None,
) -> str:
    """Crea un JWT con identificador de usuario, tipo de token y expiracion."""
    ahora = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": tipo,
        "iat": ahora,
        "exp": ahora + expires_delta,
    }
    if datos_extra:
        payload.update(datos_extra)

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def crear_access_token(subject: str) -> str:
    """Crea el token corto que la app envia en Authorization: Bearer."""
    return crear_token(
        subject=subject,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        tipo="access",
    )


def crear_refresh_token(subject: str) -> str:
    """Crea el token largo que permite renovar la sesion."""
    return crear_token(
        subject=subject,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        tipo="refresh",
    )


def decodificar_token(token: str) -> dict[str, Any]:
    """Valida la firma del JWT y devuelve su contenido."""
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError as exc:
        raise ValueError("Token invalido o expirado") from exc
