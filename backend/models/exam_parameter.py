from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class ExamParameter(Base):
    __tablename__ = "exam_parameters"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    exam_detail_id: Mapped[int] = mapped_column(ForeignKey("exam_details.id"), nullable=False)

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    obtained_value: Mapped[str | None] = mapped_column(String(100), nullable=True)
    reference_value: Mapped[str | None] = mapped_column(String(100), nullable=True)
    unit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    status: Mapped[str | None] = mapped_column(String(50), nullable=True)
