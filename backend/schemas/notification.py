from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class NotificationSendRequest(BaseModel):
    """Datos necesarios para enviar una notificacion push demo."""

    title: str = Field(..., min_length=1, max_length=120, examples=["Recordatorio"])
    body: str = Field(..., min_length=1, max_length=500, examples=["Es hora de tomar tu medicina"])
    data: dict[str, Any] | None = Field(default=None, examples=[{"tipo": "medicina"}])


class NotificationRead(BaseModel):
    """Notificacion registrada para mostrarla o auditarla desde la API."""

    id: str
    user_id: int
    title: str
    body: str
    data: dict[str, Any] | None = None
    status: str
    delivered_tokens: int
    created_at: datetime


class NotificationListResponse(BaseModel):
    """Lista de notificaciones del usuario autenticado."""

    items: list[NotificationRead]
