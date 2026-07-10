from datetime import UTC, date, datetime, time
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from backend.models.medication import Medication
from backend.models.medication_dose_event import MedicationDoseEvent
from backend.models.medication_schedule import MedicationSchedule, MedicationScheduleTime
from backend.schemas.medication import (
    MedicationCreate,
    MedicationDoseEventCreate,
    MedicationDoseEventRead,
    MedicationRead,
    MedicationScheduleMode,
    MedicationSchedulePayload,
    MedicationScheduleRead,
    MedicationUpdate,
)


def list_user_medications(db: Session, user_id: int) -> list[MedicationRead]:
    statement = (
        select(Medication)
        .options(selectinload(Medication.schedule).selectinload(MedicationSchedule.times))
        .where(Medication.user_id == user_id, Medication.is_active.is_(True))
        .order_by(Medication.schedule_time.asc().nulls_last(), Medication.name.asc())
    )
    return [_to_read(medication) for medication in db.scalars(statement)]


def create_user_medication(db: Session, user_id: int, payload: MedicationCreate) -> MedicationRead:
    dose_label = _dose_label(payload.doseAmount, payload.doseUnit, payload.dose)
    schedule_payload = payload.schedule or _legacy_schedule(payload.time)
    medication = Medication(
        user_id=user_id,
        name=payload.name.strip(),
        dose=dose_label,
        dose_amount=payload.doseAmount,
        dose_unit=(payload.doseUnit or "").strip() or None,
        frequency=(payload.frequency or _frequency_label(schedule_payload)).strip(),
        duration=(payload.duration or _duration_label(schedule_payload)).strip(),
        schedule_time=_parse_time(schedule_payload.times[0]),
        instructions=(payload.instructions or "").strip(),
        is_important=payload.isImportant,
    )
    db.add(medication)
    db.flush()
    medication.schedule = _build_schedule(schedule_payload)
    db.commit()
    return _read_user_medication(db, user_id, medication.id)


def update_user_medication(
    db: Session,
    user_id: int,
    medication_id: int,
    payload: MedicationUpdate,
) -> MedicationRead | None:
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return None

    if payload.name is not None:
        medication.name = payload.name.strip()
    if payload.doseAmount is not None:
        medication.dose_amount = payload.doseAmount
        medication.dose_unit = (payload.doseUnit or medication.dose_unit or "").strip()
        medication.dose = _dose_label(
            medication.dose_amount,
            medication.dose_unit,
            payload.dose,
        )
    elif payload.dose is not None:
        medication.dose = payload.dose.strip()
    if payload.instructions is not None:
        medication.instructions = payload.instructions.strip()
    if payload.isImportant is not None:
        medication.is_important = payload.isImportant
    if payload.taken is not None:
        medication.taken = payload.taken

    if payload.schedule is not None:
        medication.schedule = None
        db.flush()
        medication.schedule = _build_schedule(payload.schedule)
        medication.schedule_time = _parse_time(payload.schedule.times[0])
        medication.frequency = _frequency_label(payload.schedule)
        medication.duration = _duration_label(payload.schedule)
    elif payload.time is not None:
        medication.schedule_time = _parse_time(payload.time)
        if medication.schedule and medication.schedule.times:
            medication.schedule.times[0].time_of_day = medication.schedule_time
    if payload.frequency is not None and payload.schedule is None:
        medication.frequency = payload.frequency.strip()
    if payload.duration is not None and payload.schedule is None:
        medication.duration = payload.duration.strip()

    db.add(medication)
    db.commit()
    return _read_user_medication(db, user_id, medication.id)


def delete_user_medication(db: Session, user_id: int, medication_id: int) -> bool:
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return False
    medication.is_active = False
    db.add(medication)
    db.commit()
    return True


def list_deleted_user_medications(db: Session, user_id: int) -> list[MedicationRead]:
    """Lista medicamentos eliminados logicamente del usuario."""
    statement = (
        select(Medication)
        .options(selectinload(Medication.schedule).selectinload(MedicationSchedule.times))
        .where(Medication.user_id == user_id, Medication.is_active.is_(False))
        .order_by(Medication.updated_at.desc(), Medication.name.asc())
    )
    return [_to_read(medication) for medication in db.scalars(statement)]


