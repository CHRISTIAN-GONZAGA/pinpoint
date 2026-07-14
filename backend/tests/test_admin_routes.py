"""Admin route management API tests."""


def _admin_token(client) -> str:
  login = client.post(
    "/api/auth/login",
    json={"email": "admin@pinpoint.local", "password": "AdminPass1"},
  )
  assert login.status_code == 200
  return login.get_json()["access_token"]


def test_admin_create_update_delete_route(client):
  token = _admin_token(client)
  headers = {"Authorization": f"Bearer {token}"}

  create = client.post(
    "/api/admin/routes",
    headers=headers,
    json={
      "route_code": "R8",
      "route_name": "Test Bus Loop",
      "color": "#8338EC",
      "vehicle_type": "bus",
      "base_fare": 15,
      "additional_fare": 2,
      "description": "Admin-created bus corridor",
      "active_status": True,
      "corridor_geojson": {
        "type": "LineString",
        "coordinates": [
          [125.54, 8.95],
          [125.55, 8.96],
          [125.56, 8.95],
        ],
      },
      "stops": [
        {"name": "Start", "lat": 8.95, "lng": 125.54, "stop_order": 1},
        {
          "name": "Mid",
          "lat": 8.96,
          "lng": 125.55,
          "stop_order": 2,
          "description": "Transfer point",
        },
        {"name": "End", "lat": 8.95, "lng": 125.56, "stop_order": 3},
      ],
    },
  )
  assert create.status_code == 201, create.get_json()
  body = create.get_json()
  assert body["route_code"] == "R8"
  assert body["vehicle_type"] == "bus"
  assert body["base_fare"] == 15
  assert len(body["ordered_stops"]) == 3
  assert body["ordered_stops"][1]["description"] == "Transfer point"
  route_id = body["route_id"]

  listed = client.get("/api/admin/routes", headers=headers)
  assert listed.status_code == 200
  codes = {r["route_code"] for r in listed.get_json()["routes"]}
  assert "R8" in codes

  public = client.get("/api/routes")
  public_codes = {r["route_code"] for r in public.get_json()["routes"]}
  assert "R8" in public_codes

  updated = client.patch(
    f"/api/admin/routes/{route_id}",
    headers=headers,
    json={"active_status": False, "vehicle_type": "van"},
  )
  assert updated.status_code == 200
  assert updated.get_json()["active_status"] is False
  assert updated.get_json()["vehicle_type"] == "van"

  public_after = client.get("/api/routes")
  public_after_codes = {r["route_code"] for r in public_after.get_json()["routes"]}
  assert "R8" not in public_after_codes

  deleted = client.delete(f"/api/admin/routes/{route_id}", headers=headers)
  assert deleted.status_code == 200


def test_admin_routes_require_auth(client):
  response = client.get("/api/admin/routes")
  assert response.status_code == 401
