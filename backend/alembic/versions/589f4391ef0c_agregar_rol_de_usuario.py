"""agregar rol de usuario

Revision ID: 589f4391ef0c
Revises: e7b3a9c2d4f1
Create Date: 2026-07-08 20:02:48.405392

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '589f4391ef0c'
down_revision: str | Sequence[str] | None = 'e7b3a9c2d4f1'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Agrega el rol y convierte todas las cuentas existentes en pacientes."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(
            sa.Column(
                "role",
                sa.String(length=32),
                server_default="patient",
                nullable=False,
            )
        )
        batch_op.create_check_constraint(
            "ck_users_role",
            "role IN ('patient', 'caregiver', 'professional', 'admin')",
        )


def downgrade() -> None:
    """Elimina el rol funcional."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_constraint("ck_users_role", type_="check")
        batch_op.drop_column("role")