def restore_user_medication(
    db: Session,
    user_id: int,
    medication_id: int,
) -> MedicationRead | None:
    """Restaura un medicamento previamente eliminado logicamente."""
    medication = _get_inactive_user_medication(db, user_id, medication_id)
    if medication is None:
        return None
    medication.is_active = True
    db.add(medication)
    db.commit()
    db.refresh(medication)
    return _to_read(medication)


def mark_user_medication_taken(
    db: Session,
    user_id: int,
    medication_id: int,
) -> MedicationRead | None:
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return None
    medication.taken = True
    db.add(medication)
    db.commit()
    return _read_user_medication(db, user_id, medication.id)


def record_dose_event(
    db: Session,
    user_id: int,
    medication_id: int,
    payload: MedicationDoseEventCreate,
) -> MedicationDoseEventRead | None:
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return None

    existing = db.scalar(
        select(MedicationDoseEvent).where(
            MedicationDoseEvent.client_event_id == payload.client_event_id,
            MedicationDoseEvent.medication_id == medication_id,
        )
    )
    if existing is None and db.scalar(
        select(MedicationDoseEvent.id).where(
            MedicationDoseEvent.client_event_id == payload.client_event_id
        )
    ):
        raise ValueError("El identificador del evento ya esta en uso")
    if existing is None:
        existing = db.scalar(
            select(MedicationDoseEvent).where(
                MedicationDoseEvent.medication_id == medication_id,
                MedicationDoseEvent.scheduled_at == payload.scheduled_at,
            )
        )
    if existing is None:
        existing = MedicationDoseEvent(
            medication_id=medication_id,
            client_event_id=payload.client_event_id,
            scheduled_at=payload.scheduled_at,
            sequence_number=payload.sequence_number,
            status=payload.status.value,
            acted_at=payload.acted_at or datetime.now(UTC),
            snoozed_until=payload.snoozed_until,
        )
        db.add(existing)
        if payload.status.value == "taken":
            medication.taken = True
            db.add(medication)
        db.commit()
        db.refresh(existing)
    elif payload.status.value == "taken" and not medication.taken:
        medication.taken = True
        db.add(medication)
        db.commit()
    return _event_to_read(existing, medication.name)


def list_dose_events(
    db: Session,
    user_id: int,
    *,
    start: datetime | None = None,
    end: datetime | None = None,
) -> list[MedicationDoseEventRead]:
    statement = (
        select(MedicationDoseEvent, Medication.name)
        .join(Medication, Medication.id == MedicationDoseEvent.medication_id)
        .where(Medication.user_id == user_id)
        .order_by(MedicationDoseEvent.scheduled_at.desc())
    )
    if start is not None:
        statement = statement.where(MedicationDoseEvent.scheduled_at >= start)
    if end is not None:
        statement = statement.where(MedicationDoseEvent.scheduled_at <= end)
    return [_event_to_read(event, name) for event, name in db.execute(statement)]


def count_taken_medications(db: Session, user_id: int) -> tuple[int, int]:
    medications = list_user_medications(db, user_id)
    return sum(1 for medication in medications if medication.taken), len(medications)


def get_user_medication_model(
    db: Session,
    user_id: int,
    medication_id: int,
) -> Medication | None:
    return _get_user_medication(db, user_id, medication_id)


def medication_to_read(db: Session, user_id: int, medication_id: int) -> MedicationRead:
    return _read_user_medication(db, user_id, medication_id)


def _get_user_medication(db: Session, user_id: int, medication_id: int) -> Medication | None:
    return db.scalar(
        select(Medication)
        .options(selectinload(Medication.schedule).selectinload(MedicationSchedule.times))
        .where(
            Medication.id == medication_id,
            Medication.user_id == user_id,
            Medication.is_active.is_(True),
        )
    )


def _get_inactive_user_medication(
    db: Session,
    user_id: int,
    medication_id: int,
) -> Medication | None:
    return db.scalar(
        select(Medication)
        .options(selectinload(Medication.schedule).selectinload(MedicationSchedule.times))
        .where(
            Medication.id == medication_id,
            Medication.user_id == user_id,
            Medication.is_active.is_(False),
        )
    )


def _read_user_medication(db: Session, user_id: int, medication_id: int) -> MedicationRead:
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        raise ValueError("Medicamento no encontrado")
    return _to_read(medication)


