"""Deployment, health, and performance tests."""

from app import create_app
from app.config.config import Config
from app.extensions import db
from app.models.transport import FareMatrix, JeepneyRoute, TricycleZone


class ProductionBootstrapConfig(Config):
  SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
  AUTO_SEED = False


def test_health_includes_version_and_database(client):
  response = client.get("/health")
  assert response.status_code == 200
  data = response.get_json()
  assert data["status"] == "healthy"
  assert data["service"] == "pinpoint-api"
  assert "version" in data
  assert data["database"] == "ok"


def test_security_headers_present(client):
  response = client.get("/health")
  assert response.headers.get("X-Content-Type-Options") == "nosniff"
  assert response.headers.get("X-Frame-Options") == "DENY"


def test_transport_list_is_cached(client):
  first = client.get("/api/routes")
  second = client.get("/api/routes")
  assert first.status_code == 200
  assert second.status_code == 200
  assert first.get_json() == second.get_json()


def test_transport_data_bootstraps_when_auto_seed_is_disabled():
  app = create_app(ProductionBootstrapConfig)
  with app.app_context():
    assert JeepneyRoute.query.count() == 7
    assert TricycleZone.query.count() >= 3
    assert FareMatrix.query.filter_by(transport_type="jeepney").first() is not None
    db.session.remove()
    db.drop_all()
