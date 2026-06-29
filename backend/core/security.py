from datetime import UTC, datetime, timedelta
import hashlib
from typing import Any

import bcrypt
from jose import JWTError, jwt

from backend.core.config import settings


HASH_PREFIX = "bcrypt-sha256$"


def _normalizar_password(password: str) -> bytes:
    return hashlib.sha256(password.encode("utf-8")).hexdigest().encode("ascii")


def verificar_password(password_plano: str, password_hash: str) -> bool:
    if not password_hash.startswith(HASH_PREFIX):
        return False

    hash_guardado = password_hash.removeprefix(HASH_PREFIX).encode("utf-8")
    password_normalizado = _normalizar_password(password_plano)
    return bcrypt.checkpw(password_normalizado, hash_guardado)


def generar_password_hash(password: str) -> str:
    password_normalizado = _normalizar_password(password)
    return HASH_PREFIX + bcrypt.hashpw(password_normalizado, bcrypt.gensalt()).decode("utf-8")


def crear_token(
    subject: str,
    expires_delta: timedelta,
    tipo: str,
    datos_extra: dict[str, Any] | None = None,
) -> str:
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
    return crear_token(
        subject=subject,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        tipo="access",
    )


def crear_refresh_token(subject: str) -> str:
    return crear_token(
        subject=subject,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        tipo="refresh",
    )


def decodificar_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError as exc:
        raise ValueError("Token invalido o expirado") from exc
