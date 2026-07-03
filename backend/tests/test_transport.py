"""Transportation API tests."""


def test_list_routes(client):
  response = client.get("/api/routes")
  assert response.status_code == 200
  routes = response.get_json()["routes"]
  assert len(routes) == 7
  codes = {route["route_code"] for route in routes}
  assert codes == {"R1", "R2", "R3", "R4", "R5", "R6", "R7"}


def test_tricycle_zones(client):
  response = client.get("/api/maps/tricycle-zones")
  assert response.status_code == 200
  zones = response.get_json()["zones"]
  assert len(zones) >= 3


def test_fare_matrix(client):
  response = client.get("/api/fares")
  assert response.status_code == 200
  fares = response.get_json()["fares"]
  types = {fare["transport_type"] for fare in fares}
  assert "jeepney" in types
  assert "tricycle" in types
