"""Deployment, health, and performance tests."""


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
