"""Crea el bucket privado usado por fotos de medicamentos."""

from backend.core.config import settings
from backend.services.medication_photo_service import _storage_client


def main() -> None:
    client = _storage_client()
    existing = {
        bucket.name
        for bucket in client.storage.list_buckets()
    }
    if settings.SUPABASE_MEDICATION_BUCKET in existing:
        print("El bucket de medicamentos ya existe")
        return
    client.storage.create_bucket(
        settings.SUPABASE_MEDICATION_BUCKET,
        options={
            "public": False,
            "file_size_limit": 5 * 1024 * 1024,
            "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"],
        },
    )
    print("Bucket privado de medicamentos creado")


if __name__ == "__main__":
    main()
