import unicodedata
from datetime import UTC, datetime, time
from decimal import Decimal
from difflib import SequenceMatcher

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from backend.models.medication import Medication
from backend.models.medication_dose_event import MedicationDoseEvent
from backend.models.medication_schedule import (
    MedicationSchedule,
    MedicationScheduleTime,
)
from backend.models.medication_sync_conflict import MedicationSyncConflict
from backend.models.medication_sync_operation import MedicationSyncOperation
from backend.schemas.medication import (
    MedicationCreate,
    MedicationDoseEventCreate,
    MedicationDoseEventRead,
    MedicationRead,
    MedicationScheduleMode,
    MedicationSchedulePayload,
    MedicationScheduleRead,
    MedicationSyncAction,
    MedicationSyncActionResult,
    MedicationSyncConflictRead,
    MedicationSyncConflictResolution,
    MedicationSyncOperationType,
    MedicationSyncRequest,
    MedicationSyncResponse,
    MedicationSyncResultStatus,
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


def create_user_medication(
    db: Session,
    user_id: int,
    payload: MedicationCreate,
    *,
    actor_user_id: int | None = None,
    client_medication_id: str | None = None,
) -> MedicationRead:
    dose_label = _dose_label(payload.doseAmount, payload.doseUnit, payload.dose)
    schedule_payload = payload.schedule or _legacy_schedule(payload.time)
    actor_id = actor_user_id or user_id
    medication = Medication(
        user_id=user_id,
        created_by_user_id=actor_id,
        last_modified_by_user_id=actor_id,
        name=payload.name.strip(),
        client_medication_id=client_medication_id or payload.clientMedicationId,
        sync_fingerprint=_fingerprint_from_payload(payload),
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
    *,
    actor_user_id: int | None = None,
) -> MedicationRead | None:
    medication = _get_user_medication(db, user_id, medication_id)
    if medication is None:
        return None

    if payload.name is not None:
        medication.name = payload.name.strip()
    if payload.clientMedicationId is not None:
        medication.client_medication_id = payload.clientMedicationId
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

    medication.last_modified_by_user_id = actor_user_id or user_id
    medication.sync_fingerprint = _fingerprint_from_medication(medication)
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


def clear_user_dose_events(
    db: Session,
    user_id: int,
    *,
    before: datetime | None = None,
) -> int:
    medication_ids = select(Medication.id).where(Medication.user_id == user_id)
    statement = select(MedicationDoseEvent).where(
        MedicationDoseEvent.medication_id.in_(medication_ids),
    )
    if before is not None:
        statement = statement.where(MedicationDoseEvent.scheduled_at < before)
    events = list(db.scalars(statement))
    for event in events:
        db.delete(event)
    db.commit()
    return len(events)


def count_taken_medications(db: Session, user_id: int) -> tuple[int, int]:
    medications = list_user_medications(db, user_id)
    return sum(1 for medication in medications if medication.taken), len(medications)


def sync_user_medication_actions(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    payload: MedicationSyncRequest,
) -> MedicationSyncResponse:
    results = [
        _sync_user_medication_action(db, patient_id, actor_user_id, action)
        for action in payload.actions
    ]
    return MedicationSyncResponse(
        results=results,
        items=list_user_medications(db, patient_id),
        pending_conflicts=list_user_medication_sync_conflicts(db, patient_id),
    )


def list_user_medication_sync_conflicts(
    db: Session,
    patient_id: int,
) -> list[MedicationSyncConflictRead]:
    conflicts = db.scalars(
        select(MedicationSyncConflict)
        .where(
            MedicationSyncConflict.patient_user_id == patient_id,
            MedicationSyncConflict.status == "pending",
        )
        .order_by(MedicationSyncConflict.created_at.desc())
    )
    return [_conflict_to_read(db, conflict) for conflict in conflicts]


def resolve_user_medication_sync_conflict(
    db: Session,
    patient_id: int,
    conflict_id: int,
    resolution: MedicationSyncConflictResolution,
) -> MedicationRead | None:
    conflict = db.scalar(
        select(MedicationSyncConflict).where(
            MedicationSyncConflict.id == conflict_id,
            MedicationSyncConflict.patient_user_id == patient_id,
            MedicationSyncConflict.status == "pending",
        )
    )
    if conflict is None:
        return None

    medication: MedicationRead | None = None
    if resolution == MedicationSyncConflictResolution.merge:
        if conflict.candidate_medication_id is None:
            raise ValueError("El conflicto no tiene candidato para fusionar")
        update = MedicationUpdate.model_validate(conflict.incoming_payload)
        medication = update_user_medication(
            db,
            patient_id,
            conflict.candidate_medication_id,
            update,
            actor_user_id=patient_id,
        )
        conflict.resolved_medication_id = int(medication.id) if medication else None
        conflict.status = "resolved"
    elif resolution == MedicationSyncConflictResolution.create_separate:
        create = MedicationCreate.model_validate(conflict.incoming_payload)
        medication = create_user_medication(
            db,
            patient_id,
            create,
            actor_user_id=patient_id,
            client_medication_id=conflict.incoming_client_medication_id,
        )
        conflict.resolved_medication_id = int(medication.id)
        conflict.status = "resolved"
    else:
        conflict.status = "rejected"
    conflict.resolution = resolution.value
    db.add(conflict)
    db.commit()
    return medication


def get_user_medication_model(
    db: Session,
    user_id: int,
    medication_id: int,
) -> Medication | None:
    return _get_user_medication(db, user_id, medication_id)


def medication_to_read(db: Session, user_id: int, medication_id: int) -> MedicationRead:
    return _read_user_medication(db, user_id, medication_id)


def _sync_user_medication_action(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
) -> MedicationSyncActionResult:
    existing_operation = db.scalar(
        select(MedicationSyncOperation).where(
            MedicationSyncOperation.patient_user_id == patient_id,
            MedicationSyncOperation.client_operation_id == action.client_operation_id,
        )
    )
    if existing_operation is not None:
        return _operation_to_result(db, patient_id, existing_operation)

    try:
        if action.operation_type == MedicationSyncOperationType.create_medication:
            return _sync_create_medication(db, patient_id, actor_user_id, action)
        if action.operation_type == MedicationSyncOperationType.update_medication:
            return _sync_update_medication(db, patient_id, actor_user_id, action)
        if action.operation_type == MedicationSyncOperationType.delete_medication:
            return _sync_delete_medication(db, patient_id, actor_user_id, action)
        if action.operation_type == MedicationSyncOperationType.dose_event:
            return _sync_dose_event(db, patient_id, actor_user_id, action)
    except ValueError as exc:
        return MedicationSyncActionResult(
            client_operation_id=action.client_operation_id,
            client_medication_id=action.client_medication_id,
            status=MedicationSyncResultStatus.failed,
            message=str(exc),
        )
    return MedicationSyncActionResult(
        client_operation_id=action.client_operation_id,
        client_medication_id=action.client_medication_id,
        status=MedicationSyncResultStatus.failed,
        message="Operacion no soportada",
    )


def _sync_create_medication(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
) -> MedicationSyncActionResult:
    create = MedicationCreate.model_validate(
        {**action.payload, "clientMedicationId": action.client_medication_id or action.payload.get("clientMedicationId")}
    )
    candidate, score, mode = _find_duplicate_candidate(db, patient_id, create)
    if mode == "merge" and candidate is not None:
        update = MedicationUpdate.model_validate(create.model_dump(exclude_none=True))
        medication = update_user_medication(
            db,
            patient_id,
            candidate.id,
            update,
            actor_user_id=actor_user_id,
        )
        operation = _record_sync_operation(
            db,
            patient_id,
            actor_user_id,
            action,
            MedicationSyncResultStatus.synced,
            medication_id=int(medication.id) if medication else None,
        )
        return _operation_to_result(db, patient_id, operation)

    if mode == "conflict":
        conflict = _create_or_get_conflict(
            db,
            patient_id,
            actor_user_id,
            action,
            create,
            candidate,
            score,
        )
        operation = _record_sync_operation(
            db,
            patient_id,
            actor_user_id,
            action,
            MedicationSyncResultStatus.conflict,
            conflict_id=conflict.id,
        )
        return _operation_to_result(db, patient_id, operation)

    medication = create_user_medication(
        db,
        patient_id,
        create,
        actor_user_id=actor_user_id,
        client_medication_id=action.client_medication_id,
    )
    operation = _record_sync_operation(
        db,
        patient_id,
        actor_user_id,
        action,
        MedicationSyncResultStatus.synced,
        medication_id=int(medication.id),
    )
    return _operation_to_result(db, patient_id, operation)


def _sync_update_medication(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
) -> MedicationSyncActionResult:
    medication_id = _resolve_action_medication_id(db, patient_id, action)
    if medication_id is None:
        return _sync_create_medication(db, patient_id, actor_user_id, action)
    update = MedicationUpdate.model_validate(action.payload)
    medication = update_user_medication(
        db,
        patient_id,
        medication_id,
        update,
        actor_user_id=actor_user_id,
    )
    operation = _record_sync_operation(
        db,
        patient_id,
        actor_user_id,
        action,
        MedicationSyncResultStatus.synced,
        medication_id=int(medication.id) if medication else None,
    )
    return _operation_to_result(db, patient_id, operation)


def _sync_delete_medication(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
) -> MedicationSyncActionResult:
    medication_id = _resolve_action_medication_id(db, patient_id, action)
    if medication_id is not None:
        delete_user_medication(db, patient_id, medication_id)
    operation = _record_sync_operation(
        db,
        patient_id,
        actor_user_id,
        action,
        MedicationSyncResultStatus.synced,
        medication_id=medication_id,
    )
    return _operation_to_result(db, patient_id, operation)


def _sync_dose_event(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
) -> MedicationSyncActionResult:
    medication_id = _resolve_action_medication_id(db, patient_id, action)
    if medication_id is None:
        raise ValueError("Medicamento no encontrado para la toma")
    event_payload = MedicationDoseEventCreate.model_validate(action.payload)
    record_dose_event(db, patient_id, medication_id, event_payload)
    operation = _record_sync_operation(
        db,
        patient_id,
        actor_user_id,
        action,
        MedicationSyncResultStatus.synced,
        medication_id=medication_id,
    )
    return _operation_to_result(db, patient_id, operation)


def _record_sync_operation(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
    status: MedicationSyncResultStatus,
    *,
    medication_id: int | None = None,
    conflict_id: int | None = None,
) -> MedicationSyncOperation:
    operation = MedicationSyncOperation(
        patient_user_id=patient_id,
        actor_user_id=actor_user_id,
        client_operation_id=action.client_operation_id,
        client_medication_id=action.client_medication_id,
        operation_type=action.operation_type.value,
        result_status=status.value,
        medication_id=medication_id,
        conflict_id=conflict_id,
    )
    db.add(operation)
    db.commit()
    db.refresh(operation)
    return operation


def _operation_to_result(
    db: Session,
    patient_id: int,
    operation: MedicationSyncOperation,
) -> MedicationSyncActionResult:
    medication = None
    conflict = None
    if operation.medication_id is not None:
        model = _get_user_medication(db, patient_id, operation.medication_id)
        medication = _to_read(model) if model is not None else None
    if operation.conflict_id is not None:
        conflict_model = db.get(MedicationSyncConflict, operation.conflict_id)
        if conflict_model is not None:
            conflict = _conflict_to_read(db, conflict_model)
    return MedicationSyncActionResult(
        client_operation_id=operation.client_operation_id,
        client_medication_id=operation.client_medication_id,
        status=MedicationSyncResultStatus(operation.result_status),
        medication=medication,
        conflict=conflict,
    )


def _resolve_action_medication_id(
    db: Session,
    patient_id: int,
    action: MedicationSyncAction,
) -> int | None:
    if action.server_medication_id and action.server_medication_id.isdigit():
        medication_id = int(action.server_medication_id)
        if _get_user_medication(db, patient_id, medication_id) is not None:
            return medication_id
    if action.client_medication_id:
        medication = db.scalar(
            select(Medication).where(
                Medication.user_id == patient_id,
                Medication.client_medication_id == action.client_medication_id,
            )
        )
        if medication is not None:
            return medication.id
    return None


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


def _find_duplicate_candidate(
    db: Session,
    patient_id: int,
    payload: MedicationCreate,
) -> tuple[Medication | None, float, str | None]:
    incoming_name = _normalize_text(payload.name)
    incoming_fingerprint = _fingerprint_from_payload(payload)
    best: Medication | None = None
    best_score = 0.0

    medications = db.scalars(
        select(Medication)
        .options(selectinload(Medication.schedule).selectinload(MedicationSchedule.times))
        .where(Medication.user_id == patient_id, Medication.is_active.is_(True))
    )
    for medication in medications:
        if medication.sync_fingerprint and medication.sync_fingerprint == incoming_fingerprint:
            return medication, 1.0, "merge"
        name_score = SequenceMatcher(None, incoming_name, _normalize_text(medication.name)).ratio()
        dose_score = 1.0 if _same_dose(payload, medication) else 0.0
        schedule_score = 1.0 if _schedule_overlaps(payload, medication) else 0.0
        score = (name_score * 0.65) + (dose_score * 0.2) + (schedule_score * 0.15)
        if score > best_score:
            best = medication
            best_score = score

    if best is None:
        return None, 0.0, None
    if best_score >= 0.93 and _same_dose(payload, best):
        return best, best_score, "merge"
    if best_score >= 0.78:
        return best, best_score, "conflict"
    return None, best_score, None


def _create_or_get_conflict(
    db: Session,
    patient_id: int,
    actor_user_id: int,
    action: MedicationSyncAction,
    payload: MedicationCreate,
    candidate: Medication | None,
    score: float,
) -> MedicationSyncConflict:
    if action.client_medication_id:
        existing = db.scalar(
            select(MedicationSyncConflict).where(
                MedicationSyncConflict.patient_user_id == patient_id,
                MedicationSyncConflict.incoming_client_medication_id == action.client_medication_id,
                MedicationSyncConflict.status == "pending",
            )
        )
        if existing is not None:
            return existing
    conflict = MedicationSyncConflict(
        patient_user_id=patient_id,
        actor_user_id=actor_user_id,
        candidate_medication_id=candidate.id if candidate else None,
        incoming_client_medication_id=action.client_medication_id,
        incoming_payload=payload.model_dump(mode="json", exclude_none=True),
        similarity_score=round(score, 4),
    )
    db.add(conflict)
    db.commit()
    db.refresh(conflict)
    return conflict


def _conflict_to_read(
    db: Session,
    conflict: MedicationSyncConflict,
) -> MedicationSyncConflictRead:
    candidate = (
        db.get(Medication, conflict.candidate_medication_id)
        if conflict.candidate_medication_id is not None
        else None
    )
    incoming_name = str(conflict.incoming_payload.get("name") or "Medicamento")
    return MedicationSyncConflictRead(
        id=conflict.id,
        candidateMedicationId=str(candidate.id) if candidate else None,
        incomingClientMedicationId=conflict.incoming_client_medication_id,
        incomingMedicationName=incoming_name,
        candidateMedicationName=candidate.name if candidate else None,
        similarityScore=conflict.similarity_score,
        status=conflict.status,
        createdAt=conflict.created_at,
    )


def _fingerprint_from_payload(payload: MedicationCreate) -> str:
    schedule = payload.schedule or _legacy_schedule(payload.time)
    dose = _dose_label(payload.doseAmount, payload.doseUnit, payload.dose)
    return "|".join(
        [
            _normalize_text(payload.name),
            _normalize_text(dose),
            schedule.mode.value,
            str(schedule.interval_hours or ""),
            ",".join(sorted(schedule.times)),
            ",".join(str(day) for day in sorted(schedule.weekdays)),
        ]
    )


def _fingerprint_from_medication(medication: Medication) -> str:
    times = [_format_time(medication.schedule_time)]
    mode = MedicationScheduleMode.fixed_times.value
    interval = ""
    weekdays = "1,2,3,4,5,6,7"
    if medication.schedule is not None:
        mode = medication.schedule.mode
        interval = str(medication.schedule.interval_hours or "")
        times = [_format_time(item.time_of_day) for item in medication.schedule.times]
        weekdays = medication.schedule.weekdays
    return "|".join(
        [
            _normalize_text(medication.name),
            _normalize_text(medication.dose),
            mode,
            interval,
            ",".join(sorted(times)),
            weekdays,
        ]
    )


def _same_dose(payload: MedicationCreate, medication: Medication) -> bool:
    incoming = _normalize_text(_dose_label(payload.doseAmount, payload.doseUnit, payload.dose))
    existing = _normalize_text(medication.dose)
    return incoming == existing


def _schedule_overlaps(payload: MedicationCreate, medication: Medication) -> bool:
    schedule = payload.schedule or _legacy_schedule(payload.time)
    incoming_times = set(schedule.times)
    existing_times = {_format_time(medication.schedule_time)}
    if medication.schedule is not None:
        existing_times = {_format_time(item.time_of_day) for item in medication.schedule.times}
    return bool(incoming_times & existing_times)


def _normalize_text(value: str | None) -> str:
    normalized = unicodedata.normalize("NFKD", value or "")
    ascii_only = "".join(char for char in normalized if not unicodedata.combining(char))
    return "".join(char for char in ascii_only.lower() if char.isalnum())


def _legacy_schedule(value: str | None) -> MedicationSchedulePayload:
    if not value:
        raise ValueError("Selecciona un horario")
    return MedicationSchedulePayload(
        mode=MedicationScheduleMode.fixed_times,
        times=[value],
        weekdays=[1, 2, 3, 4, 5, 6, 7],
        start_date=datetime.now(UTC).date(),
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
        clientMedicationId=medication.client_medication_id,
        syncFingerprint=medication.sync_fingerprint,
        updatedAt=medication.updated_at,
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
