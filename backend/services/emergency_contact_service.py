from sqlalchemy import select, update
from sqlalchemy.orm import Session

from backend.models.emergency_contact import EmergencyContact
from backend.models.user_medical_profile import UserMedicalProfile
from backend.schemas.emergency_contact import (
    EmergencyContactCreate,
    EmergencyContactRead,
    EmergencyContactUpdate,
)


def list_user_emergency_contacts(db: Session, user_id: int) -> list[EmergencyContactRead]:
    statement = (
        select(EmergencyContact)
        .where(EmergencyContact.user_id == user_id, EmergencyContact.is_active.is_(True))
        .order_by(EmergencyContact.is_primary.desc(), EmergencyContact.name.asc())
    )
    return [_to_read(contact) for contact in db.scalars(statement)]


def create_user_emergency_contact(
    db: Session,
    user_id: int,
    payload: EmergencyContactCreate,
) -> EmergencyContactRead:
    existing = db.scalar(
        select(EmergencyContact).where(
            EmergencyContact.user_id == user_id,
            EmergencyContact.is_active.is_(True),
            EmergencyContact.phone == payload.phone,
        )
    )
    if payload.isPrimary:
        _clear_primary_flag(db, user_id)
    contact = existing or EmergencyContact(user_id=user_id)
    contact.name = payload.name.strip()
    contact.phone = payload.phone.strip()
    contact.relationship = payload.relationship.strip()
    contact.is_primary = payload.isPrimary
    contact.is_active = True
    if existing is None:
        db.add(contact)
    db.commit()
    db.refresh(contact)
    return _to_read(contact)


def update_user_emergency_contact(
    db: Session,
    user_id: int,
    contact_id: int,
    payload: EmergencyContactUpdate,
) -> EmergencyContactRead | None:
    contact = _get_user_contact(db, user_id, contact_id)
    if contact is None:
        return None
    if payload.isPrimary is True:
        _clear_primary_flag(db, user_id)
    if payload.name is not None:
        contact.name = payload.name.strip()
    if payload.phone is not None:
        contact.phone = payload.phone.strip()
    if payload.relationship is not None:
        contact.relationship = payload.relationship.strip()
    if payload.isPrimary is not None:
        contact.is_primary = payload.isPrimary
    db.commit()
    db.refresh(contact)
    return _to_read(contact)


def delete_user_emergency_contact(db: Session, user_id: int, contact_id: int) -> bool:
    contact = _get_user_contact(db, user_id, contact_id)
    if contact is None:
        return False
    _clear_profile_contact_if_matches(db, user_id, contact)
    contact.is_active = False
    db.commit()
    return True


def _get_user_contact(
    db: Session,
    user_id: int,
    contact_id: int,
) -> EmergencyContact | None:
    return db.scalar(
        select(EmergencyContact).where(
            EmergencyContact.id == contact_id,
            EmergencyContact.user_id == user_id,
            EmergencyContact.is_active.is_(True),
        )
    )


def _clear_primary_flag(db: Session, user_id: int) -> None:
    db.execute(
        update(EmergencyContact)
        .where(EmergencyContact.user_id == user_id, EmergencyContact.is_active.is_(True))
        .values(is_primary=False)
    )


def _clear_profile_contact_if_matches(
    db: Session,
    user_id: int,
    contact: EmergencyContact,
) -> None:
    profile = db.scalar(
        select(UserMedicalProfile).where(UserMedicalProfile.user_id == user_id)
    )
    if profile is None:
        return
    same_phone = profile.emergency_contact_phone.strip() == contact.phone.strip()
    same_name = profile.emergency_contact_name.strip() == contact.name.strip()
    if same_phone or (contact.relationship == "Perfil medico" and same_name):
        profile.emergency_contact_name = ""
        profile.emergency_contact_phone = ""


def _to_read(contact: EmergencyContact) -> EmergencyContactRead:
    return EmergencyContactRead(
        id=str(contact.id),
        name=contact.name,
        phone=contact.phone,
        relationship=contact.relationship,
        isPrimary=contact.is_primary,
    )
