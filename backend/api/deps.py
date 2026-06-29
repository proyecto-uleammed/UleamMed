from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.security import decodificar_token
from backend.models.user import User
from backend.services.auth_service import obtener_usuario_por_id


# FastAPI usa esta configuracion para leer el token Bearer del header Authorization.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Obtiene el usuario autenticado desde el access token."""
    credenciales_invalidas = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # El token debe estar firmado correctamente y ser de tipo access.
        payload = decodificar_token(token)
        user_id = payload.get("sub")
        token_type = payload.get("type")
        if user_id is None or token_type != "access":
            raise credenciales_invalidas
    except ValueError as exc:
        raise credenciales_invalidas from exc

    # Si el usuario no existe o esta inactivo, la ruta se considera no autorizada.
    usuario = obtener_usuario_por_id(db, int(user_id))
    if usuario is None or not usuario.is_active:
        raise credenciales_invalidas

    return usuario
