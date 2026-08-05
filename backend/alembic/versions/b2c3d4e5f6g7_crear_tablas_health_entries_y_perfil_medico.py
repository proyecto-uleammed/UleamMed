"""crear tablas health_entries y user_medical_profiles

Revision ID: b2c3d4e5f6g7
Revises: a1b2c3d4e5f6
Create Date: 2026-07-10 08:00:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b2c3d4e5f6g7"
down_revision: str | Sequence[str] | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_medical_profiles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("birth_date", sa.String(length=10), server_default="", nullable=False),
        sa.Column("blood_type", sa.String(length=3), server_default="", nullable=False),
        sa.Column("conditions", sa.Text(), server_default="", nullable=False),
        sa.Column("allergies", sa.Text(), server_default="", nullable=False),
        sa.Column("important_notes", sa.Text(), server_default="", nullable=False),
        sa.Column("emergency_contact_name", sa.String(length=80), server_default="", nullable=False),
        sa.Column("emergency_contact_phone", sa.String(length=20), server_default="", nullable=False),
        sa.Column("share_with_caregivers", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index(
        op.f("ix_user_medical_profiles_id"),
        "user_medical_profiles",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_user_medical_profiles_user_id"),
        "user_medical_profiles",
        ["user_id"],
        unique=False,
    )

    op.create_table(
        "health_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("name", sa.String(length=150), nullable=False),
        sa.Column("severity", sa.String(length=20), server_default="low", nullable=False),
        sa.Column("detail", sa.String(length=500), server_default="", nullable=False),
        sa.Column("date", sa.String(length=30), server_default="", nullable=False),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_health_entries_id"), "health_entries", ["id"], unique=False)
    op.create_index(op.f("ix_health_entries_user_id"), "health_entries", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_health_entries_user_id"), table_name="health_entries")
    op.drop_index(op.f("ix_health_entries_id"), table_name="health_entries")
    op.drop_table("health_entries")
    op.drop_index(op.f("ix_user_medical_profiles_user_id"), table_name="user_medical_profiles")
    op.drop_index(op.f("ix_user_medical_profiles_id"), table_name="user_medical_profiles")
    op.drop_table("user_medical_profiles")
