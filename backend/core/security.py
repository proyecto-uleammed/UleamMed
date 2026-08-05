import hashlib
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
from jose import JWTError, jwt

from backend.core.config import settings

# Prefijo para reconocer hashes generados por esta implementacion.
HASH_PREFIX = "bcrypt-sha256$"


def _normalize_password(password: str) -> bytes:
    """Convierte la contrasena a SHA-256 antes de enviarla a bcrypt."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest().encode("ascii")


def verify_password(plain_password: str, password_hash: str) -> bool:
    """Compara una contrasena enviada por el usuario contra el hash guardado."""
    if not password_hash.startswith(HASH_PREFIX):
        return False

    stored_hash = password_hash.removeprefix(HASH_PREFIX).encode("utf-8")
    normalized_password = _normalize_password(plain_password)
    return bcrypt.checkpw(normalized_password, stored_hash)


def generate_password_hash(password: str) -> str:
    """Genera el hash seguro que se guarda en la tabla de usuarios."""
    normalized_password = _normalize_password(password)
    return HASH_PREFIX + bcrypt.hashpw(normalized_password, bcrypt.gensalt()).decode("utf-8")


def create_token(
    subject: str,
    expires_delta: timedelta,
    token_type: str,
    extra_data: dict[str, Any] | None = None,
) -> str:
    """Crea un JWT con identificador de usuario, tipo de token y expiracion."""
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    if extra_data:
        payload.update(extra_data)

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_access_token(subject: str) -> str:
    """Crea el token corto que la app envia en Authorization: Bearer."""
    return create_token(
        subject=subject,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        token_type="access",
    )


def create_refresh_token(subject: str) -> str:
    """Crea el token largo que permite renovar la sesion."""
    return create_token(
        subject=subject,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        token_type="refresh",
    )


def decode_token(token: str) -> dict[str, Any]:
    """Valida la firma del JWT y devuelve su contenido."""
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError as exc:
        raise ValueError("Token invalido o expirado") from exc
