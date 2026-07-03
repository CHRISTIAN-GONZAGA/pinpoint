"""Configuration helpers for deployment targets."""

import os

import pytest

from app.config.config import normalize_database_url, resolve_database_url


def test_normalize_render_postgres_url_adds_driver_and_ssl():
  url = normalize_database_url(
    "postgres://pinpoint:secret@dpg-test-a.singapore-postgres.render.com/pinpoint"
  )
  assert url.startswith("postgresql+psycopg2://")
  assert "sslmode=require" in url


def test_normalize_sqlite_url_unchanged():
  url = normalize_database_url("sqlite:///pinpoint.db")
  assert url == "sqlite:///pinpoint.db"


def test_normalize_strips_quotes_and_whitespace():
  url = normalize_database_url(
    '  "postgres://pinpoint:secret@host/pinpoint"  '
  )
  assert url.startswith("postgresql+psycopg2://pinpoint:secret@host/pinpoint")


def test_resolve_database_url_uses_sqlite_when_unset(monkeypatch):
  monkeypatch.delenv("DATABASE_URL", raising=False)
  assert resolve_database_url() == "sqlite:///pinpoint.db"


def test_resolve_database_url_raises_in_production_when_empty(monkeypatch):
  monkeypatch.setenv("DATABASE_URL", "")
  monkeypatch.setenv("FLASK_ENV", "production")
  with pytest.raises(ValueError, match="DATABASE_URL is empty"):
    resolve_database_url()
