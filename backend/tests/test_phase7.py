"""Phase 7 personalization, offline, and database tests."""


def _user_headers(client, email="phase7@pinpoint.local"):
  client.post(
    "/api/auth/register",
    json={
      "full_name": "Phase Seven",
      "email": email,
      "password": "SecurePass1",
    },
  )
  login = client.post(
    "/api/auth/login",
    json={"email": email, "password": "SecurePass1"},
  )
  token = login.get_json()["access_token"]
  return {"Authorization": f"Bearer {token}"}


def test_update_profile_settings(client):
  headers = _user_headers(client)
  response = client.patch(
    "/api/users/profile",
    headers=headers,
    json={
      "language_preference": "tl",
      "large_text_enabled": True,
      "emergency_contact_name": "Maria",
      "emergency_contact_phone": "09171234567",
    },
  )
  assert response.status_code == 200
  data = response.get_json()
  assert data["language_preference"] == "tl"
  assert data["large_text_enabled"] is True
  assert data["emergency_contact_name"] == "Maria"


def test_ai_history_persistence(client):
  headers = _user_headers(client)
  save = client.post(
    "/api/ai/history",
    headers=headers,
    json={
      "session_id": "session-abc",
      "messages": [
        {"role": "user", "content": "Which jeep goes to SM?", "language": "en"},
        {"role": "assistant", "content": "Route R3 serves SM City Butuan.", "language": "en"},
      ],
    },
  )
  assert save.status_code == 201
  listed = client.get("/api/ai/history?session_id=session-abc", headers=headers)
  assert listed.status_code == 200
  messages = listed.get_json()["messages"]
  assert len(messages) == 2
  assert messages[0]["role"] == "user"


def test_ai_history_is_scoped_to_session_and_user(client):
  owner_headers = _user_headers(client, "history-owner@pinpoint.local")
  other_headers = _user_headers(client, "history-other@pinpoint.local")
  client.post(
    "/api/ai/history",
    headers=owner_headers,
    json={
      "session_id": "private-session",
      "messages": [{"role": "user", "content": "Owner-only message"}],
    },
  )
  client.post(
    "/api/ai/history",
    headers=owner_headers,
    json={
      "session_id": "other-session",
      "messages": [{"role": "user", "content": "Different conversation"}],
    },
  )

  owner_session = client.get(
    "/api/ai/history?session_id=private-session",
    headers=owner_headers,
  )
  other_user = client.get(
    "/api/ai/history?session_id=private-session",
    headers=other_headers,
  )

  assert [entry["content"] for entry in owner_session.get_json()["messages"]] == [
    "Owner-only message"
  ]
  assert other_user.get_json()["messages"] == []


def test_register_device_token(client):
  headers = _user_headers(client)
  response = client.post(
    "/api/users/devices",
    headers=headers,
    json={"token": "fcm-device-token-123", "platform": "android"},
  )
  assert response.status_code == 201
  assert response.get_json()["platform"] == "android"
