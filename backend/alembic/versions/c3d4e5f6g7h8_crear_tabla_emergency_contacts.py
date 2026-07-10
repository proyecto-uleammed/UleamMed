"""crear emergency_contacts

Revision ID: c3d4e5f6g7h8
Revises: c0a1b2c3d4e5
Create Date: 2026-07-10 16:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3d4e5f6g7h8"
down_revision: Union[str, Sequence[str], None] = "c0a1b2c3d4e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "emergency_contacts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("phone", sa.String(length=20), nullable=False),
        sa.Column("relationship", sa.String(length=50), server_default="", nullable=False),
        sa.Column("is_primary", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_emergency_contacts_id"), "emergency_contacts", ["id"], unique=False)
    op.create_index(op.f("ix_emergency_contacts_user_id"), "emergency_contacts", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_emergency_contacts_user_id"), table_name="emergency_contacts")
    op.drop_index(op.f("ix_emergency_contacts_id"), table_name="emergency_contacts")
    op.drop_table("emergency_contacts")
