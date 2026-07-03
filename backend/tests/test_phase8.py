"""Phase 8 account services, security, and rate limiting tests."""

from app.middleware.rate_limit import reset_rate_limiter


def _user_headers(client, email="phase8@pinpoint.local", password="SecurePass1"):
  reset_rate_limiter()
  client.post(
    "/api/auth/register",
    json={
      "full_name": "Phase Eight",
      "email": email,
      "password": password,
    },
  )
  login = client.post(
    "/api/auth/login",
    json={"email": email, "password": password},
  )
  token = login.get_json()["access_token"]
  return {"Authorization": f"Bearer {token}"}


def test_forgot_and_reset_password(client):
  reset_rate_limiter()
  email = "resetme@pinpoint.local"
  client.post(
    "/api/auth/register",
    json={"full_name": "Reset User", "email": email, "password": "SecurePass1"},
  )

  forgot = client.post("/api/auth/forgot-password", json={"email": email})
  assert forgot.status_code == 200
  data = forgot.get_json()
  assert "reset_token" in data

  reset = client.post(
    "/api/auth/reset-password",
    json={"token": data["reset_token"], "password": "NewSecure1"},
  )
  assert reset.status_code == 200

  login = client.post("/api/auth/login", json={"email": email, "password": "NewSecure1"})
  assert login.status_code == 200


def test_delete_account(client):
  headers = _user_headers(client, email="delete-me@pinpoint.local")
  response = client.delete("/api/users/account", headers=headers)
  assert response.status_code == 200

  login = client.post(
    "/api/auth/login",
    json={"email": "delete-me@pinpoint.local", "password": "SecurePass1"},
  )
  assert login.status_code == 401


def test_auth_rate_limit(client):
  reset_rate_limiter()
  for _ in range(10):
    client.post(
      "/api/auth/login",
      json={"email": "missing@pinpoint.local", "password": "wrongpass"},
    )
  blocked = client.post(
    "/api/auth/login",
    json={"email": "missing@pinpoint.local", "password": "wrongpass"},
  )
  assert blocked.status_code == 429
