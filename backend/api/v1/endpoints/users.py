from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from backend.api.deps import get_current_user
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.user import UserRead, UserUpdate


# Todas las rutas de este archivo quedan bajo /api/v1/users.
router = APIRouter(prefix="/users", tags=["usuarios"])


@router.get("/me", response_model=UserRead)
def obtener_mi_perfil(usuario_actual: User = Depends(get_current_user)) -> UserRead:
    """Devuelve los datos publicos del usuario autenticado."""
    return usuario_actual


@router.patch("/me", response_model=UserRead)
def actualizar_mi_perfil(
    datos: UserUpdate,
    usuario_actual: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserRead:
    """Actualiza campos permitidos del perfil propio."""
    if "full_name" in datos.model_fields_set:
        usuario_actual.full_name = datos.full_name
    db.add(usuario_actual)
    db.commit()
    db.refresh(usuario_actual)
    return usuario_actual
