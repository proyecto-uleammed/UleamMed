from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.models.health_entry import HealthEntry
from backend.schemas.health_entry import (
    HealthEntryCreate,
    HealthEntryKind,
    HealthEntryRead,
    HealthEntrySeverity,
    HealthEntryUpdate,
)


def list_user_health_entries(db: Session, user_id: int) -> list[HealthEntryRead]:
    statement = (
        select(HealthEntry)
        .where(HealthEntry.user_id == user_id, HealthEntry.is_active.is_(True))
        .order_by(HealthEntry.kind.asc(), HealthEntry.name.asc())
    )
    return [_to_read(entry) for entry in db.scalars(statement)]


def create_user_health_entry(
    db: Session,
    user_id: int,
    payload: HealthEntryCreate,
) -> HealthEntryRead:
    entry = HealthEntry(
        user_id=user_id,
        kind=payload.kind.value,
        name=payload.name.strip(),
        severity=payload.severity.value,
        detail=payload.detail.strip(),
        date=payload.date.strip(),
        active=payload.active if payload.kind == HealthEntryKind.condition else True,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return _to_read(entry)


def update_user_health_entry(
    db: Session,
    user_id: int,
    entry_id: int,
    payload: HealthEntryUpdate,
) -> HealthEntryRead | None:
    entry = _get_user_health_entry(db, user_id, entry_id)
    if entry is None:
        return None

    if payload.kind is not None:
        entry.kind = payload.kind.value
    if payload.name is not None:
        entry.name = payload.name.strip()
    if payload.severity is not None:
        entry.severity = payload.severity.value
    if payload.detail is not None:
        entry.detail = payload.detail.strip()
    if payload.date is not None:
        entry.date = payload.date.strip()
    if payload.active is not None and entry.kind == HealthEntryKind.condition.value:
        entry.active = payload.active

    db.commit()
    db.refresh(entry)
    return _to_read(entry)


def delete_user_health_entry(db: Session, user_id: int, entry_id: int) -> bool:
    entry = _get_user_health_entry(db, user_id, entry_id)
    if entry is None:
        return False
    entry.is_active = False
    db.commit()
    return True


def _get_user_health_entry(
    db: Session,
    user_id: int,
    entry_id: int,
) -> HealthEntry | None:
    return db.scalar(
        select(HealthEntry).where(
            HealthEntry.id == entry_id,
            HealthEntry.user_id == user_id,
            HealthEntry.is_active.is_(True),
        )
    )


def _to_read(entry: HealthEntry) -> HealthEntryRead:
    try:
        kind = HealthEntryKind(entry.kind)
    except ValueError:
        kind = HealthEntryKind.condition
    try:
        severity = HealthEntrySeverity(entry.severity)
    except ValueError:
        severity = HealthEntrySeverity.low
    return HealthEntryRead(
        id=str(entry.id),
        kind=kind,
        name=entry.name,
        severity=severity,
        detail=entry.detail,
        date=entry.date,
        active=entry.active,
    )
