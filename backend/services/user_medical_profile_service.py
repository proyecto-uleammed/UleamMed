from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.models.emergency_contact import EmergencyContact
from backend.models.user_medical_profile import UserMedicalProfile
from backend.schemas.user_medical_profile import (
    UserMedicalProfileRead,
    UserMedicalProfileUpdate,
)


def get_user_medical_profile(db: Session, user_id: int) -> UserMedicalProfileRead:
    profile = _get_profile_row(db, user_id)
    if profile is None:
        return UserMedicalProfileRead()
    return _to_read(profile)


def upsert_user_medical_profile(
    db: Session,
    user_id: int,
    payload: UserMedicalProfileUpdate,
) -> UserMedicalProfileRead:
    profile = _get_profile_row(db, user_id)
    if profile is None:
        profile = UserMedicalProfile(user_id=user_id)
        db.add(profile)

    profile.birth_date = payload.birthDate.strip()
    profile.blood_type = payload.bloodType.strip().upper()
    profile.conditions = payload.conditions.strip()
    profile.allergies = payload.allergies.strip()
    profile.important_notes = payload.importantNotes.strip()
    profile.emergency_contact_name = payload.emergencyContactName.strip()
    profile.emergency_contact_phone = payload.emergencyContactPhone.strip()
    profile.share_with_caregivers = payload.shareWithCaregivers
    _sync_profile_emergency_contact(db, user_id, profile)

    db.commit()
    db.refresh(profile)
    return _to_read(profile)


def patient_shares_health_data(db: Session, patient_id: int) -> bool:
    profile = _get_profile_row(db, patient_id)
    return profile is not None and profile.share_with_caregivers


def _get_profile_row(db: Session, user_id: int) -> UserMedicalProfile | None:
    return db.scalar(select(UserMedicalProfile).where(UserMedicalProfile.user_id == user_id))


def _sync_profile_emergency_contact(
    db: Session,
    user_id: int,
    profile: UserMedicalProfile,
) -> None:
    name = profile.emergency_contact_name.strip()
    phone = profile.emergency_contact_phone.strip()
    if not name or not phone:
        return

    existing = db.scalar(
        select(EmergencyContact).where(
            EmergencyContact.user_id == user_id,
            EmergencyContact.is_active.is_(True),
            EmergencyContact.phone == phone,
        )
    )
    if existing is None:
        existing = db.scalar(
            select(EmergencyContact).where(
                EmergencyContact.user_id == user_id,
                EmergencyContact.is_active.is_(True),
                EmergencyContact.relationship == "Perfil medico",
            )
        )
    if existing is None:
        existing = EmergencyContact(user_id=user_id)
        db.add(existing)

    db.query(EmergencyContact).filter(
        EmergencyContact.user_id == user_id,
        EmergencyContact.is_active.is_(True),
    ).update({EmergencyContact.is_primary: False})
    existing.name = name
    existing.phone = phone
    existing.relationship = "Perfil medico"
    existing.is_primary = True
    existing.is_active = True


def _to_read(profile: UserMedicalProfile) -> UserMedicalProfileRead:
    return UserMedicalProfileRead(
        birthDate=profile.birth_date,
        bloodType=profile.blood_type,
        conditions=profile.conditions,
        allergies=profile.allergies,
        importantNotes=profile.important_notes,
        emergencyContactName=profile.emergency_contact_name,
        emergencyContactPhone=profile.emergency_contact_phone,
        shareWithCaregivers=profile.share_with_caregivers,
    )
