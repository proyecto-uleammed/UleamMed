from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.v1.router import api_router
from backend.core.config import settings


# Crea la aplicacion principal de FastAPI.
# Desde aqui se configura el nombre, la version y la documentacion automatica.
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Endpoint simple para comprobar que el backend esta levantado."""
    return {"status": "ok", "environment": settings.ENVIRONMENT}


# Monta todas las rutas de la API versionada bajo /api/v1.
app.include_router(api_router, prefix=settings.API_V1_PREFIX)
