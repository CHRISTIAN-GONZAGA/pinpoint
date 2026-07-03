"""Application configuration loaded from environment variables."""

import os
from datetime import timedelta
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from dotenv import load_dotenv

load_dotenv()

APP_VERSION = os.getenv("APP_VERSION", "2.0.0")


def _clean_env_value(value: str | None) -> str:
  """Strip whitespace and optional quotes from env vars."""
  if not value:
    return ""
  return value.strip().strip('"').strip("'")


def normalize_database_url(url: str) -> str:
  """Convert Render/Heroku postgres URLs to SQLAlchemy-compatible URIs."""
  url = _clean_env_value(url)
  if not url:
    return url
  if url.startswith("postgres://"):
    url = url.replace("postgres://", "postgresql+psycopg2://", 1)
  elif url.startswith("postgresql://") and "+psycopg2" not in url:
    url = url.replace("postgresql://", "postgresql+psycopg2://", 1)

  # Render Postgres requires SSL; append if missing.
  if url.startswith("postgresql+psycopg2://"):
    parsed = urlparse(url)
    query = dict(parse_qsl(parsed.query, keep_blank_values=True))
    if "sslmode" not in query:
      query["sslmode"] = "require"
      url = urlunparse(parsed._replace(query=urlencode(query)))
  return url


def resolve_database_url(default: str = "sqlite:///pinpoint.db") -> str:
  """Read DATABASE_URL from the environment with safe fallbacks."""
  raw = os.getenv("DATABASE_URL")
  if raw is None:
    return normalize_database_url(default)

  cleaned = _clean_env_value(raw)
  if not cleaned:
    if os.getenv("FLASK_ENV") == "production":
      raise ValueError(
        "DATABASE_URL is empty. In Render, open pinpoint-api → Environment → "
        "Add Environment Variable → Link PostgreSQL database (pinpoint-db)."
      )
    return normalize_database_url(default)

  return normalize_database_url(cleaned)


class Config:
  """Base configuration for PINPOINT backend."""

  APP_VERSION = APP_VERSION
  SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key")
  JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-jwt-secret")
  SQLALCHEMY_DATABASE_URI = resolve_database_url()
  SQLALCHEMY_TRACK_MODIFICATIONS = False
  CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")
  API_PREFIX = os.getenv("API_PREFIX", "/api")
  DEBUG = os.getenv("DEBUG_MODE", "true").lower() == "true"
  AUTO_SEED = os.getenv("AUTO_SEED", "true").lower() == "true"
  CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "60"))

  JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
  JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

  # AI / RAG configuration
  VECTOR_DB_PATH = os.getenv("VECTOR_DB_PATH", "./chroma_data")
  AI_MODEL = os.getenv("AI_MODEL", "gpt-4o-mini")
  EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "default")
  OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
  OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
  OPENROUTER_API_KEY = os.getenv("OPENROUTER_KEY", "")
  AI_USE_CHROMA = os.getenv("AI_USE_CHROMA", "false").lower() == "true"
  AI_RETRIEVAL_TOP_K = int(os.getenv("AI_RETRIEVAL_TOP_K", "5"))


class ProductionConfig(Config):
  """Production-ready settings."""

  DEBUG = False
  AUTO_SEED = os.getenv("AUTO_SEED", "false").lower() == "true"


class DevelopmentConfig(Config):
  """Local development defaults."""

  DEBUG = True
  AUTO_SEED = True
