"""Servicio de notificaciones push.

Este modulo quedara encargado de inicializar Firebase Admin SDK y enviar
mensajes por FCM cuando existan credenciales configuradas.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from threading import Lock
from typing import Any
from uuid import uuid4

import firebase_admin
from firebase_admin import credentials, messaging

from backend.core.config import settings
from backend.schemas.device import DeviceTokenRead
from backend.schemas.notification import NotificationRead


@dataclass
class DeviceRegistration:
    """Registro interno de un token FCM asociado a un usuario."""

    user_id: int
    token: str
    platform: str | None = None


# Almacenamiento temporal en memoria.
# Cuando la BD este definida por Andyy, estas estructuras se reemplazan
# por consultas a tablas reales de dispositivos y notificaciones.
_device_tokens: dict[int, dict[str, DeviceRegistration]] = {}
_notifications: dict[int, list[NotificationRead]] = {}
_lock = Lock()


def register_device_token(user_id: int, token: str, platform: str | None = None) -> DeviceTokenRead:
    """Guarda o actualiza el token FCM de un dispositivo del usuario."""
    registration = DeviceRegistration(user_id=user_id, token=token, platform=platform)
    with _lock:
        _device_tokens.setdefault(user_id, {})[token] = registration

    return DeviceTokenRead(user_id=user_id, token=token, platform=platform)


def delete_device_token(user_id: int, token: str) -> bool:
    """Elimina un token FCM del usuario autenticado."""
    with _lock:
        user_tokens = _device_tokens.get(user_id, {})
        removed = user_tokens.pop(token, None) is not None
        if not user_tokens:
            _device_tokens.pop(user_id, None)

    return removed


def list_user_tokens(user_id: int) -> list[DeviceTokenRead]:
    """Devuelve los tokens registrados para un usuario."""
    with _lock:
        registrations = list(_device_tokens.get(user_id, {}).values())

    return [
        DeviceTokenRead(user_id=registration.user_id, token=registration.token, platform=registration.platform)
        for registration in registrations
    ]


def list_user_notifications(user_id: int) -> list[NotificationRead]:
    """Devuelve las notificaciones registradas para el usuario."""
    with _lock:
        return list(_notifications.get(user_id, []))


def send_demo_notification(
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> NotificationRead:
    """Registra una notificacion y la envia por FCM si hay credenciales."""
    tokens = [device.token for device in list_user_tokens(user_id)]
    status = "sin_tokens"

    if tokens:
        status = _send_with_firebase(tokens=tokens, title=title, body=body, data=data)

    notification = NotificationRead(
        id=str(uuid4()),
        user_id=user_id,
        title=title,
        body=body,
        data=data,
        status=status,
        delivered_tokens=len(tokens),
        created_at=datetime.now(UTC),
    )

    with _lock:
        _notifications.setdefault(user_id, []).append(notification)

    return notification


def _send_with_firebase(
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> str:
    """Intenta enviar por FCM; si no hay credenciales, deja el envio simulado."""
    app_initialized = _initialize_firebase()
    if not app_initialized:
        return "simulada_sin_credenciales_firebase"

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data={key: str(value) for key, value in (data or {}).items()},
    )
    response = messaging.send_each_for_multicast(message)
    return f"enviada_firebase_{response.success_count}_ok_{response.failure_count}_error"


def _initialize_firebase() -> bool:
    """Inicializa Firebase Admin SDK una sola vez si existe el JSON configurado."""
    if firebase_admin._apps:
        return True

    if not settings.FIREBASE_CREDENTIALS:
        return False

    credentials_path = Path(settings.FIREBASE_CREDENTIALS)
    if not credentials_path.exists():
        return False

    certificate = credentials.Certificate(str(credentials_path))
    firebase_admin.initialize_app(certificate)
    return True
