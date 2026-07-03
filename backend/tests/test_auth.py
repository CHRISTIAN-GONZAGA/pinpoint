"""Authentication endpoint tests."""


def test_health_check(client):
  response = client.get("/health")
  assert response.status_code == 200
  assert response.get_json()["status"] == "healthy"


def test_register_and_login(client):
  register = client.post(
    "/api/auth/register",
    json={
      "full_name": "Test User",
      "email": "test@pinpoint.local",
      "password": "SecurePass1",
    },
  )
  assert register.status_code == 200
  data = register.get_json()
  assert "access_token" in data
  assert data["user"]["email"] == "test@pinpoint.local"

  login = client.post(
    "/api/auth/login",
    json={"email": "test@pinpoint.local", "password": "SecurePass1"},
  )
  assert login.status_code == 200
  assert login.get_json()["user"]["full_name"] == "Test User"


def test_profile_requires_auth(client):
  response = client.get("/api/users/profile")
  assert response.status_code == 401
