from __future__ import annotations

from functools import lru_cache
from pathlib import Path, PurePosixPath
from uuid import uuid4

from supabase import Client, create_client

from backend.core.config import settings


ALLOWED_PHOTO_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
MAX_PHOTO_BYTES = 5 * 1024 * 1024


class MedicationPhotoConfigurationError(RuntimeError):
    pass


class MedicationPhotoNotFoundError(FileNotFoundError):
    pass


def _supabase_configured() -> bool:
    return bool(settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY)


def _local_storage_root() -> Path:
    configured = settings.MEDICATION_PHOTOS_LOCAL_DIR.strip()
    root = Path(configured) if configured else Path("storage/medication_photos")
    if not root.is_absolute():
        root = Path(__file__).resolve().parents[2] / root
    return root


def _local_object_path(object_path: str) -> Path:
    return _local_storage_root() / PurePosixPath(object_path)


@lru_cache
def _storage_client() -> Client:
    if not _supabase_configured():
        raise MedicationPhotoConfigurationError(
            "Supabase Storage no esta configurado en el backend"
        )
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


def upload_medication_photo(
    *,
    user_id: int,
    medication_id: int,
    content: bytes,
    content_type: str,
) -> str:
    extension = ALLOWED_PHOTO_TYPES.get(content_type)
    if extension is None:
        raise ValueError("La foto debe ser JPEG, PNG o WebP")
    if not content or len(content) > MAX_PHOTO_BYTES:
        raise ValueError("La foto debe pesar entre 1 byte y 5 MB")

    object_path = (
        PurePosixPath("users")
        / str(user_id)
        / "medications"
        / str(medication_id)
        / f"{uuid4().hex}{extension}"
    ).as_posix()

    if _supabase_configured():
        _storage_client().storage.from_(settings.SUPABASE_MEDICATION_BUCKET).upload(
            path=object_path,
            file=content,
            file_options={"content-type": content_type, "upsert": "false"},
        )
        return object_path

    destination = _local_object_path(object_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
    return object_path


def download_medication_photo(object_path: str) -> bytes:
    if _supabase_configured():
        return _storage_client().storage.from_(
            settings.SUPABASE_MEDICATION_BUCKET
        ).download(object_path)

    local_path = _local_object_path(object_path)
    if not local_path.is_file():
        raise MedicationPhotoNotFoundError("Foto no encontrada")
    return local_path.read_bytes()


def delete_medication_photo(object_path: str | None) -> None:
    if not object_path:
        return

    if _supabase_configured():
        _storage_client().storage.from_(settings.SUPABASE_MEDICATION_BUCKET).remove(
            [object_path]
        )
        return

    local_path = _local_object_path(object_path)
    if local_path.is_file():
        local_path.unlink()
