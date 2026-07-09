from datetime import UTC, datetime, timedelta
import hashlib
import secrets

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.core.config import settings
from backend.core.roles import UserRole
from backend.core.security import (
    create_access_token,
    create_refresh_token,
    generate_password_hash,
    verify_password,
)
from backend.models.password_reset_token import PasswordResetToken
from backend.models.user import User
from backend.schemas.user import TokenPair, UserCreate


def get_user_by_email(db: Session, email: str) -> User | None:
    """Busca un usuario por correo, normalizando a minusculas."""
    statement = select(User).where(User.email == email.lower())
    return db.scalar(statement)


def get_user_by_id(db: Session, user_id: int) -> User | None:
    """Busca un usuario por su identificador primario."""
    return db.get(User, user_id)


def create_user(db: Session, payload: UserCreate) -> User:
    """Crea un usuario con contrasena hasheada y lo guarda en la BD."""
    user = User(
        email=payload.email.lower(),
        full_name=payload.full_name,
        hashed_password=generate_password_hash(payload.password),
        role=UserRole.PATIENT,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User | None:
    """Valida correo y contrasena; devuelve None si las credenciales fallan."""
    user = get_user_by_email(db, email)
    if user is None:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user


def create_tokens_for_user(user: User) -> TokenPair:
    """Genera access token y refresh token para un usuario valido."""
    subject = str(user.id)
    return TokenPair(
        access_token=create_access_token(subject),
        refresh_token=create_refresh_token(subject),
    )


def create_password_reset_code(db: Session, user: User) -> str:
    """Genera un codigo temporal de 6 digitos para restablecer contrasena."""
    code = f"{secrets.randbelow(1_000_000):06d}"
    now = datetime.now(UTC)

    active_tokens = db.scalars(
        select(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used_at.is_(None),
        )
    ).all()
    for token in active_tokens:
        token.used_at = now

    reset_token = PasswordResetToken(
        user_id=user.id,
        code_hash=_hash_reset_code(code),
        expires_at=now + timedelta(minutes=settings.PASSWORD_RESET_CODE_EXPIRE_MINUTES),
    )
    db.add(reset_token)
    db.commit()
    return code


def reset_password_with_code(
    db: Session,
    *,
    email: str,
    code: str,
    new_password: str,
) -> bool:
    """Valida el codigo vigente y cambia la contrasena del usuario."""
    user = get_user_by_email(db, email)
    if user is None or not user.is_active:
        return False

    now = datetime.now(UTC)
    code_hash = _hash_reset_code(code)
    reset_token = db.scalar(
        select(PasswordResetToken)
        .where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.code_hash == code_hash,
            PasswordResetToken.used_at.is_(None),
        )
        .order_by(PasswordResetToken.created_at.desc())
    )
    if reset_token is None:
        return False

    expires_at = reset_token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    if expires_at < now:
        reset_token.used_at = now
        db.add(reset_token)
        db.commit()
        return False

    user.hashed_password = generate_password_hash(new_password)
    reset_token.used_at = now
    db.add(user)
    db.add(reset_token)
    db.commit()
    return True


def _hash_reset_code(code: str) -> str:
    return hashlib.sha256(code.strip().encode("utf-8")).hexdigest()
