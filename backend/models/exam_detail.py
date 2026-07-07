from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class ExamDetail(Base):
    __tablename__ = "exam_details"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    medical_exam_id: Mapped[int] = mapped_column(ForeignKey("medical_exams.id"), nullable=False)

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
