from datetime import UTC, datetime, timedelta
import hashlib
import secrets

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.core.config import settings
from backend.core.security import (
    crear_access_token,
    crear_refresh_token,
    generar_password_hash,
    verificar_password,
)
from backend.models.password_reset_token import PasswordResetToken
from backend.models.user import User
from backend.schemas.user import TokenPair, UserCreate


def obtener_usuario_por_email(db: Session, email: str) -> User | None:
    """Busca un usuario por correo, normalizando a minusculas."""
    statement = select(User).where(User.email == email.lower())
    return db.scalar(statement)


def obtener_usuario_por_id(db: Session, user_id: int) -> User | None:
    """Busca un usuario por su identificador primario."""
    return db.get(User, user_id)


def crear_usuario(db: Session, datos: UserCreate) -> User:
    """Crea un usuario con contrasena hasheada y lo guarda en la BD."""
    usuario = User(
        email=datos.email.lower(),
        full_name=datos.full_name,
        hashed_password=generar_password_hash(datos.password),
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


def autenticar_usuario(db: Session, email: str, password: str) -> User | None:
    """Valida correo y contrasena; devuelve None si las credenciales fallan."""
    usuario = obtener_usuario_por_email(db, email)
    if usuario is None:
        return None
    if not verificar_password(password, usuario.hashed_password):
        return None
    return usuario


def crear_tokens_para_usuario(usuario: User) -> TokenPair:
    """Genera access token y refresh token para un usuario valido."""
    subject = str(usuario.id)
    return TokenPair(
        access_token=crear_access_token(subject),
        refresh_token=crear_refresh_token(subject),
    )


def crear_codigo_recuperacion(db: Session, usuario: User) -> str:
    """Genera un codigo temporal de 6 digitos para restablecer contrasena."""
    codigo = f"{secrets.randbelow(1_000_000):06d}"
    ahora = datetime.now(UTC)

    tokens_activos = db.scalars(
        select(PasswordResetToken).where(
            PasswordResetToken.user_id == usuario.id,
            PasswordResetToken.used_at.is_(None),
        )
    ).all()
    for token in tokens_activos:
        token.used_at = ahora

    reset_token = PasswordResetToken(
        user_id=usuario.id,
        code_hash=_hash_codigo_recuperacion(codigo),
        expires_at=ahora + timedelta(minutes=settings.PASSWORD_RESET_CODE_EXPIRE_MINUTES),
    )
    db.add(reset_token)
    db.commit()
    return codigo


def restablecer_password_con_codigo(
    db: Session,
    *,
    email: str,
    codigo: str,
    nueva_password: str,
) -> bool:
    """Valida el codigo vigente y cambia la contrasena del usuario."""
    usuario = obtener_usuario_por_email(db, email)
    if usuario is None or not usuario.is_active:
        return False

    ahora = datetime.now(UTC)
    codigo_hash = _hash_codigo_recuperacion(codigo)
    reset_token = db.scalar(
        select(PasswordResetToken)
        .where(
            PasswordResetToken.user_id == usuario.id,
            PasswordResetToken.code_hash == codigo_hash,
            PasswordResetToken.used_at.is_(None),
        )
        .order_by(PasswordResetToken.created_at.desc())
    )
    if reset_token is None:
        return False

    expires_at = reset_token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if expires_at < ahora:
        reset_token.used_at = ahora
        db.add(reset_token)
        db.commit()
        return False

    usuario.hashed_password = generar_password_hash(nueva_password)
    reset_token.used_at = ahora
    db.add(usuario)
    db.add(reset_token)
    db.commit()
    return True


def _hash_codigo_recuperacion(codigo: str) -> str:
    return hashlib.sha256(codigo.strip().encode("utf-8")).hexdigest()
