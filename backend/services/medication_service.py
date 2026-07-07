from datetime import time

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.models.medication import Medication
from backend.schemas.medication import MedicationCreate, MedicationRead, MedicationUpdate


def list_user_medications(db: Session, user_id: int) -> list[MedicationRead]:
    """Devuelve medicamentos reales del usuario autenticado."""
    statement = (
        select(Medication)
        .where(Medication.user_id == user_id, Medication.is_active.is_(True))
        .order_by(Medication.schedule_time.asc().nulls_last(), Medication.name.asc())
    )
    return [_to_read(medication) for medication in db.scalars(statement)]


def create_user_medication(db: Session, user_id: int, payload: MedicationCreate) -> MedicationRead:
    """Crea un medicamento para el usuario autenticado."""
    medication = Medication(
        user_id=user_id,
        name=payload.name.strip(),
        dose=payload.dose.strip(),
        frequency=(payload.frequency or "Diario").strip(),
        duration=(payload.duration or "").strip(),
        schedule_time=_parse_time(payload.time),
        instructions=(payload.instructions or "").strip(),
        is_important=payload.isImportant,
    )
    db.add(medication)
    db.commit()
    db.refresh(medication)
    return _to_read(medication)


def update_user_medication(
    db: Session,
    user_id: int,
    medication_id: int,
    payload: MedicationUpdate,
) -> MedicationRead | None:
    """Actualiza un medicamento del usuario autenticado."""
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return None

    if payload.name is not None:
        medication.name = payload.name.strip()
    if payload.dose is not None:
        medication.dose = payload.dose.strip()
    if payload.frequency is not None:
        medication.frequency = payload.frequency.strip()
    if payload.duration is not None:
        medication.duration = payload.duration.strip()
    if payload.time is not None:
        medication.schedule_time = _parse_time(payload.time)
    if payload.instructions is not None:
        medication.instructions = payload.instructions.strip()
    if payload.isImportant is not None:
        medication.is_important = payload.isImportant
    if payload.taken is not None:
        medication.taken = payload.taken

    db.add(medication)
    db.commit()
    db.refresh(medication)
    return _to_read(medication)


def delete_user_medication(db: Session, user_id: int, medication_id: int) -> bool:
    """Desactiva un medicamento del usuario autenticado."""
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return False

    medication.is_active = False
    db.add(medication)
    db.commit()
    return True


def mark_user_medication_taken(db: Session, user_id: int, medication_id: int) -> MedicationRead | None:
    """Marca como tomado un medicamento del usuario."""
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return None

    medication.taken = True
    db.add(medication)
    db.commit()
    db.refresh(medication)
    return _to_read(medication)


def count_taken_medications(db: Session, user_id: int) -> tuple[int, int]:
    """Cuenta medicamentos tomados y total programado."""
    medications = list_user_medications(db, user_id)
    return sum(1 for medication in medications if medication.taken), len(medications)


def _get_user_medication(db: Session, user_id: int, medication_id: int) -> Medication | None:
    return db.scalar(
        select(Medication).where(
            Medication.id == medication_id,
            Medication.user_id == user_id,
            Medication.is_active.is_(True),
        ),
    )


def _parse_time(value: str) -> time:
    try:
        return time.fromisoformat(value.strip())
    except ValueError as exc:
        raise ValueError("Formato de hora invalido. Usa HH:MM.") from exc


def _format_time(value: time | None) -> str:
    return value.strftime("%H:%M") if value is not None else ""


def _to_read(medication: Medication) -> MedicationRead:
    return MedicationRead(
        id=str(medication.id),
        name=medication.name,
        dose=medication.dose,
        time=_format_time(medication.schedule_time),
        taken=medication.taken,
        frequency=medication.frequency or "Diario",
        duration=medication.duration or "",
        instructions=medication.instructions or "",
        isImportant=medication.is_important,
    )
