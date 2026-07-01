import unittest

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
from backend.core.database import Base, get_db
from backend.core.security import crear_access_token
from backend.models.user import User


class BackendIntegratedFlowTest(unittest.TestCase):
    """Pruebas integradas del flujo principal del backend."""

    def setUp(self) -> None:
        """Prepara una base SQLite en memoria para no tocar PostgreSQL."""
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        self.SessionLocal = sessionmaker(bind=self.engine, autoflush=False, autocommit=False)
        Base.metadata.create_all(bind=self.engine)

        def override_get_db():
            db = self.SessionLocal()
            try:
                yield db
            finally:
                db.close()

        app.dependency_overrides[get_db] = override_get_db
        self.client = TestClient(app)

    def tearDown(self) -> None:
        """Limpia dependencias sobrescritas despues de cada prueba."""
        app.dependency_overrides.clear()
        Base.metadata.drop_all(bind=self.engine)

    def _crear_usuario_y_token(self) -> str:
        """Registra un usuario demo y devuelve su access token."""
        registro = self.client.post(
            "/api/v1/auth/register",
            json={
                "email": "persona@uleam.edu.ec",
                "full_name": "Persona Demo",
                "password": "clave-segura-123",
            },
        )
        self.assertEqual(registro.status_code, 201)

        login = self.client.post(
            "/api/v1/auth/login",
            json={
                "email": "persona@uleam.edu.ec",
                "password": "clave-segura-123",
            },
        )
        self.assertEqual(login.status_code, 200)
        return login.json()["access_token"]

    def test_flujo_rest_principal(self) -> None:
        """Valida auth, perfil, dispositivos y notificaciones demo."""
        access_token = self._crear_usuario_y_token()
        headers = {"Authorization": f"Bearer {access_token}"}

        perfil = self.client.get("/api/v1/users/me", headers=headers)
        self.assertEqual(perfil.status_code, 200)
        self.assertEqual(perfil.json()["email"], "persona@uleam.edu.ec")

        actualizar_vacio = self.client.patch(
            "/api/v1/users/me",
            headers=headers,
            json={},
        )
        self.assertEqual(actualizar_vacio.status_code, 200)
        self.assertEqual(actualizar_vacio.json()["full_name"], "Persona Demo")

        actualizar = self.client.patch(
            "/api/v1/users/me",
            headers=headers,
            json={"full_name": "Persona Actualizada"},
        )
        self.assertEqual(actualizar.status_code, 200)
        self.assertEqual(actualizar.json()["full_name"], "Persona Actualizada")

        dispositivo = self.client.post(
            "/api/v1/devices",
            headers=headers,
            json={"token": "fcm-token-demo-12345", "platform": "android"},
        )
        self.assertEqual(dispositivo.status_code, 200)

        notificacion = self.client.post(
            "/api/v1/notifications/send",
            headers=headers,
            json={
                "title": "Recordatorio",
                "body": "Es hora de tomar tu medicina",
                "data": {"tipo": "medicina"},
            },
        )
        self.assertEqual(notificacion.status_code, 200)
        self.assertIn("status", notificacion.json())

        listado = self.client.get("/api/v1/notifications", headers=headers)
        self.assertEqual(listado.status_code, 200)
        self.assertGreaterEqual(len(listado.json()["items"]), 1)

    def test_websocket_autenticado(self) -> None:
        """Valida conexion WebSocket con access token y respuesta eco."""
        access_token = self._crear_usuario_y_token()

        with self.client.websocket_connect(f"/api/v1/ws?token={access_token}") as websocket:
            conectado = websocket.receive_json()
            websocket.send_text("hola tiempo real")
            eco = websocket.receive_json()

        self.assertEqual(conectado["type"], "conexion_establecida")
        self.assertEqual(eco["type"], "eco")
        self.assertEqual(eco["message"], "hola tiempo real")

    def test_token_con_subject_invalido_devuelve_401(self) -> None:
        """Un token firmado pero con subject no numerico no debe generar 500."""
        token = crear_access_token("usuario-invalido")

        respuesta = self.client.get(
            "/api/v1/users/me",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(respuesta.status_code, 401)

    def test_cors_permite_preflight_de_flutter_web(self) -> None:
        """Valida que un frontend web pueda llamar a la API desde otro origen."""
        respuesta = self.client.options(
            "/api/v1/health",
            headers={
                "Origin": "http://localhost:5173",
                "Access-Control-Request-Method": "GET",
            },
        )

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.headers["access-control-allow-origin"], "http://localhost:5173")


if __name__ == "__main__":
    unittest.main()
