from datetime import datetime

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
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
    MedicationUpdate,
)
from backend.services.medication_service import (
    count_taken_medications,
    create_user_medication,
    delete_user_medication,
    get_user_medication_model,
    list_dose_events,
    list_user_medications,
    mark_user_medication_taken,
    medication_to_read,
    record_dose_event,
    update_user_medication,
)
from backend.services.medication_photo_service import (
    MAX_PHOTO_BYTES,
    MedicationPhotoConfigurationError,
    delete_medication_photo,
    download_medication_photo,
    upload_medication_photo,
)


router = APIRouter(prefix="/medications", tags=["medications"])


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
            pass
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
        pass
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
