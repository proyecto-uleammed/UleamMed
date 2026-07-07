import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
from backend.core.database import Base, get_db
from backend.core.security import create_access_token


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

    def _create_user_and_token(self) -> str:
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
        access_token = self._create_user_and_token()
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

        device = self.client.post(
            "/api/v1/devices",
            headers=headers,
            json={"token": "fcm-token-demo-12345", "platform": "android"},
        )
        self.assertEqual(device.status_code, 200)

        notification = self.client.post(
            "/api/v1/notifications/send",
            headers=headers,
            json={
                "title": "Recordatorio",
                "body": "Es hora de tomar tu medicina",
                "data": {"tipo": "medicina"},
            },
        )
        self.assertEqual(notification.status_code, 200)
        self.assertIn("status", notification.json())

        listado = self.client.get("/api/v1/notifications", headers=headers)
        self.assertEqual(listado.status_code, 200)
        self.assertGreaterEqual(len(listado.json()["items"]), 1)

    def test_registro_envia_correo_bienvenida(self) -> None:
        """Valida que el registro dispare el correo de bienvenida."""
        with patch("backend.api.v1.endpoints.auth.send_welcome_email") as send:
            respuesta = self.client.post(
                "/api/v1/auth/register",
                json={
                    "email": "bienvenida@uleam.edu.ec",
                    "full_name": "Usuario Bienvenida",
                    "password": "clave-segura-123",
                },
            )

        self.assertEqual(respuesta.status_code, 201)
        send.assert_called_once()
        self.assertEqual(send.call_args.args[0].email, "bienvenida@uleam.edu.ec")

    def test_recuperacion_password_con_codigo(self) -> None:
        """Valida solicitud de codigo y cambio de contrasena."""
        registro = self.client.post(
            "/api/v1/auth/register",
            json={
                "email": "recupera@uleam.edu.ec",
                "full_name": "Usuario Recupera",
                "password": "clave-vieja-123",
            },
        )
        self.assertEqual(registro.status_code, 201)

        with (
            patch("backend.services.auth_service.secrets.randbelow", return_value=123456),
            patch("backend.api.v1.endpoints.auth.send_password_reset_email") as send,
        ):
            solicitud = self.client.post(
                "/api/v1/auth/forgot-password",
                json={"email": "recupera@uleam.edu.ec"},
            )

        self.assertEqual(solicitud.status_code, 200)
        self.assertIn("instrucciones", solicitud.json()["message"])
        send.assert_called_once()
        self.assertEqual(send.call_args.kwargs["code"], "123456")

        invalido = self.client.post(
            "/api/v1/auth/reset-password",
            json={
                "email": "recupera@uleam.edu.ec",
                "code": "000000",
                "new_password": "clave-nueva-123",
            },
        )
        self.assertEqual(invalido.status_code, 400)

        with patch("backend.api.v1.endpoints.auth.send_password_updated_email") as confirm:
            reset = self.client.post(
                "/api/v1/auth/reset-password",
                json={
                    "email": "recupera@uleam.edu.ec",
                    "code": "123456",
                    "new_password": "clave-nueva-123",
                },
            )

        self.assertEqual(reset.status_code, 200)
        confirm.assert_called_once()
        self.assertEqual(confirm.call_args.args[0].email, "recupera@uleam.edu.ec")

        login_viejo = self.client.post(
            "/api/v1/auth/login",
            json={"email": "recupera@uleam.edu.ec", "password": "clave-vieja-123"},
        )
        self.assertEqual(login_viejo.status_code, 401)

        login_nuevo = self.client.post(
            "/api/v1/auth/login",
            json={"email": "recupera@uleam.edu.ec", "password": "clave-nueva-123"},
        )
        self.assertEqual(login_nuevo.status_code, 200)

    def test_modulo_medicamentos_permite_marcar_toma(self) -> None:
        """Valida listado y marcado de medicamentos del usuario."""
        access_token = self._create_user_and_token()
        headers = {"Authorization": f"Bearer {access_token}"}

        listado = self.client.get("/api/v1/medications", headers=headers)
        self.assertEqual(listado.status_code, 200)
        self.assertEqual(listado.json()["items"], [])

        creado = self.client.post(
            "/api/v1/medications",
            headers=headers,
            json={
                "name": "Omeprazol",
                "dose": "20 mg",
                "time": "14:00",
                "frequency": "Diario",
                "duration": "30 dias",
                "instructions": "Tomar antes de comer",
                "isImportant": True,
            },
        )
        self.assertEqual(creado.status_code, 201)
        medicamento_id = creado.json()["id"]
        self.assertEqual(creado.json()["name"], "Omeprazol")

        editado = self.client.patch(
            f"/api/v1/medications/{medicamento_id}",
            headers=headers,
            json={"dose": "40 mg"},
        )
        self.assertEqual(editado.status_code, 200)
        self.assertEqual(editado.json()["dose"], "40 mg")

        marcado = self.client.post(f"/api/v1/medications/{medicamento_id}/take", headers=headers)
        self.assertEqual(marcado.status_code, 200)
        self.assertTrue(marcado.json()["medication"]["taken"])
        self.assertEqual(marcado.json()["taken_count"], 1)
        self.assertEqual(marcado.json()["total_count"], 1)

        actualizado = self.client.get("/api/v1/medications", headers=headers)
        self.assertEqual(sum(1 for medication in actualizado.json()["items"] if medication["taken"]), 1)

        eliminado = self.client.delete(f"/api/v1/medications/{medicamento_id}", headers=headers)
        self.assertEqual(eliminado.status_code, 204)

        final = self.client.get("/api/v1/medications", headers=headers)
        self.assertEqual(final.json()["items"], [])

    def test_websocket_autenticado(self) -> None:
        """Valida conexion WebSocket con access token y respuesta eco."""
        access_token = self._create_user_and_token()

        with self.client.websocket_connect(f"/api/v1/ws?token={access_token}") as websocket:
            conectado = websocket.receive_json()
            websocket.send_text("hola tiempo real")
            eco = websocket.receive_json()

        self.assertEqual(conectado["type"], "conexion_establecida")
        self.assertEqual(eco["type"], "eco")
        self.assertEqual(eco["message"], "hola tiempo real")

    def test_token_con_subject_invalido_devuelve_401(self) -> None:
        """Un token firmado pero con subject no numerico no debe generar 500."""
        token = create_access_token("invalid-user")

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
