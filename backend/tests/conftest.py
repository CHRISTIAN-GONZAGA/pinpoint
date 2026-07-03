"""Pytest configuration and shared fixtures."""

import pytest

from app import create_app
from app.config.config import Config
from app.extensions import db
from app.middleware.rate_limit import reset_rate_limiter


class TestConfig(Config):
  TESTING = True
  DEBUG = True
  SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
  JWT_SECRET_KEY = "test-jwt-secret-key-with-32-characters-min"
  AUTO_SEED = True


@pytest.fixture(autouse=True)
def _reset_rate_limits():
  reset_rate_limiter()
  yield
  reset_rate_limiter()


@pytest.fixture()
def app():
  application = create_app(TestConfig)
  with application.app_context():
    db.create_all()
    yield application
    db.session.remove()
    db.drop_all()


@pytest.fixture()
def client(app):
  return app.test_client()
