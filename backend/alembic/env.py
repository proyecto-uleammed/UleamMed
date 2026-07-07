from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context
from backend.core.config import settings
from backend.core.database import Base
from backend.models import adulto_mayor as adulto_mayor_model
from backend.models import cuidador as cuidador_model
from backend.models import cuidador_adulto_mayor as cuidador_adulto_mayor_model
from backend.models import cumplimiento_medicacion as cumplimiento_medicacion_model
from backend.models import destinatario_notificacion as destinatario_notificacion_model
from backend.models import detalle_examen as detalle_examen_model
from backend.models import encargado as encargado_model
from backend.models import examen_medico as examen_medico_model
from backend.models import historial_medico as historial_medico_model
from backend.models import medicamento as medicamento_model
from backend.models import notificacion as notificacion_model
from backend.models import parametro_examen as parametro_examen_model
from backend.models import password_reset_token as password_reset_token_model
from backend.models import perfil_medico as perfil_medico_model
from backend.models import token_fcm as token_fcm_model
from backend.models import tratamiento as tratamiento_model
from backend.models import tratamiento_medicamento as tratamiento_medicamento_model
from backend.models import user as user_model
from backend.models import usuario as usuario_model

_MODEL_MODULES = (
    adulto_mayor_model,
    cuidador_model,
    cuidador_adulto_mayor_model,
    cumplimiento_medicacion_model,
    destinatario_notificacion_model,
    detalle_examen_model,
    encargado_model,
    examen_medico_model,
    historial_medico_model,
    medicamento_model,
    notificacion_model,
    parametro_examen_model,
    password_reset_token_model,
    perfil_medico_model,
    token_fcm_model,
    tratamiento_model,
    tratamiento_medicamento_model,
    user_model,
    usuario_model,
)

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
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
