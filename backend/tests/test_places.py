"""Phase 3 places and tourism API tests."""


def test_list_attractions(client):
  response = client.get("/api/tourism")
  assert response.status_code == 200
  attractions = response.get_json()["attractions"]
  assert len(attractions) >= 4


def test_nearby_places(client):
  response = client.get("/api/tourism/nearby?lat=8.9475&lng=125.5406&radius=10")
  assert response.status_code == 200
  places = response.get_json()["places"]
  assert len(places) > 0
  assert "distance_km" in places[0]


def test_emergency_contacts(client):
  response = client.get("/api/emergency")
  assert response.status_code == 200
  contacts = response.get_json()["contacts"]
  assert len(contacts) >= 5


def test_establishments_by_category(client):
  response = client.get("/api/establishments?category=hospital")
  assert response.status_code == 200
  items = response.get_json()["establishments"]
  assert all(item["category"] == "hospital" for item in items)


def test_favorites_require_auth(client):
  response = client.get("/api/favorites")
  assert response.status_code == 401
