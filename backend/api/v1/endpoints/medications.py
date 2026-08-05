import logging
from datetime import datetime

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from backend.api.deps import get_current_patient
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.medication import (
    MedicationCreate,
    MedicationDoseEventCreate,
    MedicationDoseEventRead,
    MedicationListResponse,
    MedicationMarkResponse,
    MedicationRead,
    MedicationSyncConflictListResponse,
    MedicationSyncConflictResolve,
    MedicationSyncRequest,
    MedicationSyncResponse,
    MedicationUpdate,
)
from backend.services.medication_photo_service import (
    MAX_PHOTO_BYTES,
    MedicationPhotoConfigurationError,
    MedicationPhotoNotFoundError,
    delete_medication_photo,
    download_medication_photo,
    upload_medication_photo,
)
from backend.services.medication_service import (
    clear_user_dose_events,
    count_taken_medications,
    create_user_medication,
    delete_user_medication,
    get_user_medication_model,
    list_deleted_user_medications,
    list_dose_events,
    list_user_medication_sync_conflicts,
    list_user_medications,
    mark_user_medication_taken,
    medication_to_read,
    record_dose_event,
    resolve_user_medication_sync_conflict,
    restore_user_medication,
    sync_user_medication_actions,
    update_user_medication,
)

router = APIRouter(prefix="/medications", tags=["medications"])
logger = logging.getLogger(__name__)


@router.get("", response_model=MedicationListResponse)
def list_my_medications(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationListResponse:
    """Lista los medicamentos programados para el usuario autenticado."""
    return MedicationListResponse(items=list_user_medications(db, current_user.id))


@router.post("", response_model=MedicationRead, status_code=status.HTTP_201_CREATED)
def create_my_medication(
    payload: MedicationCreate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Crea un medicamento para el usuario autenticado."""
    try:
        return create_user_medication(db, current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc


@router.get("/dose-events", response_model=list[MedicationDoseEventRead])
def list_my_dose_events(
    start: datetime | None = None,
    end: datetime | None = None,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> list[MedicationDoseEventRead]:
    """Lista eventos de toma del paciente autenticado."""
    return list_dose_events(db, current_user.id, start=start, end=end)


@router.delete("/dose-events")
def clear_my_dose_events(
    before: datetime | None = None,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    """Elimina eventos de toma antiguos del paciente autenticado."""
    deleted = clear_user_dose_events(db, current_user.id, before=before)
    return {"deleted": deleted}


@router.post("/sync", response_model=MedicationSyncResponse)
def sync_my_medications(
    payload: MedicationSyncRequest,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationSyncResponse:
    """Procesa operaciones offline de medicamentos de forma idempotente."""
    return sync_user_medication_actions(db, current_user.id, current_user.id, payload)


@router.get("/sync-conflicts", response_model=MedicationSyncConflictListResponse)
def list_my_medication_sync_conflicts(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationSyncConflictListResponse:
    """Lista posibles duplicados pendientes de decision del paciente."""
    return MedicationSyncConflictListResponse(
        items=list_user_medication_sync_conflicts(db, current_user.id)
    )


@router.post("/sync-conflicts/{conflict_id}/resolve", response_model=MedicationRead | None)
def resolve_my_medication_sync_conflict(
    conflict_id: int,
    payload: MedicationSyncConflictResolve,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead | None:
    """Resuelve un posible duplicado detectado durante la sincronizacion."""
    try:
        result = resolve_user_medication_sync_conflict(
            db,
            current_user.id,
            conflict_id,
            payload.resolution,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    if result is None and payload.resolution.value != "reject":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conflicto no encontrado")
    return result


@router.get("/trash", response_model=MedicationListResponse)
def list_my_deleted_medications(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationListResponse:
    """Lista medicamentos eliminados logicamente del paciente autenticado."""
    return MedicationListResponse(
        items=list_deleted_user_medications(db, current_user.id)
    )


@router.post("/{medication_id}/restore", response_model=MedicationRead)
def restore_my_medication(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Restaura un medicamento eliminado logicamente."""
    medication = restore_user_medication(db, current_user.id, medication_id)
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado en la papelera",
        )
    return medication


@router.patch("/{medication_id}", response_model=MedicationRead)
def update_my_medication(
    medication_id: int,
    payload: MedicationUpdate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead:
    """Actualiza un medicamento del usuario autenticado."""
    try:
        medication = update_user_medication(db, current_user.id, medication_id, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    if medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicamento no encontrado")
    return medication


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_medication(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> None:
    """Elimina logicamente un medicamento del usuario autenticado."""
    medication = get_user_medication_model(db, current_user.id, medication_id)
    if medication is not None and medication.photo_path:
        try:
            delete_medication_photo(medication.photo_path)
        except Exception:
            logger.exception(
                "No se pudo borrar la foto del medicamento %s",
                medication_id,
            )
    removed = delete_user_medication(db, current_user.id, medication_id)
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medicamento no encontrado")


@router.post("/{medication_id}/photo", response_model=MedicationRead)
def upload_my_medication_photo(
    medication_id: int,
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationRead:
    medication = get_user_medication_model(db, current_user.id, medication_id)
    if medication is None:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    previous_path = medication.photo_path
    try:
        new_path = upload_medication_photo(
            user_id=current_user.id,
            medication_id=medication.id,
            content=photo.file.read(MAX_PHOTO_BYTES + 1),
            content_type=photo.content_type or "",
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except MedicationPhotoConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    medication.photo_path = new_path
    db.add(medication)
    db.commit()
    try:
        delete_medication_photo(previous_path)
    except Exception:
        logger.exception(
            "No se pudo borrar la foto anterior del medicamento %s",
            medication_id,
        )
    return medication_to_read(db, current_user.id, medication.id)


@router.get("/{medication_id}/photo")
def download_my_medication_photo(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> Response:
    medication = get_user_medication_model(db, current_user.id, medication_id)
    if medication is None or not medication.photo_path:
        raise HTTPException(status_code=404, detail="Foto no encontrada")
    try:
        content = download_medication_photo(medication.photo_path)
    except MedicationPhotoConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except MedicationPhotoNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    path = medication.photo_path.lower()
    media_type = "image/png" if path.endswith(".png") else "image/webp" if path.endswith(".webp") else "image/jpeg"
    return Response(content=content, media_type=media_type)


@router.delete("/{medication_id}/photo", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_medication_photo(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> None:
    medication = get_user_medication_model(db, current_user.id, medication_id)
    if medication is None:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")
    try:
        delete_medication_photo(medication.photo_path)
    except MedicationPhotoConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    medication.photo_path = None
    db.add(medication)
    db.commit()


@router.post("/{medication_id}/take", response_model=MedicationMarkResponse)
def mark_my_medication(
    medication_id: int,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationMarkResponse:
    """Marca un medicamento como tomado para el usuario autenticado."""
    medication = mark_user_medication_taken(db, current_user.id, medication_id)
    if medication is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )

    taken_count, total_count = count_taken_medications(db, current_user.id)
    return MedicationMarkResponse(
        medication=medication,
        taken_count=taken_count,
        total_count=total_count,
    )


@router.post("/{medication_id}/dose-events", response_model=MedicationDoseEventRead)
def record_my_dose_event(
    medication_id: int,
    payload: MedicationDoseEventCreate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> MedicationDoseEventRead:
    """Registra una toma de forma idempotente para sincronizacion offline."""
    try:
        event = record_dose_event(db, current_user.id, medication_id, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Medicamento no encontrado",
        )
    return event
