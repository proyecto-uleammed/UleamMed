"""merge heads 9f1c2d3e4a5b and b2c3d4e5f6g7

Revision ID: c0a1b2c3d4e5
Revises: 9f1c2d3e4a5b, b2c3d4e5f6g7
Create Date: 2026-07-10 16:00:00.000000

"""
from collections.abc import Sequence

revision: str = "c0a1b2c3d4e5"
down_revision: str | Sequence[str] | None = ("9f1c2d3e4a5b", "b2c3d4e5f6g7")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
