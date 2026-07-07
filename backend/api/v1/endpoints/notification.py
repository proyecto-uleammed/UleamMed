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
    list_user_notifications,
    send_demo_notification,
)


# Todas las rutas de este archivo quedan bajo /api/v1/notifications.
router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/send", response_model=NotificationRead)
def send_notification(
    payload: NotificationSendRequest,
    current_user: User = Depends(get_current_user),
) -> NotificationRead:
    """Envia una notificacion demo al usuario autenticado."""
    return send_demo_notification(
        user_id=current_user.id,
        title=payload.title,
        body=payload.body,
        data=payload.data,
    )


@router.get("", response_model=NotificationListResponse)
def list_my_notifications(
    current_user: User = Depends(get_current_user),
) -> NotificationListResponse:
    """Lista las notificaciones guardadas para el usuario autenticado."""
    return NotificationListResponse(items=list_user_notifications(current_user.id))
