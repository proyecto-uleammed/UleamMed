"""crear tabla appointments

Revision ID: a1b2c3d4e5f6
Revises: f2d3a4b5c6d7
Create Date: 2026-07-10 07:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "f2d3a4b5c6d7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "appointments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("doctor", sa.String(length=150), nullable=False),
        sa.Column("specialty", sa.String(length=150), nullable=False),
        sa.Column("location", sa.String(length=250), server_default="", nullable=False),
        sa.Column("notes", sa.String(length=1000), server_default="", nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("reminder", sa.String(length=30), server_default="none", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_appointments_id"), "appointments", ["id"], unique=False)
    op.create_index(op.f("ix_appointments_user_id"), "appointments", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_appointments_user_id"), table_name="appointments")
    op.drop_index(op.f("ix_appointments_id"), table_name="appointments")
    op.drop_table("appointments")
