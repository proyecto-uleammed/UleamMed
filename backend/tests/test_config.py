import unittest

from backend.core.config import Settings


class DatabaseUrlDriverNormalizationTests(unittest.TestCase):
    """Supabase entrega el connection string sin el driver psycopg v3.

    Sin normalizar, SQLAlchemy asume psycopg2 (no instalado en este
    proyecto) y el backend crashea al arrancar. Estos tests blindan que
    `Settings` siempre termine usando `postgresql+psycopg://`.
    """

    def test_normaliza_esquema_postgresql_simple(self):
        settings = Settings(DATABASE_URL="postgresql://user:pass@host:5432/db")
        self.assertEqual(
            settings.DATABASE_URL, "postgresql+psycopg://user:pass@host:5432/db"
        )

    def test_normaliza_esquema_postgres_legado(self):
        settings = Settings(DATABASE_URL="postgres://user:pass@host:5432/db")
        self.assertEqual(
            settings.DATABASE_URL, "postgresql+psycopg://user:pass@host:5432/db"
        )

    def test_no_toca_url_que_ya_especifica_driver(self):
        url = "postgresql+psycopg://user:pass@host:5432/db"
        settings = Settings(DATABASE_URL=url)
        self.assertEqual(settings.DATABASE_URL, url)

    def test_no_toca_otro_driver_explicito(self):
        url = "postgresql+asyncpg://user:pass@host:5432/db"
        settings = Settings(DATABASE_URL=url)
        self.assertEqual(settings.DATABASE_URL, url)


if __name__ == "__main__":
    unittest.main()
