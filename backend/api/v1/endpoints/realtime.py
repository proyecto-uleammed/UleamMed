from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status

from backend.core.security import decodificar_token
from backend.websockets.manager import manager


# Todas las rutas de este archivo quedan bajo /api/v1.
router = APIRouter(tags=["tiempo real"])


def _obtener_user_id_desde_token(token: str | None) -> int | None:
    """Valida el JWT del query param y devuelve el id del usuario."""
    if not token:
        return None

    try:
        payload = decodificar_token(token)
    except ValueError:
        return None

    if payload.get("type") != "access" or payload.get("sub") is None:
        return None

    try:
        return int(payload["sub"])
    except (TypeError, ValueError):
        return None


@router.websocket("/ws")
async def websocket_tiempo_real(websocket: WebSocket, token: str | None = None) -> None:
    """Canal WebSocket autenticado para eventos en tiempo real."""
    user_id = _obtener_user_id_desde_token(token)
    if user_id is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(user_id, websocket)
    await manager.send_to_user(
        user_id,
        {
            "type": "conexion_establecida",
            "message": "Canal de tiempo real conectado",
            "user_id": user_id,
        },
    )

    try:
        while True:
            # Por ahora se recibe texto libre y se responde un eco demo.
            mensaje = await websocket.receive_text()
            await manager.send_to_user(
                user_id,
                {
                    "type": "eco",
                    "message": mensaje,
                    "user_id": user_id,
                },
            )
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
