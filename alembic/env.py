from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

from backend.core.config import settings

# Las migraciones pueden apuntar a cualquier base (PostgreSQL local o Supabase)
# usando DATABASE_URL del entorno o del archivo .env. Asi evitamos escribir
# credenciales reales en alembic.ini, que si se versiona en Git.
# Si DATABASE_URL no esta definida, se usa el valor por defecto de alembic.ini.
if settings.DATABASE_URL:
    config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# add your model's MetaData object here
# for 'autogenerate' support
# from myapp import mymodel
# target_metadata = mymodel.Base.metadata
from backend.core.database import Base
from backend.models.user import User as _User
from backend.models.usuario import Usuario as _Usuario
from backend.models.encargado import Encargado as _Encargado
from backend.models.cuidador import Cuidador as _Cuidador
from backend.models.adulto_mayor import AdultoMayor as _AdultoMayor
from backend.models.perfil_medico import PerfilMedico as _PerfilMedico
from backend.models.historial_medico import HistorialMedico as _HistorialMedico
from backend.models.examen_medico import ExamenMedico as _ExamenMedico
from backend.models.detalle_examen import DetalleExamen as _DetalleExamen
from backend.models.parametro_examen import ParametroExamen as _ParametroExamen
from backend.models.medicamento import Medicamento as _Medicamento
from backend.models.tratamiento import Tratamiento as _Tratamiento
from backend.models.tratamiento_medicamento import TratamientoMedicamento as _TratamientoMedicamento
from backend.models.cumplimiento_medicacion import CumplimientoMedicacion as _CumplimientoMedicacion
from backend.models.notificacion import Notificacion as _Notificacion
from backend.models.destinatario_notificacion import DestinatarioNotificacion as _DestinatarioNotificacion
from backend.models.token_fcm import TokenFcm as _TokenFcm
from backend.models.cuidador_adulto_mayor import CuidadorAdultoMayor as _CuidadorAdultoMayor

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
