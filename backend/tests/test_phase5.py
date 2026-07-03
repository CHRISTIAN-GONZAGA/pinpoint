"""Phase 5 admin, notifications, sync, and analytics tests."""

import json


def _admin_headers(client):
  login = client.post(
    "/api/auth/login",
    json={"email": "admin@pinpoint.local", "password": "AdminPass1"},
  )
  token = login.get_json()["access_token"]
  return {"Authorization": f"Bearer {token}"}


def _user_headers(client):
  client.post(
    "/api/auth/register",
    json={
      "full_name": "Sync User",
      "email": "sync@pinpoint.local",
      "password": "SecurePass1",
    },
  )
  login = client.post(
    "/api/auth/login",
    json={"email": "sync@pinpoint.local", "password": "SecurePass1"},
  )
  token = login.get_json()["access_token"]
  return {"Authorization": f"Bearer {token}"}


def test_public_announcements(client):
  response = client.get("/api/notifications/announcements")
  assert response.status_code == 200
  data = response.get_json()
  assert len(data["announcements"]) >= 1


def test_admin_dashboard(client):
  headers = _admin_headers(client)
  response = client.get("/api/admin/dashboard", headers=headers)
  assert response.status_code == 200
  data = response.get_json()
  assert "total_users" in data
  assert "routes" in data


def test_admin_create_announcement(client):
  headers = _admin_headers(client)
  response = client.post(
    "/api/admin/announcements",
    headers=headers,
    json={
      "title": "Route R2 Maintenance",
      "content": "Temporary reroute near Robinsons this weekend.",
      "category": "transport",
      "priority": "high",
    },
  )
  assert response.status_code == 201


def test_sync_pull(client):
  headers = _user_headers(client)
  response = client.get("/api/sync/pull", headers=headers)
  assert response.status_code == 200
  data = response.get_json()
  assert "profile" in data
  assert "favorites" in data


def test_submit_report(client):
  headers = _user_headers(client)
  response = client.post(
    "/api/reports",
    headers=headers,
    json={
      "category": "incorrect_fare",
      "description": "Displayed fare does not match signage.",
      "latitude": 8.95,
      "longitude": 125.54,
    },
  )
  assert response.status_code == 201


def test_track_analytics_event(client):
  response = client.post(
    "/api/analytics/events",
    json={"event_type": "route_generated", "metadata": {"mode": "jeepney"}},
  )
  assert response.status_code == 201


def test_route_pdf_export(client):
  response = client.post(
    "/api/pdf/route",
    json={
      "origin_label": "Baan Junction",
      "destination_label": "Robinsons Place",
      "distance_label": "4.2 km",
      "duration_label": "25 min",
      "estimated_fare": 15,
      "steps": [{"instruction": "Walk to jeepney stop", "duration_label": "5 min"}],
    },
  )
  assert response.status_code == 200
  assert response.mimetype == "application/pdf"
