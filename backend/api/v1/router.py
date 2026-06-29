from fastapi import APIRouter

api_router = APIRouter()


@api_router.get("/health", tags=["health"])
def api_health_check() -> dict[str, str]:
    return {"status": "ok", "scope": "api-v1"}
