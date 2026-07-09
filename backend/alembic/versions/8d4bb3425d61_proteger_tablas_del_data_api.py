"""proteger tablas del data api

Revision ID: 8d4bb3425d61
Revises: 589f4391ef0c
Create Date: 2026-07-08 20:11:36.420223

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8d4bb3425d61'
down_revision: Union[str, Sequence[str], None] = '589f4391ef0c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Impide acceso directo a tablas cuando FastAPI es la unica API publica."""
    connection = op.get_bind()
    if connection.dialect.name != "postgresql":
        return

    available_roles = {
        row[0]
        for row in connection.execute(
            sa.text(
                "SELECT rolname FROM pg_roles "
                "WHERE rolname IN ('anon', 'authenticated')"
            )
        )
    }
    roles = [role for role in ("anon", "authenticated") if role in available_roles]
    if not roles:
        return

    role_list = ", ".join(roles)
    op.execute(
        sa.text(
            f"REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM {role_list}"
        )
    )
    op.execute(
        sa.text(
            f"REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM {role_list}"
        )
    )
    op.execute(
        sa.text(
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public "
            f"REVOKE ALL PRIVILEGES ON TABLES FROM {role_list}"
        )
    )
    op.execute(
        sa.text(
            "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public "
            f"REVOKE ALL PRIVILEGES ON SEQUENCES FROM {role_list}"
        )
    )


def downgrade() -> None:
    """No restaura permisos publicos inseguros automaticamente."""
