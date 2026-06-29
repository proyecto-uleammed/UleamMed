from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.security import crear_access_token, decodificar_token
from backend.schemas.user import AccessToken, LoginRequest, RefreshRequest, TokenPair, UserCreate, UserRead
from backend.services.auth_service import (
    autenticar_usuario,
    crear_tokens_para_usuario,
    crear_usuario,
    obtener_usuario_por_email,
    obtener_usuario_por_id,
)


router = APIRouter(prefix="/auth", tags=["autenticacion"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def registrar_usuario(datos: UserCreate, db: Session = Depends(get_db)) -> UserRead:
    if obtener_usuario_por_email(db, datos.email) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un usuario registrado con ese correo",
        )

    return crear_usuario(db, datos)


@router.post("/login", response_model=TokenPair)
def iniciar_sesion(datos: LoginRequest, db: Session = Depends(get_db)) -> TokenPair:
    usuario = autenticar_usuario(db, datos.email, datos.password)
    if usuario is None or not usuario.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contrasena incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return crear_tokens_para_usuario(usuario)


@router.post("/refresh", response_model=AccessToken)
def renovar_access_token(datos: RefreshRequest, db: Session = Depends(get_db)) -> AccessToken:
    try:
        payload = decodificar_token(datos.refresh_token)
        user_id = payload.get("sub")
        token_type = payload.get("type")
        if user_id is None or token_type != "refresh":
            raise ValueError("Token de renovacion invalido")
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    usuario = obtener_usuario_por_id(db, int(user_id))
    if usuario is None or not usuario.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no disponible para renovar sesion",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return AccessToken(access_token=crear_access_token(str(usuario.id)))
