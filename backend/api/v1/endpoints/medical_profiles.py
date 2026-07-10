from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.api.deps import get_current_patient
from backend.core.database import get_db
from backend.models.user import User
from backend.schemas.user_medical_profile import (
    UserMedicalProfileRead,
    UserMedicalProfileUpdate,
)
from backend.services.user_medical_profile_service import (
    get_user_medical_profile,
    upsert_user_medical_profile,
)

router = APIRouter(prefix="/medical-profile", tags=["medical-profile"])


@router.get("", response_model=UserMedicalProfileRead)
def read_my_medical_profile(
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> UserMedicalProfileRead:
    """Obtiene el perfil medico del paciente autenticado."""
    return get_user_medical_profile(db, current_user.id)


@router.put("", response_model=UserMedicalProfileRead)
def save_my_medical_profile(
    payload: UserMedicalProfileUpdate,
    current_user: User = Depends(get_current_patient),
    db: Session = Depends(get_db),
) -> UserMedicalProfileRead:
    """Guarda el perfil medico del paciente autenticado."""
    try:
        return upsert_user_medical_profile(db, current_user.id, payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
