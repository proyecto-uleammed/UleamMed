"""agregar horarios y eventos de medicacion

Revision ID: f2d3a4b5c6d7
Revises: b1ca2dc36560
Create Date: 2026-07-09
"""

import sqlalchemy as sa
from alembic import op

revision = "f2d3a4b5c6d7"
down_revision = "b1ca2dc36560"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("medications", sa.Column("dose_amount", sa.Numeric(10, 2), nullable=True))
    op.add_column("medications", sa.Column("dose_unit", sa.String(30), nullable=True))
    op.add_column("medications", sa.Column("photo_path", sa.String(500), nullable=True))

    op.create_table(
        "medication_schedules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("medication_id", sa.Integer(), nullable=False),
        sa.Column("mode", sa.String(30), nullable=False),
        sa.Column("interval_hours", sa.Integer(), nullable=True),
        sa.Column("anchor_time", sa.Time(), nullable=True),
        sa.Column("weekdays", sa.String(30), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("medication_id"),
    )
    op.create_index("ix_medication_schedules_id", "medication_schedules", ["id"])

    op.create_table(
        "medication_schedule_times",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("schedule_id", sa.Integer(), nullable=False),
        sa.Column("time_of_day", sa.Time(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["schedule_id"], ["medication_schedules.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("schedule_id", "time_of_day", name="uq_medication_schedule_time"),
    )
    op.create_index("ix_medication_schedule_times_id", "medication_schedule_times", ["id"])

    op.create_table(
        "medication_dose_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("medication_id", sa.Integer(), nullable=False),
        sa.Column("client_event_id", sa.String(64), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("acted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("client_event_id", name="uq_medication_dose_event_client"),
        sa.UniqueConstraint(
            "medication_id",
            "scheduled_at",
            name="uq_medication_dose_event_schedule",
        ),
    )
    op.create_index("ix_medication_dose_events_id", "medication_dose_events", ["id"])
    op.create_index(
        "ix_medication_dose_events_medication_id",
        "medication_dose_events",
        ["medication_id"],
    )

    op.execute(
        """
        INSERT INTO medication_schedules (
            medication_id, mode, interval_hours, anchor_time, weekdays,
            start_date, end_date
        )
        SELECT id, 'fixed_times', NULL, schedule_time, '1,2,3,4,5,6,7',
               CURRENT_DATE, NULL
        FROM medications
        """
    )
    op.execute(
        """
        INSERT INTO medication_schedule_times (schedule_id, time_of_day, sort_order)
        SELECT s.id, m.schedule_time, 0
        FROM medication_schedules s
        JOIN medications m ON m.id = s.medication_id
        WHERE m.schedule_time IS NOT NULL
        """
    )


def downgrade() -> None:
    op.drop_index("ix_medication_dose_events_medication_id", table_name="medication_dose_events")
    op.drop_index("ix_medication_dose_events_id", table_name="medication_dose_events")
    op.drop_table("medication_dose_events")
    op.drop_index("ix_medication_schedule_times_id", table_name="medication_schedule_times")
    op.drop_table("medication_schedule_times")
    op.drop_index("ix_medication_schedules_id", table_name="medication_schedules")
    op.drop_table("medication_schedules")
    op.drop_column("medications", "photo_path")
    op.drop_column("medications", "dose_unit")
    op.drop_column("medications", "dose_amount")
