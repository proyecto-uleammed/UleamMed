from pydantic import BaseModel, Field


class DeviceTokenCreate(BaseModel):
    """Datos que envia la app movil para registrar su token FCM."""

    token: str = Field(..., min_length=10, max_length=4096, examples=["fcm-token-demo"])
    platform: str | None = Field(default=None, max_length=50, examples=["android"])


class DeviceTokenRead(BaseModel):
    """Respuesta publica de un dispositivo registrado."""

    user_id: int
    token: str
    platform: str | None = None


class DeviceDeleteResponse(BaseModel):
    """Respuesta al eliminar un token FCM."""

    removed: bool
    message: str
