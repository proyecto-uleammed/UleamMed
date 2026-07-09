from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.roles import UserRole
from backend.core.security import decode_token
from backend.models.user import User
from backend.services.auth_service import get_user_by_id


# FastAPI usa esta configuracion para leer el token Bearer del header Authorization.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Obtiene el usuario autenticado desde el access token."""
    invalid_credentials = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # El token debe estar firmado correctamente y ser de tipo access.
        payload = decode_token(token)
        user_id = payload.get("sub")
        token_type = payload.get("type")
        if user_id is None or token_type != "access":
            raise invalid_credentials
    except ValueError as exc:
        raise invalid_credentials from exc

    try:
        user_id_int = int(user_id)
    except (TypeError, ValueError) as exc:
        raise invalid_credentials from exc

    # Si el usuario no existe o esta inactivo, la ruta se considera no autorizada.
    user = get_user_by_id(db, user_id_int)
    if user is None or not user.is_active:
        raise invalid_credentials

    return user


def get_current_patient(current_user: User = Depends(get_current_user)) -> User:
    """Autoriza unicamente cuentas con el rol funcional de paciente."""
    if current_user.role != UserRole.PATIENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Esta funcion esta disponible unicamente para pacientes",
        )
    return current_user
