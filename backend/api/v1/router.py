from fastapi import APIRouter

from backend.api.v1.endpoints import auth, users

# Router central de la version 1 de la API.
api_router = APIRouter()

# Cada modulo de endpoints se conecta aqui para mantener main.py simple.
api_router.include_router(auth.router)
api_router.include_router(users.router)


@api_router.get("/health", tags=["health"])
def api_health_check() -> dict[str, str]:
    """Comprueba que el prefijo /api/v1 esta funcionando."""
    return {"status": "ok", "scope": "api-v1"}
