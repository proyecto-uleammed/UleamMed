from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.models.appointment import Appointment
from backend.schemas.appointment import (
    AppointmentCreate,
    AppointmentRead,
    AppointmentReminder,
    AppointmentUpdate,
)


def list_user_appointments(db: Session, user_id: int) -> list[AppointmentRead]:
    statement = (
        select(Appointment)
        .where(Appointment.user_id == user_id, Appointment.is_active.is_(True))
        .order_by(Appointment.scheduled_at.asc())
    )
    return [_to_read(appointment) for appointment in db.scalars(statement)]


def create_user_appointment(
    db: Session,
    user_id: int,
    payload: AppointmentCreate,
) -> AppointmentRead:
    appointment = Appointment(
        user_id=user_id,
        doctor=payload.doctor.strip(),
        specialty=payload.specialty.strip(),
        location=payload.location.strip(),
        notes=payload.notes.strip(),
        scheduled_at=_normalize_datetime(payload.scheduledAt),
        completed=payload.completed,
        reminder=payload.reminder.value,
    )
    db.add(appointment)
    db.commit()
    db.refresh(appointment)
    return _to_read(appointment)


def update_user_appointment(
    db: Session,
    user_id: int,
    appointment_id: int,
    payload: AppointmentUpdate,
) -> AppointmentRead | None:
    appointment = _get_user_appointment(db, user_id, appointment_id)
    if appointment is None:
        return None

    if payload.doctor is not None:
        appointment.doctor = payload.doctor.strip()
    if payload.specialty is not None:
        appointment.specialty = payload.specialty.strip()
    if payload.location is not None:
        appointment.location = payload.location.strip()
    if payload.notes is not None:
        appointment.notes = payload.notes.strip()
    if payload.completed is not None:
        appointment.completed = payload.completed
    if payload.reminder is not None:
        appointment.reminder = payload.reminder.value
    if payload.scheduledAt is not None:
        appointment.scheduled_at = _normalize_datetime(payload.scheduledAt)

    db.commit()
    db.refresh(appointment)
    return _to_read(appointment)


def delete_user_appointment(db: Session, user_id: int, appointment_id: int) -> bool:
    appointment = _get_user_appointment(db, user_id, appointment_id)
    if appointment is None:
        return False
    appointment.is_active = False
    db.commit()
    return True


def _get_user_appointment(
    db: Session,
    user_id: int,
    appointment_id: int,
) -> Appointment | None:
    return db.scalar(
        select(Appointment).where(
            Appointment.id == appointment_id,
            Appointment.user_id == user_id,
            Appointment.is_active.is_(True),
        )
    )


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _to_read(appointment: Appointment) -> AppointmentRead:
    try:
        reminder = AppointmentReminder(appointment.reminder)
    except ValueError:
        reminder = AppointmentReminder.none
    return AppointmentRead(
        id=str(appointment.id),
        doctor=appointment.doctor,
        specialty=appointment.specialty,
        location=appointment.location,
        notes=appointment.notes,
        completed=appointment.completed,
        reminder=reminder,
        scheduledAt=appointment.scheduled_at,
    )
