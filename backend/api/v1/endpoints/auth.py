from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.security import create_access_token, decode_token
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
    send_password_reset_email,
    send_password_updated_email,
    send_welcome_email,
)
from backend.services.auth_service import (
    authenticate_user,
    create_password_reset_code,
    create_tokens_for_user,
    create_user,
    get_user_by_email,
    get_user_by_id,
    reset_password_with_code,
)
from backend.core.config import settings


# Todas las rutas de este archivo quedan bajo /api/v1/auth.
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def register_user(payload: UserCreate, db: Session = Depends(get_db)) -> UserRead:
    """Registra un usuario nuevo si el correo aun no existe."""
    if get_user_by_email(db, payload.email) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un usuario registrado con ese correo",
        )

    user = create_user(db, payload)
    send_welcome_email(user)
    return user


@router.post("/login", response_model=TokenPair)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenPair:
    """Valida credenciales y devuelve access token mas refresh token."""
    user = authenticate_user(db, payload.email, payload.password)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contrasena incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return create_tokens_for_user(user)


@router.post("/refresh", response_model=AccessToken)
def refresh_access_token(payload: RefreshRequest, db: Session = Depends(get_db)) -> AccessToken:
    """Usa un refresh token valido para entregar un nuevo access token."""
    try:
        # Solo se aceptan tokens creados como refresh, no access tokens.
        token_payload = decode_token(payload.refresh_token)
        user_id = token_payload.get("sub")
        token_type = token_payload.get("type")
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
    user = get_user_by_id(db, user_id_int)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario no disponible para renovar sesion",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return AccessToken(access_token=create_access_token(str(user.id)))


@router.post("/forgot-password", response_model=MessageResponse)
def request_password_reset(
    payload: PasswordResetRequest,
    db: Session = Depends(get_db),
) -> MessageResponse:
    """Genera un codigo temporal y lo envia por correo si la cuenta existe."""
    user = get_user_by_email(db, payload.email)
    if user is not None and user.is_active:
        code = create_password_reset_code(db, user)
        send_password_reset_email(
            user=user,
            code=code,
            expiration_minutes=settings.PASSWORD_RESET_CODE_EXPIRE_MINUTES,
        )

    return MessageResponse(
        message="Si el correo existe, enviaremos instrucciones para restablecer la contrasena.",
    )


@router.post("/reset-password", response_model=MessageResponse)
def confirm_password_reset(
    payload: PasswordResetConfirm,
    db: Session = Depends(get_db),
) -> MessageResponse:
    """Cambia la contrasena usando el codigo temporal enviado por correo."""
    updated = reset_password_with_code(
        db,
        email=payload.email,
        code=payload.code,
        new_password=payload.new_password,
    )
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Codigo invalido o expirado",
        )

    user = get_user_by_email(db, payload.email)
    if user is not None:
        send_password_updated_email(user)

    return MessageResponse(message="Contrasena actualizada correctamente.")
