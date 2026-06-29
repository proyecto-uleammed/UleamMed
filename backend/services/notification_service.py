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


def registrar_token_dispositivo(user_id: int, token: str, platform: str | None = None) -> DeviceTokenRead:
    """Guarda o actualiza el token FCM de un dispositivo del usuario."""
    registro = DeviceRegistration(user_id=user_id, token=token, platform=platform)
    with _lock:
        _device_tokens.setdefault(user_id, {})[token] = registro

    return DeviceTokenRead(user_id=user_id, token=token, platform=platform)


def eliminar_token_dispositivo(user_id: int, token: str) -> bool:
    """Elimina un token FCM del usuario autenticado."""
    with _lock:
        tokens_usuario = _device_tokens.get(user_id, {})
        eliminado = tokens_usuario.pop(token, None) is not None
        if not tokens_usuario:
            _device_tokens.pop(user_id, None)

    return eliminado


def listar_tokens_usuario(user_id: int) -> list[DeviceTokenRead]:
    """Devuelve los tokens registrados para un usuario."""
    with _lock:
        registros = list(_device_tokens.get(user_id, {}).values())

    return [
        DeviceTokenRead(user_id=registro.user_id, token=registro.token, platform=registro.platform)
        for registro in registros
    ]


def listar_notificaciones_usuario(user_id: int) -> list[NotificationRead]:
    """Devuelve las notificaciones registradas para el usuario."""
    with _lock:
        return list(_notifications.get(user_id, []))


def enviar_notificacion_demo(
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> NotificationRead:
    """Registra una notificacion y la envia por FCM si hay credenciales."""
    tokens = [dispositivo.token for dispositivo in listar_tokens_usuario(user_id)]
    status = "sin_tokens"

    if tokens:
        status = _enviar_por_firebase(tokens=tokens, title=title, body=body, data=data)

    notificacion = NotificationRead(
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
        _notifications.setdefault(user_id, []).append(notificacion)

    return notificacion


def _enviar_por_firebase(
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> str:
    """Intenta enviar por FCM; si no hay credenciales, deja el envio simulado."""
    app_inicializada = _inicializar_firebase()
    if not app_inicializada:
        return "simulada_sin_credenciales_firebase"

    mensaje = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data={key: str(value) for key, value in (data or {}).items()},
    )
    respuesta = messaging.send_each_for_multicast(mensaje)
    return f"enviada_firebase_{respuesta.success_count}_ok_{respuesta.failure_count}_error"


def _inicializar_firebase() -> bool:
    """Inicializa Firebase Admin SDK una sola vez si existe el JSON configurado."""
    if firebase_admin._apps:
        return True

    if not settings.FIREBASE_CREDENTIALS:
        return False

    ruta_credenciales = Path(settings.FIREBASE_CREDENTIALS)
    if not ruta_credenciales.exists():
        return False

    credencial = credentials.Certificate(str(ruta_credenciales))
    firebase_admin.initialize_app(credencial)
    return True
