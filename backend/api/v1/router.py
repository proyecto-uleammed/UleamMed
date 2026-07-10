from fastapi import APIRouter

from backend.api.v1.endpoints import (
    appointments,
    auth,
    caregiving,
    devices,
    emergency_contacts,
    health_entries,
    medical_profiles,
    medications,
    notification,
    realtime,
    users,
)

# Router central de la version 1 de la API.
api_router = APIRouter()

# Cada modulo de endpoints se conecta aqui para mantener main.py simple.
api_router.include_router(auth.router)
api_router.include_router(appointments.router)
api_router.include_router(health_entries.router)
api_router.include_router(emergency_contacts.router)
api_router.include_router(medical_profiles.router)
api_router.include_router(caregiving.router)
api_router.include_router(devices.router)
api_router.include_router(medications.router)
api_router.include_router(notification.router)
api_router.include_router(realtime.router)
api_router.include_router(users.router)


@api_router.get("/health", tags=["health"])
def api_health_check() -> dict[str, str]:
    """Comprueba que el prefijo /api/v1 esta funcionando."""
    return {"status": "ok", "scope": "api-v1"}
