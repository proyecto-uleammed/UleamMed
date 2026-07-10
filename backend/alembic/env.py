from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context
from backend.core.config import settings
from backend.core.database import Base
from backend.models import appointment as appointment_model
from backend.models import caregiver as caregiver_model
from backend.models import caregiver_invitation as caregiver_invitation_model
from backend.models import caregiver_join_attempt as caregiver_join_attempt_model
from backend.models import caregiver_older_adult as caregiver_older_adult_model
from backend.models import exam_detail as exam_detail_model
from backend.models import exam_parameter as exam_parameter_model
from backend.models import fcm_token as fcm_token_model
from backend.models import guardian as guardian_model
from backend.models import medical_exam as medical_exam_model
from backend.models import medical_history as medical_history_model
from backend.models import medical_profile as medical_profile_model
from backend.models import medication as medication_model
from backend.models import medication_adherence_record as medication_adherence_record_model
from backend.models import medication_catalog as medication_catalog_model
from backend.models import medication_dose_event as medication_dose_event_model
from backend.models import medication_schedule as medication_schedule_model
from backend.models import medication_sync_conflict as medication_sync_conflict_model
from backend.models import medication_sync_operation as medication_sync_operation_model
from backend.models import notification as notification_model
from backend.models import notification_recipient as notification_recipient_model
from backend.models import older_adult as older_adult_model
from backend.models import password_reset_token as password_reset_token_model
from backend.models import patient_caregiver_link as patient_caregiver_link_model
from backend.models import treatment as treatment_model
from backend.models import treatment_medication as treatment_medication_model
from backend.models import user as user_model

_MODEL_MODULES = (
    appointment_model,
    caregiver_model,
    caregiver_invitation_model,
    caregiver_join_attempt_model,
    caregiver_older_adult_model,
    exam_detail_model,
    exam_parameter_model,
    fcm_token_model,
    guardian_model,
    medical_exam_model,
    medical_history_model,
    medical_profile_model,
    medication_model,
    medication_adherence_record_model,
    medication_catalog_model,
    medication_dose_event_model,
    medication_schedule_model,
    medication_sync_conflict_model,
    medication_sync_operation_model,
    notification_model,
    notification_recipient_model,
    older_adult_model,
    password_reset_token_model,
    patient_caregiver_link_model,
    treatment_model,
    treatment_medication_model,
    user_model,
)

LEGACY_SPANISH_TABLES = {
    "adulto_mayor",
    "cuidador",
    "cuidador_adulto_mayor",
    "cumplimiento_medicacion",
    "destinatario_notificacion",
    "detalle_examen",
    "encargado",
    "examen_medico",
    "historial_medico",
    "medicamento",
    "notificacion",
    "parametro_examen",
    "perfil_medico",
    "token_fcm",
    "tratamiento",
    "tratamiento_medicamento",
    "usuario",
}


def include_object(object_, name, type_, reflected, compare_to):
    """Avoid accidental drops while legacy Spanish tables are being phased out."""
    if type_ == "table" and reflected and compare_to is None and name in LEGACY_SPANISH_TABLES:
        return False
    return True

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Alembic debe apuntar a la misma base que usa FastAPI.
# En desarrollo puede ser PostgreSQL local; para el equipo debe ser la cadena
# de Supabase definida en DATABASE_URL dentro del entorno o archivo .env.
if settings.DATABASE_URL:
    config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Los imports de _MODEL_MODULES registran todos los modelos en Base.metadata
# para que Alembic pueda autogenerar migraciones correctamente.
target_metadata = Base.metadata

# other values from the config, defined by the needs of env.py,
# can be acquired:
# my_important_option = config.get_main_option("my_important_option")
# ... etc.


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        include_object=include_object,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.

    """
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_object=include_object,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
