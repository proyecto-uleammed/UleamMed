from datetime import date, time

from sqlalchemy import Date, ForeignKey, Integer, String, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.core.database import Base


class MedicationSchedule(Base):
    __tablename__ = "medication_schedules"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    medication_id: Mapped[int] = mapped_column(
        ForeignKey("medications.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    mode: Mapped[str] = mapped_column(String(30), nullable=False)
    interval_hours: Mapped[int | None] = mapped_column(Integer, nullable=True)
    anchor_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    weekdays: Mapped[str] = mapped_column(String(30), nullable=False, default="1,2,3,4,5,6,7")
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    medication: Mapped["Medication"] = relationship(back_populates="schedule")
    times: Mapped[list["MedicationScheduleTime"]] = relationship(
        back_populates="schedule",
        cascade="all, delete-orphan",
        order_by="MedicationScheduleTime.sort_order",
    )


class MedicationScheduleTime(Base):
    __tablename__ = "medication_schedule_times"
    __table_args__ = (
        UniqueConstraint("schedule_id", "time_of_day", name="uq_medication_schedule_time"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    schedule_id: Mapped[int] = mapped_column(
        ForeignKey("medication_schedules.id", ondelete="CASCADE"),
        nullable=False,
    )
    time_of_day: Mapped[time] = mapped_column(Time, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    schedule: Mapped[MedicationSchedule] = relationship(back_populates="times")


from backend.models.medication import Medication  # noqa: E402
