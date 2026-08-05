"""crear tablas en ingles para mer

Revision ID: e7b3a9c2d4f1
Revises: c5fbfe125a1b
Create Date: 2026-07-07 10:30:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect, text

# revision identifiers, used by Alembic.
revision: str = "e7b3a9c2d4f1"
down_revision: str | Sequence[str] | None = "c5fbfe125a1b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create English MER tables and copy legacy Spanish data when available."""
    _create_tables()
    _copy_legacy_data()


def downgrade() -> None:
    """Drop only the English transition tables."""
    for table_name in (
        "exam_parameters",
        "exam_details",
        "medication_adherence_records",
        "treatment_medications",
        "medical_exams",
        "treatments",
        "medical_profiles",
        "medical_histories",
        "caregiver_older_adults",
        "older_adults",
        "fcm_tokens",
        "notification_recipients",
        "notifications",
        "medication_catalog",
        "caregivers",
        "guardians",
    ):
        if _has_table(table_name):
            op.drop_table(table_name)


def _create_tables() -> None:
    if not _has_table("guardians"):
        op.create_table(
            "guardians",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=True),
            sa.Column("first_names", sa.String(length=100), nullable=False),
            sa.Column("last_names", sa.String(length=100), nullable=False),
            sa.Column("national_id", sa.String(length=20), nullable=False),
            sa.Column("phone", sa.String(length=20), nullable=True),
            sa.Column("address", sa.String(length=255), nullable=True),
            sa.Column("relationship", sa.String(length=50), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("national_id"),
            sa.UniqueConstraint("user_id"),
        )
        op.create_index(op.f("ix_guardians_id"), "guardians", ["id"], unique=False)

    if not _has_table("caregivers"):
        op.create_table(
            "caregivers",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=True),
            sa.Column("first_names", sa.String(length=100), nullable=False),
            sa.Column("last_names", sa.String(length=100), nullable=False),
            sa.Column("phone", sa.String(length=20), nullable=True),
            sa.Column("specialty", sa.String(length=100), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("user_id"),
        )
        op.create_index(op.f("ix_caregivers_id"), "caregivers", ["id"], unique=False)

    if not _has_table("medication_catalog"):
        op.create_table(
            "medication_catalog",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=150), nullable=False),
            sa.Column("description", sa.String(length=500), nullable=True),
            sa.Column("presentation", sa.String(length=100), nullable=True),
            sa.Column("manufacturer", sa.String(length=150), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_medication_catalog_id"), "medication_catalog", ["id"], unique=False)

    if not _has_table("notifications"):
        op.create_table(
            "notifications",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("title", sa.String(length=150), nullable=False),
            sa.Column("message", sa.String(length=500), nullable=False),
            sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("type", sa.String(length=50), nullable=True),
            sa.Column("priority", sa.String(length=50), nullable=True),
            sa.Column("is_sent", sa.Boolean(), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_notifications_id"), "notifications", ["id"], unique=False)

    if not _has_table("notification_recipients"):
        op.create_table(
            "notification_recipients",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("notification_id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=True),
            sa.Column("is_read", sa.Boolean(), nullable=False),
            sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["notification_id"], ["notifications.id"]),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_notification_recipients_id"), "notification_recipients", ["id"], unique=False)

    if not _has_table("fcm_tokens"):
        op.create_table(
            "fcm_tokens",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=True),
            sa.Column("token", sa.String(length=500), nullable=False),
            sa.Column("registered_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("token"),
        )
        op.create_index(op.f("ix_fcm_tokens_id"), "fcm_tokens", ["id"], unique=False)

    if not _has_table("older_adults"):
        op.create_table(
            "older_adults",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("user_id", sa.Integer(), nullable=True),
            sa.Column("guardian_id", sa.Integer(), nullable=False),
            sa.Column("first_names", sa.String(length=100), nullable=False),
            sa.Column("last_names", sa.String(length=100), nullable=False),
            sa.Column("national_id", sa.String(length=20), nullable=False),
            sa.Column("birth_date", sa.Date(), nullable=False),
            sa.Column("phone", sa.String(length=20), nullable=True),
            sa.Column("address", sa.String(length=255), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.ForeignKeyConstraint(["guardian_id"], ["guardians.id"]),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("national_id"),
            sa.UniqueConstraint("user_id"),
        )
        op.create_index(op.f("ix_older_adults_id"), "older_adults", ["id"], unique=False)

    if not _has_table("caregiver_older_adults"):
        op.create_table(
            "caregiver_older_adults",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("caregiver_id", sa.Integer(), nullable=False),
            sa.Column("older_adult_id", sa.Integer(), nullable=False),
            sa.Column("linked_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["caregiver_id"], ["caregivers.id"]),
            sa.ForeignKeyConstraint(["older_adult_id"], ["older_adults.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("caregiver_id", "older_adult_id", name="uq_caregiver_older_adults"),
        )
        op.create_index(op.f("ix_caregiver_older_adults_id"), "caregiver_older_adults", ["id"], unique=False)

    if not _has_table("medical_histories"):
        op.create_table(
            "medical_histories",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("older_adult_id", sa.Integer(), nullable=False),
            sa.Column("visit_date", sa.Date(), nullable=False),
            sa.Column("reason", sa.String(length=255), nullable=True),
            sa.Column("weight", sa.Numeric(precision=5, scale=2), nullable=True),
            sa.Column("height", sa.Numeric(precision=4, scale=2), nullable=True),
            sa.Column("body_mass_index", sa.Numeric(precision=5, scale=2), nullable=True),
            sa.Column("blood_pressure", sa.String(length=20), nullable=True),
            sa.Column("heart_rate", sa.Integer(), nullable=True),
            sa.Column("temperature", sa.Numeric(precision=4, scale=1), nullable=True),
            sa.Column("oxygen_saturation", sa.Integer(), nullable=True),
            sa.Column("glucose_level", sa.Numeric(precision=6, scale=2), nullable=True),
            sa.Column("pain_level", sa.Integer(), nullable=True),
            sa.Column("general_condition", sa.String(length=255), nullable=True),
            sa.Column("diagnosis", sa.String(length=500), nullable=True),
            sa.Column("indicated_treatment", sa.String(length=500), nullable=True),
            sa.Column("recommendations", sa.String(length=500), nullable=True),
            sa.Column("doctor_name", sa.String(length=150), nullable=True),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["older_adult_id"], ["older_adults.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_medical_histories_id"), "medical_histories", ["id"], unique=False)

    if not _has_table("medical_profiles"):
        op.create_table(
            "medical_profiles",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("older_adult_id", sa.Integer(), nullable=False),
            sa.Column("blood_type", sa.String(length=10), nullable=True),
            sa.Column("allergies", sa.String(length=500), nullable=True),
            sa.Column("chronic_diseases", sa.String(length=500), nullable=True),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["older_adult_id"], ["older_adults.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("older_adult_id"),
        )
        op.create_index(op.f("ix_medical_profiles_id"), "medical_profiles", ["id"], unique=False)

    if not _has_table("treatments"):
        op.create_table(
            "treatments",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("older_adult_id", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=150), nullable=False),
            sa.Column("goal", sa.String(length=500), nullable=True),
            sa.Column("start_date", sa.Date(), nullable=False),
            sa.Column("end_date", sa.Date(), nullable=True),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.ForeignKeyConstraint(["older_adult_id"], ["older_adults.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_treatments_id"), "treatments", ["id"], unique=False)

    if not _has_table("medical_exams"):
        op.create_table(
            "medical_exams",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("medical_history_id", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=150), nullable=False),
            sa.Column("exam_date", sa.Date(), nullable=True),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.Column("file_url", sa.String(length=500), nullable=True),
            sa.Column("file_type", sa.String(length=50), nullable=True),
            sa.Column("uploaded_at", sa.Date(), nullable=True),
            sa.ForeignKeyConstraint(["medical_history_id"], ["medical_histories.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_medical_exams_id"), "medical_exams", ["id"], unique=False)

    if not _has_table("treatment_medications"):
        op.create_table(
            "treatment_medications",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("treatment_id", sa.Integer(), nullable=False),
            sa.Column("medication_catalog_id", sa.Integer(), nullable=False),
            sa.Column("dose", sa.String(length=100), nullable=False),
            sa.Column("frequency", sa.String(length=100), nullable=False),
            sa.Column("administration_route", sa.String(length=100), nullable=True),
            sa.Column("start_time", sa.Time(), nullable=True),
            sa.Column("end_time", sa.Time(), nullable=True),
            sa.Column("notes", sa.String(length=500), nullable=True),
            sa.ForeignKeyConstraint(["medication_catalog_id"], ["medication_catalog.id"]),
            sa.ForeignKeyConstraint(["treatment_id"], ["treatments.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_treatment_medications_id"), "treatment_medications", ["id"], unique=False)

    if not _has_table("medication_adherence_records"):
        op.create_table(
            "medication_adherence_records",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("treatment_medication_id", sa.Integer(), nullable=False),
            sa.Column("scheduled_date", sa.Date(), nullable=False),
            sa.Column("scheduled_time", sa.Time(), nullable=False),
            sa.Column("actual_datetime", sa.DateTime(timezone=True), nullable=True),
            sa.Column("status", sa.String(length=50), nullable=False),
            sa.Column("note", sa.String(length=500), nullable=True),
            sa.Column("recorded_by", sa.String(length=100), nullable=True),
            sa.Column("confirmed_by", sa.String(length=100), nullable=True),
            sa.Column("recorded_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint(["treatment_medication_id"], ["treatment_medications.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_medication_adherence_records_id"), "medication_adherence_records", ["id"], unique=False)

    if not _has_table("exam_details"):
        op.create_table(
            "exam_details",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("medical_exam_id", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=150), nullable=False),
            sa.Column("description", sa.String(length=500), nullable=True),
            sa.ForeignKeyConstraint(["medical_exam_id"], ["medical_exams.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_exam_details_id"), "exam_details", ["id"], unique=False)

    if not _has_table("exam_parameters"):
        op.create_table(
            "exam_parameters",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("exam_detail_id", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(length=150), nullable=False),
            sa.Column("obtained_value", sa.String(length=100), nullable=True),
            sa.Column("reference_value", sa.String(length=100), nullable=True),
            sa.Column("unit", sa.String(length=50), nullable=True),
            sa.Column("status", sa.String(length=50), nullable=True),
            sa.ForeignKeyConstraint(["exam_detail_id"], ["exam_details.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_exam_parameters_id"), "exam_parameters", ["id"], unique=False)


def _copy_legacy_data() -> None:
    _copy_users_from_legacy_usuario()
    _copy_table(
        "encargado",
        """
        INSERT INTO guardians (id, user_id, first_names, last_names, national_id, phone, address, relationship, created_at, updated_at, is_active)
        SELECT e.id_encargado, u2.id, e.nombres, e.apellidos, e.cedula, e.telefono, e.direccion, e.parentesco,
               e.fecha_creacion, e.fecha_actualizacion, e.activo
        FROM encargado e
        LEFT JOIN usuario u ON u.id_usuario = e.id_usuario
        LEFT JOIN users u2 ON u2.email = u.correo
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "cuidador",
        """
        INSERT INTO caregivers (id, user_id, first_names, last_names, phone, specialty, created_at, updated_at, is_active)
        SELECT c.id_cuidador, u2.id, c.nombres, c.apellidos, c.telefono, c.especialidad,
               c.fecha_creacion, c.fecha_actualizacion, c.activo
        FROM cuidador c
        LEFT JOIN usuario u ON u.id_usuario = c.id_usuario
        LEFT JOIN users u2 ON u2.email = u.correo
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "medicamento",
        """
        INSERT INTO medication_catalog (id, name, description, presentation, manufacturer, is_active)
        SELECT id_medicamento, nombre, descripcion, presentacion, fabricante, activo
        FROM medicamento
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "notificacion",
        """
        INSERT INTO notifications (id, title, message, sent_at, type, priority, is_sent)
        SELECT id_notificacion, titulo, mensaje, fecha_envio, tipo, prioridad, enviada
        FROM notificacion
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "destinatario_notificacion",
        """
        INSERT INTO notification_recipients (id, notification_id, user_id, is_read, read_at)
        SELECT d.id_destinatario, d.id_notificacion, u2.id, d.leida, d.fecha_lectura
        FROM destinatario_notificacion d
        LEFT JOIN usuario u ON u.id_usuario = d.id_usuario
        LEFT JOIN users u2 ON u2.email = u.correo
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "token_fcm",
        """
        INSERT INTO fcm_tokens (id, user_id, token, registered_at)
        SELECT t.id_token, u2.id, t.token, t.fecha_registro
        FROM token_fcm t
        LEFT JOIN usuario u ON u.id_usuario = t.id_usuario
        LEFT JOIN users u2 ON u2.email = u.correo
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "adulto_mayor",
        """
        INSERT INTO older_adults (id, user_id, guardian_id, first_names, last_names, national_id, birth_date, phone, address, created_at, updated_at, is_active)
        SELECT a.id_adulto_mayor, u2.id, a.id_encargado, a.nombres, a.apellidos, a.cedula,
               a.fecha_nacimiento, a.telefono, a.direccion, a.fecha_creacion, a.fecha_actualizacion, a.activo
        FROM adulto_mayor a
        LEFT JOIN usuario u ON u.id_usuario = a.id_usuario
        LEFT JOIN users u2 ON u2.email = u.correo
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "cuidador_adulto_mayor",
        """
        INSERT INTO caregiver_older_adults (id, caregiver_id, older_adult_id, linked_at)
        SELECT id_relacion, id_cuidador, id_adulto_mayor, fecha_vinculacion
        FROM cuidador_adulto_mayor
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "historial_medico",
        """
        INSERT INTO medical_histories (
            id, older_adult_id, visit_date, reason, weight, height, body_mass_index,
            blood_pressure, heart_rate, temperature, oxygen_saturation, glucose_level,
            pain_level, general_condition, diagnosis, indicated_treatment,
            recommendations, doctor_name, notes, created_at
        )
        SELECT id_historial, id_adulto_mayor, fecha_consulta, motivo_consulta, peso, altura,
               indice_masa_corporal, presion_arterial, frecuencia_cardiaca, temperatura,
               saturacion_oxigeno, nivel_glucosa, nivel_dolor, estado_general, diagnostico,
               tratamiento_indicado, recomendaciones, nombre_medico, observaciones, fecha_creacion
        FROM historial_medico
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "perfil_medico",
        """
        INSERT INTO medical_profiles (id, older_adult_id, blood_type, allergies, chronic_diseases, notes, updated_at)
        SELECT id_perfil, id_adulto_mayor, tipo_sangre, alergias, enfermedades_cronicas, observaciones, fecha_actualizacion
        FROM perfil_medico
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "tratamiento",
        """
        INSERT INTO treatments (id, older_adult_id, name, goal, start_date, end_date, notes, created_at, updated_at, is_active)
        SELECT id_tratamiento, id_adulto_mayor, nombre_tratamiento, objetivo, fecha_inicio, fecha_fin,
               observaciones, fecha_creacion, fecha_actualizacion, activo
        FROM tratamiento
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "examen_medico",
        """
        INSERT INTO medical_exams (id, medical_history_id, name, exam_date, notes, file_url, file_type, uploaded_at)
        SELECT id_examen, id_historial, nombre_examen, fecha_examen, observaciones, archivo_url, tipo_archivo, fecha_subida
        FROM examen_medico
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "tratamiento_medicamento",
        """
        INSERT INTO treatment_medications (
            id, treatment_id, medication_catalog_id, dose, frequency,
            administration_route, start_time, end_time, notes
        )
        SELECT id_tratamiento_medicamento, id_tratamiento, id_medicamento, dosis, frecuencia,
               via_administracion, hora_inicio, hora_fin, observaciones
        FROM tratamiento_medicamento
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "cumplimiento_medicacion",
        """
        INSERT INTO medication_adherence_records (
            id, treatment_medication_id, scheduled_date, scheduled_time, actual_datetime,
            status, note, recorded_by, confirmed_by, recorded_at
        )
        SELECT id_cumplimiento, id_tratamiento_medicamento, fecha_programada, hora_programada,
               fecha_hora_real, estado, observacion, registrado_por, confirmado_por, fecha_registro
        FROM cumplimiento_medicacion
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "detalle_examen",
        """
        INSERT INTO exam_details (id, medical_exam_id, name, description)
        SELECT id_detalle, id_examen, nombre_detalle, descripcion
        FROM detalle_examen
        ON CONFLICT (id) DO NOTHING
        """,
    )
    _copy_table(
        "parametro_examen",
        """
        INSERT INTO exam_parameters (id, exam_detail_id, name, obtained_value, reference_value, unit, status)
        SELECT id_parametro, id_detalle, nombre_parametro, valor_obtenido, valor_referencia, unidad_medida, estado
        FROM parametro_examen
        ON CONFLICT (id) DO NOTHING
        """,
    )


def _copy_users_from_legacy_usuario() -> None:
    if not _has_table("usuario") or not _has_table("users"):
        return
    _execute_insert(
        """
        INSERT INTO users (email, full_name, hashed_password, is_active, created_at, updated_at)
        SELECT correo, NULL, password_hash, activo, fecha_creacion, fecha_actualizacion
        FROM usuario
        ON CONFLICT (email) DO NOTHING
        """
    )


def _copy_table(source_table: str, sql: str) -> None:
    if _has_table(source_table):
        _execute_insert(sql)


def _execute_insert(sql: str) -> None:
    if op.get_bind().dialect.name == "sqlite":
        sql = sql.replace("INSERT INTO", "INSERT OR IGNORE INTO", 1)
        sql = sql.replace("ON CONFLICT (id) DO NOTHING", "")
        sql = sql.replace("ON CONFLICT (email) DO NOTHING", "")
    op.execute(text(sql))


def _has_table(table_name: str) -> bool:
    return inspect(op.get_bind()).has_table(table_name)
