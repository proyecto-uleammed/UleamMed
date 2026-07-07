from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.core.database import Base


class MedicalExam(Base):
    __tablename__ = "medical_exams"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    medical_history_id: Mapped[int] = mapped_column(ForeignKey("medical_histories.id"), nullable=False)

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    exam_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    file_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    file_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    uploaded_at: Mapped[date | None] = mapped_column(Date, nullable=True)
