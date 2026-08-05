"""Endpoints de dispositivos moviles.

Aqui se registran, listan y eliminan los tokens FCM que la app movil obtiene
desde Firebase. Por ahora usan almacenamiento demo en memoria.
"""

from fastapi import APIRouter, Depends

from backend.api.deps import get_current_user
from backend.models.user import User
from backend.schemas.device import (
    DeviceDeleteResponse,
    DeviceTokenCreate,
    DeviceTokenRead,
)
from backend.services.notification_service import (
    delete_device_token,
    list_user_tokens,
    register_device_token,
)

# Todas las rutas de este archivo quedan bajo /api/v1/devices.
router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("", response_model=DeviceTokenRead)
def register_device(
    payload: DeviceTokenCreate,
    current_user: User = Depends(get_current_user),
) -> DeviceTokenRead:
    """Registra el token FCM del dispositivo del usuario autenticado."""
    return register_device_token(
        user_id=current_user.id,
        token=payload.token,
        platform=payload.platform,
    )


@router.get("", response_model=list[DeviceTokenRead])
def list_my_devices(current_user: User = Depends(get_current_user)) -> list[DeviceTokenRead]:
    """Lista los tokens FCM registrados para el usuario autenticado."""
    return list_user_tokens(current_user.id)


@router.delete("/{token}", response_model=DeviceDeleteResponse)
def delete_device(
    token: str,
    current_user: User = Depends(get_current_user),
) -> DeviceDeleteResponse:
    """Elimina un token FCM del usuario autenticado."""
    removed = delete_device_token(user_id=current_user.id, token=token)
    if removed:
        return DeviceDeleteResponse(removed=True, message="Token de dispositivo eliminado")

    return DeviceDeleteResponse(removed=False, message="Token de dispositivo no encontrado")
