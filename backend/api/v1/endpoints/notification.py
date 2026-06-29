"""Endpoints de notificaciones.

Aqui se envian notificaciones push demo y se listan las notificaciones del
usuario autenticado. Por ahora usan almacenamiento demo en memoria.
"""

from fastapi import APIRouter, Depends

from backend.api.deps import get_current_user
from backend.models.user import User
from backend.schemas.notification import (
    NotificationListResponse,
    NotificationRead,
    NotificationSendRequest,
)
from backend.services.notification_service import (
    enviar_notificacion_demo,
    listar_notificaciones_usuario,
)


# Todas las rutas de este archivo quedan bajo /api/v1/notifications.
router = APIRouter(prefix="/notifications", tags=["notificaciones"])


@router.post("/send", response_model=NotificationRead)
def enviar_notificacion(
    datos: NotificationSendRequest,
    usuario_actual: User = Depends(get_current_user),
) -> NotificationRead:
    """Envia una notificacion demo al usuario autenticado."""
    return enviar_notificacion_demo(
        user_id=usuario_actual.id,
        title=datos.title,
        body=datos.body,
        data=datos.data,
    )


@router.get("", response_model=NotificationListResponse)
def listar_mis_notificaciones(
    usuario_actual: User = Depends(get_current_user),
) -> NotificationListResponse:
    """Lista las notificaciones guardadas para el usuario autenticado."""
    return NotificationListResponse(items=listar_notificaciones_usuario(usuario_actual.id))
