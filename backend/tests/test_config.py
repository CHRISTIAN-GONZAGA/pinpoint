"""Configuration helpers for deployment targets."""

from app.config.config import normalize_database_url


def test_normalize_render_postgres_url_adds_driver_and_ssl():
  url = normalize_database_url(
    "postgres://pinpoint:secret@dpg-test-a.singapore-postgres.render.com/pinpoint"
  )
  assert url.startswith("postgresql+psycopg2://")
  assert "sslmode=require" in url


def test_normalize_sqlite_url_unchanged():
  url = normalize_database_url("sqlite:///pinpoint.db")
  assert url == "sqlite:///pinpoint.db"
