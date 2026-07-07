from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.security import crear_access_token, decodificar_token
from backend.schemas.user import (
    AccessToken,
    LoginRequest,
    MessageResponse,
    PasswordResetConfirm,
    PasswordResetRequest,
    RefreshRequest,
    TokenPair,
    UserCreate,
    UserRead,
)
from backend.services.email_service import (
    enviar_correo_bienvenida,
    enviar_correo_password_actualizado,
    enviar_correo_recuperacion,
)
from backend.services.auth_service import (
    autenticar_usuario,
    crear_codigo_recuperacion,
    crear_tokens_para_usuario,
    crear_usuario,
    obtener_usuario_por_email,
    obtener_usuario_por_id,
    restablecer_password_con_codigo,
)
from backend.core.config import settings


# Todas las rutas de este archivo quedan bajo /api/v1/auth.
router = APIRouter(prefix="/auth", tags=["autenticacion"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def registrar_usuario(datos: UserCreate, db: Session = Depends(get_db)) -> UserRead:
    """Registra un usuario nuevo si el correo aun no existe."""
    if obtener_usuario_por_email(db, datos.email) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un usuario registrado con ese correo",
        )

    usuario = crear_usuario(db, datos)
    enviar_correo_bienvenida(usuario)
    return usuario


@router.post("/login", response_model=TokenPair)
def iniciar_sesion(datos: LoginRequest, db: Session = Depends(get_db)) -> TokenPair:
    """Valida credenciales y devuelve access token mas refresh token."""
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
    """Usa un refresh token valido para entregar un nuevo access token."""
    try:
        # Solo se aceptan tokens creados como refresh, no access tokens.
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

    try:
        user_id_int = int(user_id)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    # Antes de renovar, confirma que el usuario sigue existiendo y activo.
    usuario = obtener_usuario_por_id(db, user_id_int)
    if usuario is None or not usuario.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no disponible para renovar sesion",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return AccessToken(access_token=crear_access_token(str(usuario.id)))


@router.post("/forgot-password", response_model=MessageResponse)
def solicitar_recuperacion_password(
    datos: PasswordResetRequest,
    db: Session = Depends(get_db),
) -> MessageResponse:
    """Genera un codigo temporal y lo envia por correo si la cuenta existe."""
    usuario = obtener_usuario_por_email(db, datos.email)
    if usuario is not None and usuario.is_active:
        codigo = crear_codigo_recuperacion(db, usuario)
        enviar_correo_recuperacion(
            usuario=usuario,
            codigo=codigo,
            minutos_expiracion=settings.PASSWORD_RESET_CODE_EXPIRE_MINUTES,
        )

    return MessageResponse(
        message="Si el correo existe, enviaremos instrucciones para restablecer la contrasena.",
    )


@router.post("/reset-password", response_model=MessageResponse)
def confirmar_recuperacion_password(
    datos: PasswordResetConfirm,
    db: Session = Depends(get_db),
) -> MessageResponse:
    """Cambia la contrasena usando el codigo temporal enviado por correo."""
    actualizado = restablecer_password_con_codigo(
        db,
        email=datos.email,
        codigo=datos.code,
        nueva_password=datos.new_password,
    )
    if not actualizado:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Codigo invalido o expirado",
        )

    usuario = obtener_usuario_por_email(db, datos.email)
    if usuario is not None:
        enviar_correo_password_actualizado(usuario)

    return MessageResponse(message="Contrasena actualizada correctamente.")
