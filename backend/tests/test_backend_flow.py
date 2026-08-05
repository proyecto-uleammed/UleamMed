import unittest
from datetime import UTC, datetime, timedelta
from unittest.mock import patch

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from backend.app.main import app
from backend.core.database import Base, get_db
from backend.core.roles import UserRole
from backend.core.security import create_access_token, generate_password_hash
from backend.models.appointment import Appointment  # noqa: F401
from backend.models.caregiver_invitation import CaregiverInvitation
from backend.models.emergency_contact import EmergencyContact  # noqa: F401
from backend.models.health_entry import HealthEntry  # noqa: F401
from backend.models.user import User
from backend.models.user_medical_profile import UserMedicalProfile  # noqa: F401


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

    def test_horario_estructurado_y_evento_idempotente(self) -> None:
        """Guarda dos tomas diarias y evita duplicar eventos offline."""
        access_token = self._create_user_and_token()
        headers = {"Authorization": f"Bearer {access_token}"}
        creado = self.client.post(
            "/api/v1/medications",
            headers=headers,
            json={
                "name": "Antibiotico",
                "doseAmount": 150,
                "doseUnit": "mg",
                "instructions": "Tomar despues de comer",
                "schedule": {
                    "mode": "interval",
                    "interval_hours": 12,
                    "times": ["08:00"],
                    "weekdays": [1, 2, 3, 4, 5, 6, 7],
                    "start_date": "2026-07-09",
                },
            },
        )
        self.assertEqual(creado.status_code, 201)
        self.assertEqual(creado.json()["dose"], "150 mg")
        self.assertEqual(creado.json()["schedule"]["interval_hours"], 12)

        medication_id = creado.json()["id"]
        event = {
            "client_event_id": "evento-tablet-0001",
            "scheduled_at": "2026-07-09T08:00:00Z",
            "sequence_number": 1,
            "status": "taken",
            "acted_at": "2026-07-09T08:01:00Z",
        }
        first = self.client.post(
            f"/api/v1/medications/{medication_id}/dose-events",
            headers=headers,
            json=event,
        )
        second = self.client.post(
            f"/api/v1/medications/{medication_id}/dose-events",
            headers=headers,
            json=event,
        )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["id"], second.json()["id"])

        medications = self.client.get("/api/v1/medications", headers=headers)
        self.assertEqual(medications.status_code, 200)
        self.assertTrue(medications.json()["items"][0]["taken"])

        events = self.client.get(
            "/api/v1/medications/dose-events",
            headers=headers,
        )
        self.assertEqual(events.status_code, 200)
        self.assertEqual(len(events.json()), 1)

    def test_sync_offline_medicamentos_es_idempotente_y_resuelve_conflictos(
        self,
    ) -> None:
        """Evita duplicados por reintentos y deja dudas para decision del paciente."""
        access_token = self._create_user_and_token()
        headers = {"Authorization": f"Bearer {access_token}"}
        base_payload = {
            "name": "Paracetamol",
            "doseAmount": 500,
            "doseUnit": "mg",
            "schedule": {
                "mode": "fixed_times",
                "times": ["08:00"],
                "weekdays": [1, 2, 3, 4, 5, 6, 7],
                "start_date": "2026-07-10",
            },
        }

        create_action = {
            "client_operation_id": "op-paracetamol-crear-001",
            "client_medication_id": "local-paracetamol-001",
            "operation_type": "create_medication",
            "created_at": "2026-07-10T08:00:00Z",
            "payload": base_payload,
        }
        first = self.client.post(
            "/api/v1/medications/sync",
            headers=headers,
            json={"actions": [create_action]},
        )
        second = self.client.post(
            "/api/v1/medications/sync",
            headers=headers,
            json={"actions": [create_action]},
        )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["results"][0]["status"], "synced")
        self.assertEqual(second.json()["results"][0]["status"], "synced")
        self.assertEqual(len(second.json()["items"]), 1)
        paracetamol_id = first.json()["results"][0]["medication"]["id"]

        duplicate = self.client.post(
            "/api/v1/medications/sync",
            headers=headers,
            json={
                "actions": [
                    {
                        "client_operation_id": "op-paracetamol-dup-001",
                        "client_medication_id": "local-paracetamol-dup",
                        "operation_type": "create_medication",
                        "payload": {**base_payload, "name": "paracetamol"},
                    }
                ]
            },
        )
        self.assertEqual(duplicate.status_code, 200)
        self.assertEqual(
            duplicate.json()["results"][0]["medication"]["id"],
            paracetamol_id,
        )
        self.assertEqual(len(duplicate.json()["items"]), 1)

        conflict = self.client.post(
            "/api/v1/medications/sync",
            headers=headers,
            json={
                "actions": [
                    {
                        "client_operation_id": "op-paracetamol-conflict-001",
                        "client_medication_id": "local-paracetamol-conflict",
                        "operation_type": "create_medication",
                        "payload": {**base_payload, "doseAmount": 250},
                    }
                ]
            },
        )
        self.assertEqual(conflict.status_code, 200)
        self.assertEqual(conflict.json()["results"][0]["status"], "conflict")
        conflict_id = conflict.json()["results"][0]["conflict"]["id"]

        conflicts = self.client.get(
            "/api/v1/medications/sync-conflicts",
            headers=headers,
        )
        self.assertEqual(conflicts.status_code, 200)
        self.assertEqual(len(conflicts.json()["items"]), 1)

        resolved = self.client.post(
            f"/api/v1/medications/sync-conflicts/{conflict_id}/resolve",
            headers=headers,
            json={"resolution": "create_separate"},
        )
        self.assertEqual(resolved.status_code, 200)
        self.assertEqual(resolved.json()["dose"], "250 mg")

        listed = self.client.get("/api/v1/medications", headers=headers)
        self.assertEqual(len(listed.json()["items"]), 2)

        delete_sync = self.client.post(
            "/api/v1/medications/sync",
            headers=headers,
            json={
                "actions": [
                    {
                        "client_operation_id": "op-paracetamol-delete-001",
                        "client_medication_id": "local-paracetamol-001",
                        "server_medication_id": paracetamol_id,
                        "operation_type": "delete_medication",
                        "payload": {},
                    }
                ]
            },
        )
        self.assertEqual(delete_sync.status_code, 200)
        self.assertEqual(delete_sync.json()["results"][0]["status"], "synced")
        after_delete = self.client.get("/api/v1/medications", headers=headers)
        self.assertNotIn(
            paracetamol_id,
            {item["id"] for item in after_delete.json()["items"]},
        )

    def test_sync_cuidador_vinculado_deduplica_y_respeta_permisos(self) -> None:
        """El cuidador sincroniza solo con vinculo activo y no duplica medicamentos obvios."""
        _, patient_token = self._create_account_and_token(
            email="paciente-sync@uleam.edu.ec",
            full_name="Paciente Sync",
        )
        _, caregiver_token = self._create_account_and_token(
            email="cuidador-sync@uleam.edu.ec",
            full_name="Cuidador Sync",
            account_type="caregiver",
        )
        _, other_caregiver_token = self._create_account_and_token(
            email="cuidador-sync-ajeno@uleam.edu.ec",
            full_name="Cuidador Sync Ajeno",
            account_type="caregiver",
        )
        patient_headers = {"Authorization": f"Bearer {patient_token}"}
        caregiver_headers = {"Authorization": f"Bearer {caregiver_token}"}
        other_headers = {"Authorization": f"Bearer {other_caregiver_token}"}

        medication_payload = {
            "name": "Omeprazol",
            "doseAmount": 20,
            "doseUnit": "mg",
            "schedule": {
                "mode": "fixed_times",
                "times": ["14:00"],
                "weekdays": [1, 2, 3, 4, 5, 6, 7],
                "start_date": "2026-07-10",
            },
        }
        patient_sync = self.client.post(
            "/api/v1/medications/sync",
            headers=patient_headers,
            json={
                "actions": [
                    {
                        "client_operation_id": "op-omeprazol-paciente-001",
                        "client_medication_id": "local-omeprazol-paciente",
                        "operation_type": "create_medication",
                        "payload": medication_payload,
                    }
                ]
            },
        )
        self.assertEqual(patient_sync.status_code, 200)
        patient_medication_id = patient_sync.json()["results"][0]["medication"]["id"]

        invitation = self.client.post(
            "/api/v1/caregiving/invitations",
            headers=patient_headers,
        )
        redeem = self.client.post(
            "/api/v1/caregiving/invitations/redeem",
            headers=caregiver_headers,
            json={"code": invitation.json()["code"]},
        )
        approve = self.client.post(
            f"/api/v1/caregiving/links/{redeem.json()['id']}/approve",
            headers=patient_headers,
        )
        self.assertEqual(approve.status_code, 200)
        patient_id = redeem.json()["counterpart_user_id"]

        caregiver_sync = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/medications/sync",
            headers=caregiver_headers,
            json={
                "actions": [
                    {
                        "client_operation_id": "op-omeprazol-cuidador-001",
                        "client_medication_id": "local-omeprazol-cuidador",
                        "operation_type": "create_medication",
                        "payload": {**medication_payload, "name": "omeprazol"},
                    }
                ]
            },
        )
        self.assertEqual(caregiver_sync.status_code, 200)
        self.assertEqual(
            caregiver_sync.json()["results"][0]["medication"]["id"],
            patient_medication_id,
        )
        self.assertEqual(len(caregiver_sync.json()["items"]), 1)

        forbidden = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/medications/sync",
            headers=other_headers,
            json={"actions": []},
        )
        self.assertEqual(forbidden.status_code, 404)

    def test_foto_de_medicamento_se_mantiene_privada_en_backend(self) -> None:
        """La foto pasa por FastAPI y no expone una URL publica."""
        access_token = self._create_user_and_token()
        headers = {"Authorization": f"Bearer {access_token}"}
        creado = self.client.post(
            "/api/v1/medications",
            headers=headers,
            json={"name": "Losartan", "dose": "50 mg", "time": "08:00"},
        )
        medication_id = creado.json()["id"]

        with (
            patch(
                "backend.api.v1.endpoints.medications.upload_medication_photo",
                return_value=f"users/1/medications/{medication_id}/foto.jpg",
            ),
            patch(
                "backend.api.v1.endpoints.medications.delete_medication_photo",
            ),
        ):
            uploaded = self.client.post(
                f"/api/v1/medications/{medication_id}/photo",
                headers=headers,
                files={"photo": ("foto.jpg", b"imagen", "image/jpeg")},
            )
        self.assertEqual(uploaded.status_code, 200)
        self.assertTrue(uploaded.json()["photoAvailable"])
        self.assertNotIn("photo_path", uploaded.json())

        with patch(
            "backend.api.v1.endpoints.medications.download_medication_photo",
            return_value=b"imagen",
        ):
            downloaded = self.client.get(
                f"/api/v1/medications/{medication_id}/photo",
                headers=headers,
            )
        self.assertEqual(downloaded.status_code, 200)
        self.assertEqual(downloaded.content, b"imagen")

    def test_foto_de_medicamento_usa_almacenamiento_local_sin_supabase(self) -> None:
        """Permite subir y descargar fotos cuando Supabase no esta configurado."""
        from backend.core.config import settings
        from backend.services import medication_photo_service as photo_service

        original_url = settings.SUPABASE_URL
        original_key = settings.SUPABASE_SERVICE_ROLE_KEY
        settings.SUPABASE_URL = None
        settings.SUPABASE_SERVICE_ROLE_KEY = None
        try:
            object_path = photo_service.upload_medication_photo(
                user_id=7,
                medication_id=11,
                content=b"imagen-local",
                content_type="image/jpeg",
            )
            content = photo_service.download_medication_photo(object_path)
            self.assertEqual(content, b"imagen-local")
            photo_service.delete_medication_photo(object_path)
            with self.assertRaises(photo_service.MedicationPhotoNotFoundError):
                photo_service.download_medication_photo(object_path)
        finally:
            settings.SUPABASE_URL = original_url
            settings.SUPABASE_SERVICE_ROLE_KEY = original_key

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
        patient_medication_id = shared_medications.json()["items"][0]["id"]

        appointment_payload = {
            "doctor": "Dr. Perez",
            "specialty": "Cardiologia",
            "location": "Hospital Central",
            "notes": "Control anual",
            "reminder": "oneDayBefore",
            "scheduledAt": "2026-12-15T15:00:00+00:00",
        }
        patient_creates_appointment = self.client.post(
            "/api/v1/appointments",
            headers=patient_headers,
            json=appointment_payload,
        )
        self.assertEqual(patient_creates_appointment.status_code, 201)
        self.assertEqual(patient_creates_appointment.json()["doctor"], "Dr. Perez")

        caregiver_appointments = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/appointments",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_appointments.status_code, 200)
        self.assertEqual(len(caregiver_appointments.json()["items"]), 1)

        caregiver_creates_appointment = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/appointments",
            headers=caregiver_headers,
            json={
                **appointment_payload,
                "doctor": "Dra. Lopez",
                "scheduledAt": "2026-12-20T15:00:00+00:00",
            },
        )
        self.assertEqual(caregiver_creates_appointment.status_code, 201)

        patient_appointments = self.client.get(
            "/api/v1/appointments",
            headers=patient_headers,
        )
        self.assertEqual(patient_appointments.status_code, 200)
        self.assertEqual(len(patient_appointments.json()["items"]), 2)

        past_appointment_rejected = self.client.post(
            "/api/v1/appointments",
            headers=patient_headers,
            json={
                **appointment_payload,
                "scheduledAt": "2020-01-01T10:00:00+00:00",
            },
        )
        self.assertEqual(past_appointment_rejected.status_code, 422)

        health_entry_payload = {
            "kind": "allergy",
            "name": "Penicilina",
            "severity": "high",
            "detail": "Erupcion cutanea",
            "date": "2018",
        }
        patient_creates_entry = self.client.post(
            "/api/v1/health-entries",
            headers=patient_headers,
            json=health_entry_payload,
        )
        self.assertEqual(patient_creates_entry.status_code, 201)
        self.assertEqual(patient_creates_entry.json()["name"], "Penicilina")

        caregiver_health_hidden = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/health-entries",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_health_hidden.status_code, 200)
        self.assertEqual(len(caregiver_health_hidden.json()["items"]), 0)

        patient_shares_profile = self.client.put(
            "/api/v1/medical-profile",
            headers=patient_headers,
            json={
                "birthDate": "01/01/1950",
                "bloodType": "O+",
                "conditions": "Hipertension",
                "allergies": "Penicilina",
                "importantNotes": "Usar identificacion medica",
                "emergencyContactName": "Maria Lopez",
                "emergencyContactPhone": "0991234567",
                "shareWithCaregivers": True,
            },
        )
        self.assertEqual(patient_shares_profile.status_code, 200)
        self.assertTrue(patient_shares_profile.json()["shareWithCaregivers"])
        self.assertEqual(
            patient_shares_profile.json()["emergencyContactPhone"],
            "+593991234567",
        )
        patient_profile_contacts = self.client.get(
            "/api/v1/emergency-contacts",
            headers=patient_headers,
        )
        self.assertEqual(patient_profile_contacts.status_code, 200)
        self.assertEqual(len(patient_profile_contacts.json()["items"]), 1)
        self.assertEqual(
            patient_profile_contacts.json()["items"][0]["phone"],
            "+593991234567",
        )

        caregiver_health_entries = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/health-entries",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_health_entries.status_code, 200)
        self.assertEqual(len(caregiver_health_entries.json()["items"]), 1)

        caregiver_profile = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medical-profile",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_profile.status_code, 200)
        self.assertEqual(caregiver_profile.json()["bloodType"], "O+")
        self.assertEqual(
            caregiver_profile.json()["emergencyContactPhone"],
            "+593991234567",
        )

        caregiver_creates_entry = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/health-entries",
            headers=caregiver_headers,
            json={
                **health_entry_payload,
                "kind": "condition",
                "name": "Diabetes",
                "severity": "medium",
            },
        )
        self.assertEqual(caregiver_creates_entry.status_code, 201)

        patient_health_entries = self.client.get(
            "/api/v1/health-entries",
            headers=patient_headers,
        )
        self.assertEqual(patient_health_entries.status_code, 200)
        self.assertEqual(len(patient_health_entries.json()["items"]), 2)

        invalid_health_entry = self.client.post(
            "/api/v1/health-entries",
            headers=patient_headers,
            json={
                **health_entry_payload,
                "name": "X1",
            },
        )
        self.assertEqual(invalid_health_entry.status_code, 422)

        patient_creates_contact = self.client.post(
            "/api/v1/emergency-contacts",
            headers=patient_headers,
            json={
                "name": "Maria Lopez",
                "phone": "0991234567",
                "relationship": "Hija",
                "isPrimary": True,
            },
        )
        self.assertEqual(patient_creates_contact.status_code, 201)
        self.assertEqual(patient_creates_contact.json()["phone"], "+593991234567")

        caregiver_contacts = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/emergency-contacts",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_contacts.status_code, 200)
        self.assertEqual(len(caregiver_contacts.json()["items"]), 1)
        self.assertEqual(
            caregiver_contacts.json()["items"][0]["phone"],
            "+593991234567",
        )
        delete_profile_contact = self.client.delete(
            f"/api/v1/emergency-contacts/{caregiver_contacts.json()['items'][0]['id']}",
            headers=patient_headers,
        )
        self.assertEqual(delete_profile_contact.status_code, 204)
        profile_after_delete = self.client.get(
            "/api/v1/medical-profile",
            headers=patient_headers,
        )
        self.assertEqual(profile_after_delete.status_code, 200)
        self.assertEqual(profile_after_delete.json()["emergencyContactName"], "")
        self.assertEqual(profile_after_delete.json()["emergencyContactPhone"], "")

        caregiver_schedule_update = self.client.patch(
            f"/api/v1/caregiving/patients/{patient_id}/medications/{patient_medication_id}",
            headers=caregiver_headers,
            json={
                "name": "Losartan",
                "dose": "50 mg",
                "schedule": {
                    "mode": "fixed_times",
                    "times": ["09:00", "21:00"],
                    "weekdays": [1, 2, 3, 4, 5, 6, 7],
                    "start_date": "2026-07-09",
                },
            },
        )
        self.assertEqual(caregiver_schedule_update.status_code, 200)
        self.assertEqual(caregiver_schedule_update.json()["time"], "09:00")
        self.assertEqual(len(caregiver_schedule_update.json()["schedule"]["times"]), 2)

        with (
            patch(
                "backend.api.v1.endpoints.medications.upload_medication_photo",
                return_value=f"users/{patient_id}/medications/{patient_medication_id}/foto.jpg",
            ),
            patch(
                "backend.api.v1.endpoints.medications.delete_medication_photo",
            ),
            patch(
                "backend.api.v1.endpoints.caregiving.download_medication_photo",
                return_value=b"imagen-compartida",
            ),
        ):
            patient_photo = self.client.post(
                f"/api/v1/medications/{patient_medication_id}/photo",
                headers=patient_headers,
                files={"photo": ("foto.jpg", b"imagen-compartida", "image/jpeg")},
            )
            self.assertEqual(patient_photo.status_code, 200)
            self.assertTrue(patient_photo.json()["photoAvailable"])

            caregiver_photo = self.client.get(
                f"/api/v1/caregiving/patients/{patient_id}/medications/{patient_medication_id}/photo",
                headers=caregiver_headers,
            )
        self.assertEqual(caregiver_photo.status_code, 200)
        self.assertEqual(caregiver_photo.content, b"imagen-compartida")

        dose_event = {
            "client_event_id": "evento-cuidador-0001",
            "scheduled_at": "2026-07-09T08:00:00Z",
            "sequence_number": 1,
            "status": "taken",
            "acted_at": "2026-07-09T08:05:00Z",
        }
        patient_event = self.client.post(
            f"/api/v1/medications/{patient_medication_id}/dose-events",
            headers=patient_headers,
            json=dose_event,
        )
        self.assertEqual(patient_event.status_code, 200)

        caregiver_events = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications/dose-events",
            headers=caregiver_headers,
        )
        self.assertEqual(caregiver_events.status_code, 200)
        self.assertEqual(len(caregiver_events.json()), 1)
        self.assertEqual(
            caregiver_events.json()[0]["medication_name"],
            "Losartan",
        )

        caregiver_records_dose = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/medications/{patient_medication_id}/dose-events",
            headers=caregiver_headers,
            json={
                "client_event_id": "evento-cuidador-registro-0001",
                "scheduled_at": "2026-07-09T21:00:00Z",
                "sequence_number": 1,
                "status": "taken",
                "acted_at": "2026-07-09T21:10:00Z",
            },
        )
        self.assertEqual(caregiver_records_dose.status_code, 200)
        self.assertEqual(caregiver_records_dose.json()["status"], "taken")

        caregiver_events_after = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications/dose-events",
            headers=caregiver_headers,
        )
        self.assertGreaterEqual(len(caregiver_events_after.json()), 2)

        with (
            patch(
                "backend.api.v1.endpoints.caregiving.upload_medication_photo",
                return_value=f"users/{patient_id}/medications/{patient_medication_id}/cuidador.jpg",
            ),
            patch(
                "backend.api.v1.endpoints.caregiving.delete_medication_photo",
            ),
            patch(
                "backend.api.v1.endpoints.medications.download_medication_photo",
                return_value=b"foto-cuidador",
            ),
        ):
            caregiver_upload = self.client.post(
                f"/api/v1/caregiving/patients/{patient_id}/medications/{patient_medication_id}/photo",
                headers=caregiver_headers,
                files={"photo": ("foto.jpg", b"foto-cuidador", "image/jpeg")},
            )
            self.assertEqual(caregiver_upload.status_code, 200)
            self.assertTrue(caregiver_upload.json()["photoAvailable"])

            patient_photo = self.client.get(
                f"/api/v1/medications/{patient_medication_id}/photo",
                headers=patient_headers,
            )
        self.assertEqual(patient_photo.status_code, 200)
        self.assertEqual(patient_photo.content, b"foto-cuidador")

        with patch(
            "backend.api.v1.endpoints.caregiving.delete_medication_photo",
        ):
            deleted_by_caregiver = self.client.delete(
                f"/api/v1/caregiving/patients/{patient_id}/medications/{patient_medication_id}/photo",
                headers=caregiver_headers,
            )
        self.assertEqual(deleted_by_caregiver.status_code, 204)

        patient_meds_after_delete = self.client.get(
            "/api/v1/medications",
            headers=patient_headers,
        )
        losartan = next(
            item
            for item in patient_meds_after_delete.json()["items"]
            if item["id"] == patient_medication_id
        )
        self.assertFalse(losartan["photoAvailable"])

        caregiver_created = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/medications",
            headers=caregiver_headers,
            json={
                "name": "Aspirina",
                "dose": "100 mg",
                "time": "20:00",
            },
        )
        self.assertEqual(caregiver_created.status_code, 201)
        created_id = caregiver_created.json()["id"]

        patient_medications = self.client.get(
            "/api/v1/medications",
            headers=patient_headers,
        )
        self.assertEqual(patient_medications.status_code, 200)
        patient_names = {item["name"] for item in patient_medications.json()["items"]}
        self.assertIn("Aspirina", patient_names)

        caregiver_updated = self.client.patch(
            f"/api/v1/caregiving/patients/{patient_id}/medications/{created_id}",
            headers=caregiver_headers,
            json={"instructions": "Tomar con alimentos"},
        )
        self.assertEqual(caregiver_updated.status_code, 200)
        self.assertEqual(
            caregiver_updated.json()["instructions"],
            "Tomar con alimentos",
        )

        trash_before = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications/trash",
            headers=caregiver_headers,
        )
        self.assertEqual(trash_before.status_code, 200)
        self.assertEqual(trash_before.json()["items"], [])

        delete_aspirin = self.client.delete(
            f"/api/v1/caregiving/patients/{patient_id}/medications/{created_id}",
            headers=caregiver_headers,
        )
        self.assertEqual(delete_aspirin.status_code, 204)

        trash_after = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications/trash",
            headers=caregiver_headers,
        )
        self.assertEqual(len(trash_after.json()["items"]), 1)
        self.assertEqual(trash_after.json()["items"][0]["name"], "Aspirina")

        history_after_delete = self.client.get(
            f"/api/v1/caregiving/patients/{patient_id}/medications/dose-events",
            headers=caregiver_headers,
        )
        self.assertGreaterEqual(len(history_after_delete.json()), 1)

        restored = self.client.post(
            f"/api/v1/caregiving/patients/{patient_id}/medications/{created_id}/restore",
            headers=caregiver_headers,
        )
        self.assertEqual(restored.status_code, 200)
        self.assertEqual(restored.json()["name"], "Aspirina")

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
