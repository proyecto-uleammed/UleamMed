from datetime import time

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.models.medication import Medication
from backend.schemas.medication import MedicationCreate, MedicationRead, MedicationUpdate


def listar_medicamentos_usuario(db: Session, user_id: int) -> list[MedicationRead]:
    """Devuelve medicamentos reales del usuario autenticado."""
    statement = (
        select(Medication)
        .where(Medication.user_id == user_id, Medication.is_active.is_(True))
        .order_by(Medication.schedule_time.asc().nulls_last(), Medication.name.asc())
    )
    return [_to_read(medicamento) for medicamento in db.scalars(statement)]


def crear_medicamento_usuario(db: Session, user_id: int, datos: MedicationCreate) -> MedicationRead:
    """Crea un medicamento para el usuario autenticado."""
    medicamento = Medication(
        user_id=user_id,
        name=datos.name.strip(),
        dose=datos.dose.strip(),
        frequency=(datos.frequency or "Diario").strip(),
        duration=(datos.duration or "").strip(),
        schedule_time=_parse_time(datos.time),
        instructions=(datos.instructions or "").strip(),
        is_important=datos.isImportant,
    )
    db.add(medicamento)
    db.commit()
    db.refresh(medicamento)
    return _to_read(medicamento)


def actualizar_medicamento_usuario(
    db: Session,
    user_id: int,
    medication_id: int,
    datos: MedicationUpdate,
) -> MedicationRead | None:
    """Actualiza un medicamento del usuario autenticado."""
    medicamento = _get_user_medication(db, user_id, medication_id)
    if medicamento is None:
        return None

    if datos.name is not None:
        medicamento.name = datos.name.strip()
    if datos.dose is not None:
        medicamento.dose = datos.dose.strip()
    if datos.frequency is not None:
        medicamento.frequency = datos.frequency.strip()
    if datos.duration is not None:
        medicamento.duration = datos.duration.strip()
    if datos.time is not None:
        medicamento.schedule_time = _parse_time(datos.time)
    if datos.instructions is not None:
        medicamento.instructions = datos.instructions.strip()
    if datos.isImportant is not None:
        medicamento.is_important = datos.isImportant
    if datos.taken is not None:
        medicamento.taken = datos.taken

    db.add(medicamento)
    db.commit()
    db.refresh(medicamento)
    return _to_read(medicamento)


def eliminar_medicamento_usuario(db: Session, user_id: int, medication_id: int) -> bool:
    """Desactiva un medicamento del usuario autenticado."""
    medicamento = _get_user_medication(db, user_id, medication_id)
    if medicamento is None:
        return False

    medicamento.is_active = False
    db.add(medicamento)
    db.commit()
    return True


def marcar_medicamento_tomado(db: Session, user_id: int, medication_id: int) -> MedicationRead | None:
    """Marca como tomado un medicamento del usuario."""
    medicamento = _get_user_medication(db, user_id, medication_id)
    if medicamento is None:
        return None

    medicamento.taken = True
    db.add(medicamento)
    db.commit()
    db.refresh(medicamento)
    return _to_read(medicamento)


def contar_medicamentos_tomados(db: Session, user_id: int) -> tuple[int, int]:
    """Cuenta medicamentos tomados y total programado."""
    medicamentos = listar_medicamentos_usuario(db, user_id)
    return sum(1 for medicamento in medicamentos if medicamento.taken), len(medicamentos)


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


def _to_read(medicamento: Medication) -> MedicationRead:
    return MedicationRead(
        id=str(medicamento.id),
        name=medicamento.name,
        dose=medicamento.dose,
        time=_format_time(medicamento.schedule_time),
        taken=medicamento.taken,
        frequency=medicamento.frequency or "Diario",
        duration=medicamento.duration or "",
        instructions=medicamento.instructions or "",
        isImportant=medicamento.is_important,
    )
