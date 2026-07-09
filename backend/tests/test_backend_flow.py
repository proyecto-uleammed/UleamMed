from datetime import UTC, datetime, timedelta
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
from backend.core.database import Base, get_db
from backend.core.roles import UserRole
from backend.core.security import create_access_token, generate_password_hash
from backend.models.caregiver_invitation import CaregiverInvitation
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
        self.client.close()
        Base.metadata.drop_all(bind=self.engine)
        self.engine.dispose()

    def _create_user_and_token(self) -> str:
        """Registra un usuario demo y devuelve su access token."""
        _, token = self._create_account_and_token(
            email="persona@uleam.edu.ec",
            full_name="Persona Demo",
        )
        return token

    def _create_account_and_token(
        self,
        *,
        email: str,
        full_name: str,
        account_type: str = "patient",
    ) -> tuple[dict, str]:
        """Crea una cuenta del rol solicitado y devuelve su token."""
        with patch("backend.api.v1.endpoints.auth.send_welcome_email"):
            registro = self.client.post(
                "/api/v1/auth/register",
                json={
                    "email": email,
                    "full_name": full_name,
                    "password": "clave-segura-123",
                    "account_type": account_type,
                },
            )
        self.assertEqual(registro.status_code, 201)
        login = self.client.post(
            "/api/v1/auth/login",
            json={
                "email": email,
                "password": "clave-segura-123",
            },
        )
        self.assertEqual(login.status_code, 200)
        return registro.json(), login.json()["access_token"]

    def test_flujo_rest_principal(self) -> None:
        """Valida auth, perfil, dispositivos y notificaciones demo."""
        access_token = self._create_user_and_token()
        headers = {"Authorization": f"Bearer {access_token}"}

        perfil = self.client.get("/api/v1/users/me", headers=headers)
        self.assertEqual(perfil.status_code, 200)
        self.assertEqual(perfil.json()["email"], "persona@uleam.edu.ec")
        self.assertEqual(perfil.json()["role"], "patient")

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
        self.assertEqual(respuesta.json()["role"], "patient")
        send.assert_called_once()
        self.assertEqual(send.call_args.args[0].email, "bienvenida@uleam.edu.ec")

    def test_registro_no_permite_elegir_roles_privilegiados(self) -> None:
        """El rol de una cuenta publica no puede controlarse desde el cliente."""
        respuesta = self.client.post(
            "/api/v1/auth/register",
            json={
                "email": "intruso@uleam.edu.ec",
                "full_name": "Usuario Intruso",
                "password": "clave-segura-123",
                "account_type": "admin",
            },
        )

        self.assertEqual(respuesta.status_code, 422)

        caregiver, _ = self._create_account_and_token(
            email="cuidador-registro@uleam.edu.ec",
            full_name="Cuidador Registro",
            account_type="caregiver",
        )
        self.assertEqual(caregiver["role"], "caregiver")

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

    def test_modulo_medicamentos_rechaza_roles_no_pacientes(self) -> None:
        """Los paneles futuros no obtienen permisos de paciente por autenticarse."""
        with self.SessionLocal() as db:
            caregiver = User(
                email="cuidador@uleam.edu.ec",
                full_name="Cuidador Demo",
                hashed_password=generate_password_hash("clave-segura-123"),
                role=UserRole.CAREGIVER,
            )
            db.add(caregiver)
            db.commit()
            db.refresh(caregiver)
            token = create_access_token(str(caregiver.id))

        respuesta = self.client.get(
            "/api/v1/medications",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(respuesta.status_code, 403)
        self.assertIn("pacientes", respuesta.json()["detail"])

    def test_vinculacion_cuidador_requiere_aprobacion_y_respeta_revocacion(
        self,
    ) -> None:
        """Valida el flujo completo sin permitir acceso anticipado o cruzado."""
        _, patient_token = self._create_account_and_token(
            email="paciente-vinculo@uleam.edu.ec",
            full_name="Paciente Vinculo",
        )
        _, caregiver_token = self._create_account_and_token(
            email="cuidador-vinculo@uleam.edu.ec",
            full_name="Cuidador Vinculo",
            account_type="caregiver",
        )
        _, other_caregiver_token = self._create_account_and_token(
            email="otro-cuidador@uleam.edu.ec",
            full_name="Otro Cuidador",
            account_type="caregiver",
        )
        patient_headers = {"Authorization": f"Bearer {patient_token}"}
        caregiver_headers = {"Authorization": f"Bearer {caregiver_token}"}
        other_headers = {"Authorization": f"Bearer {other_caregiver_token}"}

        medication = self.client.post(
            "/api/v1/medications",
            headers=patient_headers,
            json={
                "name": "Losartan",
                "dose": "50 mg",
                "time": "08:00",
            },
        )
        self.assertEqual(medication.status_code, 201)

        invitation = self.client.post(
            "/api/v1/caregiving/invitations",
            headers=patient_headers,
        )
        self.assertEqual(invitation.status_code, 201)
        code = invitation.json()["code"]
        self.assertEqual(len(code.replace("-", "")), 8)

        with self.SessionLocal() as db:
            stored = db.get(CaregiverInvitation, invitation.json()["id"])
            self.assertIsNotNone(stored)
            self.assertNotEqual(stored.code_digest, code.replace("-", ""))
            self.assertEqual(len(stored.code_digest), 64)

        redeemed = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=caregiver_headers,
            json={"code": code},
        )
        self.assertEqual(redeemed.status_code, 200)
        self.assertEqual(redeemed.json()["status"], "pending")
        link_id = redeemed.json()["id"]
        patient_id = redeemed.json()["counterpart_user_id"]

        before_approval = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications",
            headers=caregiver_headers,
        )
        self.assertEqual(before_approval.status_code, 404)

        caregiver_cannot_approve = self.client.post(
            f"/api/v1/caregiving/links/{link_id}/approve",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_cannot_approve.status_code, 403)

        patient_links = self.client.get(
            "/api/v1/caregiving/links",
            headers=patient_headers,
        )
        self.assertEqual(patient_links.status_code, 200)
        self.assertEqual(patient_links.json()["items"][0]["id"], link_id)
        self.assertEqual(
            patient_links.json()["items"][0]["counterpart_email_masked"],
            "c***@uleam.edu.ec",
        )

        approved = self.client.post(
            f"/api/v1/caregiving/links/{link_id}/approve",
            headers=patient_headers,
        )
        self.assertEqual(approved.status_code, 200)
        self.assertEqual(approved.json()["status"], "active")

        patients = self.client.get(
            "/api/v1/caregiving/patients",
            headers=caregiver_headers,
        )
        self.assertEqual(patients.status_code, 200)
        self.assertEqual(patients.json()["items"][0]["id"], patient_id)

        shared_medications = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications",
            headers=caregiver_headers,
        )
        self.assertEqual(shared_medications.status_code, 200)
        self.assertEqual(shared_medications.json()["items"][0]["name"], "Losartan")

        unrelated_access = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications",
            headers=other_headers,
        )
        self.assertEqual(unrelated_access.status_code, 404)

        reused = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=other_headers,
            json={"code": code},
        )
        self.assertEqual(reused.status_code, 400)

        revoked = self.client.delete(
            f"/api/v1/caregiving/links/{link_id}",
            headers=patient_headers,
        )
        self.assertEqual(revoked.status_code, 204)

        after_revocation = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications",
            headers=caregiver_headers,
        )
        self.assertEqual(after_revocation.status_code, 404)

    def test_invitacion_cancelada_expirada_y_aprobacion_ajena(self) -> None:
        """Valida cancelacion, expiracion y propiedad de solicitudes."""
        _, patient_token = self._create_account_and_token(
            email="paciente-codigos@uleam.edu.ec",
            full_name="Paciente Codigos",
        )
        _, other_patient_token = self._create_account_and_token(
            email="otro-paciente@uleam.edu.ec",
            full_name="Otro Paciente",
        )
        _, caregiver_token = self._create_account_and_token(
            email="cuidador-codigos@uleam.edu.ec",
            full_name="Cuidador Codigos",
            account_type="caregiver",
        )
        patient_headers = {"Authorization": f"Bearer {patient_token}"}
        other_patient_headers = {"Authorization": f"Bearer {other_patient_token}"}
        caregiver_headers = {"Authorization": f"Bearer {caregiver_token}"}

        canceled = self.client.post(
            "/api/v1/caregiving/invitations",
            headers=patient_headers,
        )
        canceled_code = canceled.json()["code"]
        cancel_response = self.client.delete(
            f"/api/v1/caregiving/invitations/{canceled.json()['id']}",
            headers=patient_headers,
        )
        self.assertEqual(cancel_response.status_code, 204)
        invalid_canceled = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=caregiver_headers,
            json={"code": canceled_code},
        )
        self.assertEqual(invalid_canceled.status_code, 400)

        expired = self.client.post(
            "/api/v1/caregiving/invitations",
            headers=patient_headers,
        )
        with self.SessionLocal() as db:
            stored = db.get(CaregiverInvitation, expired.json()["id"])
            stored.expires_at = datetime.now(UTC) - timedelta(minutes=1)
            db.add(stored)
            db.commit()
        invalid_expired = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=caregiver_headers,
            json={"code": expired.json()["code"]},
        )
        self.assertEqual(invalid_expired.status_code, 400)

        obsolete = self.client.post(
            "/api/v1/caregiving/invitations",
            headers=patient_headers,
        )
        valid = self.client.post(
            "/api/v1/caregiving/invitations",
            headers=patient_headers,
        )
        invalid_obsolete = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=caregiver_headers,
            json={"code": obsolete.json()["code"]},
        )
        self.assertEqual(invalid_obsolete.status_code, 400)

        pending = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=caregiver_headers,
            json={"code": valid.json()["code"]},
        )
        link_id = pending.json()["id"]
        foreign_approval = self.client.post(
            f"/api/v1/caregiving/links/{link_id}/approve",
            headers=other_patient_headers,
        )
        self.assertEqual(foreign_approval.status_code, 404)

        rejected = self.client.post(
            f"/api/v1/caregiving/links/{link_id}/reject",
            headers=patient_headers,
        )
        self.assertEqual(rejected.status_code, 200)
        self.assertEqual(rejected.json()["status"], "rejected")

    def test_limite_de_intentos_de_codigo(self) -> None:
        """Bloquea temporalmente intentos repetidos del cuidador."""
        _, caregiver_token = self._create_account_and_token(
            email="cuidador-intentos@uleam.edu.ec",
            full_name="Cuidador Intentos",
            account_type="caregiver",
        )
        headers = {"Authorization": f"Bearer {caregiver_token}"}

        for _ in range(5):
            invalid = self.client.post(
                "/api/v1/caregiving/invitations/redeem",
                headers=headers,
                json={"code": "ABCD2345"},
            )
            self.assertEqual(invalid.status_code, 400)

        blocked = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=headers,
            json={"code": "WXYZ6789"},
        )
        self.assertEqual(blocked.status_code, 429)

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