def _legacy_schedule(value: str | None) -> MedicationSchedulePayload:
    if not value:
        raise ValueError("Selecciona un horario")
    return MedicationSchedulePayload(
        mode=MedicationScheduleMode.fixed_times,
        times=[value],
        weekdays=[1, 2, 3, 4, 5, 6, 7],
        start_date=date.today(),
    )


def _build_schedule(payload: MedicationSchedulePayload) -> MedicationSchedule:
    schedule = MedicationSchedule(
        mode=payload.mode.value,
        interval_hours=payload.interval_hours,
        anchor_time=_parse_time(payload.times[0]),
        weekdays=",".join(str(day) for day in sorted(payload.weekdays)),
        start_date=payload.start_date,
        end_date=payload.end_date,
    )
    schedule.times = [
        MedicationScheduleTime(time_of_day=_parse_time(value), sort_order=index)
        for index, value in enumerate(sorted(set(payload.times)))
    ]
    return schedule


def _parse_time(value: str) -> time:
    try:
        return time.fromisoformat(value.strip())
    except ValueError as exc:
        raise ValueError("Formato de hora invalido. Usa HH:MM.") from exc


def _format_time(value: time | None) -> str:
    return value.strftime("%H:%M") if value is not None else ""


def _dose_label(amount: Decimal | None, unit: str | None, legacy: str | None) -> str:
    if amount is None:
        if legacy and legacy.strip():
            return legacy.strip()
        raise ValueError("Ingresa la dosis")
    normalized = format(amount.normalize(), "f")
    return f"{normalized} {(unit or '').strip()}".strip()


def _frequency_label(schedule: MedicationSchedulePayload) -> str:
    if schedule.mode == MedicationScheduleMode.interval:
        return f"Cada {schedule.interval_hours} horas"
    count = len(schedule.times)
    return "Diario" if count == 1 else f"{count} veces al dia"


def _duration_label(schedule: MedicationSchedulePayload) -> str:
    if schedule.end_date is None:
        return "Permanente"
    days = (schedule.end_date - schedule.start_date).days + 1
    return f"{days} dias"


def _to_read(medication: Medication) -> MedicationRead:
    schedule = medication.schedule
    if schedule is None:
        schedule_read = MedicationScheduleRead(
            mode=MedicationScheduleMode.fixed_times,
            times=[_format_time(medication.schedule_time)],
            weekdays=[1, 2, 3, 4, 5, 6, 7],
            start_date=medication.created_at.date(),
        )
    else:
        schedule_read = MedicationScheduleRead(
            mode=MedicationScheduleMode(schedule.mode),
            interval_hours=schedule.interval_hours,
            times=[_format_time(item.time_of_day) for item in schedule.times],
            weekdays=[int(day) for day in schedule.weekdays.split(",") if day],
            start_date=schedule.start_date,
            end_date=schedule.end_date,
        )
    primary_time = schedule_read.times[0] if schedule_read.times else ""
    return MedicationRead(
        id=str(medication.id),
        name=medication.name,
        dose=medication.dose,
        doseAmount=medication.dose_amount,
        doseUnit=medication.dose_unit,
        time=primary_time,
        taken=medication.taken,
        frequency=medication.frequency or _schedule_frequency_read(schedule_read),
        duration=medication.duration or "",
        instructions=medication.instructions or "",
        isImportant=medication.is_important,
        photoAvailable=bool(medication.photo_path),
        schedule=schedule_read,
    )


def _schedule_frequency_read(schedule: MedicationScheduleRead) -> str:
    if schedule.mode == MedicationScheduleMode.interval:
        return f"Cada {schedule.interval_hours} horas"
    return "Diario" if len(schedule.times) == 1 else f"{len(schedule.times)} veces al dia"


def _event_to_read(event: MedicationDoseEvent, medication_name: str) -> MedicationDoseEventRead:
    return MedicationDoseEventRead(
        id=event.id,
        medication_id=str(event.medication_id),
        medication_name=medication_name,
        client_event_id=event.client_event_id,
        scheduled_at=event.scheduled_at,
        sequence_number=event.sequence_number,
        status=event.status,
        acted_at=event.acted_at,
        snoozed_until=event.snoozed_until,
    )
