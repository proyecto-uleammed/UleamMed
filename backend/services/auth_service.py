from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.core.security import (
    crear_access_token,
    crear_refresh_token,
    generar_password_hash,
    verificar_password,
)
from backend.models.user import User
from backend.schemas.user import TokenPair, UserCreate


def obtener_usuario_por_email(db: Session, email: str) -> User | None:
    statement = select(User).where(User.email == email.lower())
    return db.scalar(statement)


def obtener_usuario_por_id(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def crear_usuario(db: Session, datos: UserCreate) -> User:
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
    usuario = obtener_usuario_por_email(db, email)
    if usuario is None:
        return None
    if not verificar_password(password, usuario.hashed_password):
        return None
    return usuario


def crear_tokens_para_usuario(usuario: User) -> TokenPair:
    subject = str(usuario.id)
    return TokenPair(
        access_token=crear_access_token(subject),
        refresh_token=crear_refresh_token(subject),
    )
