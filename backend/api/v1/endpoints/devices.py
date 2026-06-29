"""Endpoints de dispositivos moviles.

Aqui se registran, listan y eliminan los tokens FCM que la app movil obtiene
desde Firebase. Por ahora usan almacenamiento demo en memoria.
"""

from fastapi import APIRouter, Depends

from backend.api.deps import get_current_user
from backend.models.user import User
from backend.schemas.device import DeviceDeleteResponse, DeviceTokenCreate, DeviceTokenRead
from backend.services.notification_service import (
    eliminar_token_dispositivo,
    listar_tokens_usuario,
    registrar_token_dispositivo,
)


# Todas las rutas de este archivo quedan bajo /api/v1/devices.
router = APIRouter(prefix="/devices", tags=["dispositivos"])


@router.post("", response_model=DeviceTokenRead)
def registrar_dispositivo(
    datos: DeviceTokenCreate,
    usuario_actual: User = Depends(get_current_user),
) -> DeviceTokenRead:
    """Registra el token FCM del dispositivo del usuario autenticado."""
    return registrar_token_dispositivo(
        user_id=usuario_actual.id,
        token=datos.token,
        platform=datos.platform,
    )


@router.get("", response_model=list[DeviceTokenRead])
def listar_mis_dispositivos(usuario_actual: User = Depends(get_current_user)) -> list[DeviceTokenRead]:
    """Lista los tokens FCM registrados para el usuario autenticado."""
    return listar_tokens_usuario(usuario_actual.id)


@router.delete("/{token}", response_model=DeviceDeleteResponse)
def eliminar_dispositivo(
    token: str,
    usuario_actual: User = Depends(get_current_user),
) -> DeviceDeleteResponse:
    """Elimina un token FCM del usuario autenticado."""
    eliminado = eliminar_token_dispositivo(user_id=usuario_actual.id, token=token)
    if eliminado:
        return DeviceDeleteResponse(removed=True, message="Token de dispositivo eliminado")

    return DeviceDeleteResponse(removed=False, message="Token de dispositivo no encontrado")
