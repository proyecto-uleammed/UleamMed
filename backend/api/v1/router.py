from fastapi import APIRouter

from backend.api.v1.endpoints import auth, users

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)


@api_router.get("/health", tags=["health"])
def api_health_check() -> dict[str, str]:
    return {"status": "ok", "scope": "api-v1"}
