"""Gestor de conexiones WebSocket.

Este modulo se usara para registrar conexiones activas, enviar mensajes a un
usuario especifico y difundir eventos en tiempo real.
"""

from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    """Administra conexiones WebSocket activas en memoria."""

    def __init__(self) -> None:
        # Cada usuario puede tener varias conexiones: celular, navegador, tablet, etc.
        self.active_connections: dict[int, list[WebSocket]] = defaultdict(list)

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        """Acepta el socket y lo registra para el usuario autenticado."""
        await websocket.accept()
        self.active_connections[user_id].append(websocket)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        """Quita una conexion cerrada de la lista del usuario."""
        conexiones = self.active_connections.get(user_id, [])
        if websocket in conexiones:
            conexiones.remove(websocket)

        if not conexiones:
            self.active_connections.pop(user_id, None)

    async def send_to_user(self, user_id: int, message: dict[str, Any]) -> None:
        """Envia un mensaje JSON a todas las conexiones de un usuario."""
        conexiones = list(self.active_connections.get(user_id, []))
        for websocket in conexiones:
            await websocket.send_json(message)

    async def broadcast(self, message: dict[str, Any]) -> None:
        """Envia un mensaje JSON a todos los usuarios conectados."""
        for user_id in list(self.active_connections):
            await self.send_to_user(user_id, message)


# Instancia compartida por los endpoints WebSocket.
manager = ConnectionManager()
