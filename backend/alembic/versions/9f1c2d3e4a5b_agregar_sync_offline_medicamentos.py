"""agregar sync offline medicamentos

Revision ID: 9f1c2d3e4a5b
Revises: a1b2c3d4e5f6
Create Date: 2026-07-10 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "9f1c2d3e4a5b"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("medications", sa.Column("created_by_user_id", sa.Integer(), nullable=True))
    op.add_column("medications", sa.Column("last_modified_by_user_id", sa.Integer(), nullable=True))
    op.add_column("medications", sa.Column("client_medication_id", sa.String(length=100), nullable=True))
    op.add_column("medications", sa.Column("sync_fingerprint", sa.String(length=160), nullable=True))
    op.create_foreign_key(
        "fk_medications_created_by_user_id_users",
        "medications",
        "users",
        ["created_by_user_id"],
        ["id"],
    )
    op.create_foreign_key(
        "fk_medications_last_modified_by_user_id_users",
        "medications",
        "users",
        ["last_modified_by_user_id"],
        ["id"],
    )
    op.create_index(
        op.f("ix_medications_client_medication_id"),
        "medications",
        ["client_medication_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_medications_sync_fingerprint"),
        "medications",
        ["sync_fingerprint"],
        unique=False,
    )

    op.create_table(
        "medication_sync_conflicts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("patient_user_id", sa.Integer(), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("candidate_medication_id", sa.Integer(), nullable=True),
        sa.Column("resolved_medication_id", sa.Integer(), nullable=True),
        sa.Column("incoming_client_medication_id", sa.String(length=100), nullable=True),
        sa.Column("incoming_payload", sa.JSON(), nullable=False),
        sa.Column("similarity_score", sa.Float(), nullable=False),
        sa.Column("status", sa.String(length=30), server_default="pending", nullable=False),
        sa.Column("resolution", sa.String(length=30), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["candidate_medication_id"], ["medications.id"]),
        sa.ForeignKeyConstraint(["patient_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["resolved_medication_id"], ["medications.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_medication_sync_conflicts_id"), "medication_sync_conflicts", ["id"])
    op.create_index(
        op.f("ix_medication_sync_conflicts_patient_user_id"),
        "medication_sync_conflicts",
        ["patient_user_id"],
    )
    op.create_index(
        op.f("ix_medication_sync_conflicts_incoming_client_medication_id"),
        "medication_sync_conflicts",
        ["incoming_client_medication_id"],
    )

    op.create_table(
        "medication_sync_operations",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("patient_user_id", sa.Integer(), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=False),
        sa.Column("client_operation_id", sa.String(length=100), nullable=False),
        sa.Column("client_medication_id", sa.String(length=100), nullable=True),
        sa.Column("operation_type", sa.String(length=40), nullable=False),
        sa.Column("result_status", sa.String(length=40), nullable=False),
        sa.Column("medication_id", sa.Integer(), nullable=True),
        sa.Column("conflict_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["conflict_id"], ["medication_sync_conflicts.id"]),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"]),
        sa.ForeignKeyConstraint(["patient_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "patient_user_id",
            "client_operation_id",
            name="uq_medication_sync_operation_patient_client",
        ),
    )
    op.create_index(op.f("ix_medication_sync_operations_id"), "medication_sync_operations", ["id"])
    op.create_index(
        op.f("ix_medication_sync_operations_patient_user_id"),
        "medication_sync_operations",
        ["patient_user_id"],
    )
    op.create_index(
        op.f("ix_medication_sync_operations_client_medication_id"),
        "medication_sync_operations",
        ["client_medication_id"],
    )
    _revoke_data_api_access()


def downgrade() -> None:
    op.drop_index(op.f("ix_medication_sync_operations_client_medication_id"), table_name="medication_sync_operations")
    op.drop_index(op.f("ix_medication_sync_operations_patient_user_id"), table_name="medication_sync_operations")
    op.drop_index(op.f("ix_medication_sync_operations_id"), table_name="medication_sync_operations")
    op.drop_table("medication_sync_operations")

    op.drop_index(
        op.f("ix_medication_sync_conflicts_incoming_client_medication_id"),
        table_name="medication_sync_conflicts",
    )
    op.drop_index(op.f("ix_medication_sync_conflicts_patient_user_id"), table_name="medication_sync_conflicts")
    op.drop_index(op.f("ix_medication_sync_conflicts_id"), table_name="medication_sync_conflicts")
    op.drop_table("medication_sync_conflicts")

    op.drop_index(op.f("ix_medications_sync_fingerprint"), table_name="medications")
    op.drop_index(op.f("ix_medications_client_medication_id"), table_name="medications")
    op.drop_constraint("fk_medications_last_modified_by_user_id_users", "medications", type_="foreignkey")
    op.drop_constraint("fk_medications_created_by_user_id_users", "medications", type_="foreignkey")
    op.drop_column("medications", "sync_fingerprint")
    op.drop_column("medications", "client_medication_id")
    op.drop_column("medications", "last_modified_by_user_id")
    op.drop_column("medications", "created_by_user_id")


def _revoke_data_api_access() -> None:
    connection = op.get_bind()
    if connection.dialect.name != "postgresql":
        return
    available_roles = {
        row[0]
        for row in connection.execute(
            sa.text("SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated')")
        )
    }
    roles = [role for role in ("anon", "authenticated") if role in available_roles]
    if not roles:
        return
    role_list = ", ".join(roles)
    for table in ("medication_sync_conflicts", "medication_sync_operations"):
        op.execute(sa.text(f"REVOKE ALL PRIVILEGES ON TABLE {table} FROM {role_list}"))
