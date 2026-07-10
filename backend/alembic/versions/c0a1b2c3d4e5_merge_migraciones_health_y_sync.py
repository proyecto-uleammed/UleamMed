"""merge heads 9f1c2d3e4a5b and b2c3d4e5f6g7

Revision ID: c0a1b2c3d4e5
Revises: 9f1c2d3e4a5b, b2c3d4e5f6g7
Create Date: 2026-07-10 16:00:00.000000

"""
from typing import Sequence, Union

revision: str = "c0a1b2c3d4e5"
down_revision: Union[str, Sequence[str], None] = ("9f1c2d3e4a5b", "b2c3d4e5f6g7")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
