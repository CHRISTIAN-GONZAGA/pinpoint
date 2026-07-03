"""Tourism and places business logic."""

import json

from app.repositories.places_repository import (
  FavoritesRepository,
  HistoryRepository,
  PlacesRepository,
)
from app.utilities.ttl_cache import ttl_cache


class PlacesService:
  """Tourism, establishments, emergency, and nearby search."""

  def __init__(self, repo: PlacesRepository | None = None) -> None:
    self._repo = repo or PlacesRepository()

  @ttl_cache(seconds=60)
  def list_attractions(self, category: str | None = None) -> list[dict]:
    return [a.to_dict() for a in self._repo.get_attractions(category)]

  def get_attraction(self, attraction_id: int) -> dict | None:
    item = self._repo.get_attraction(attraction_id)
    return item.to_dict() if item else None

  def search(self, query: str) -> dict:
    attractions = [a.to_dict() for a in self._repo.search_attractions(query)]
    establishments = [
      e.to_dict()
      for e in self._repo.get_establishments()
      if query.lower() in e.name.lower()
    ]
    return {"attractions": attractions, "establishments": establishments}

  @ttl_cache(seconds=60)
  def list_establishments(self, category: str | None = None) -> list[dict]:
    return [e.to_dict() for e in self._repo.get_establishments(category)]

  def get_establishment(self, establishment_id: int) -> dict | None:
    item = self._repo.get_establishment(establishment_id)
    return item.to_dict() if item else None

  def list_emergency(self) -> list[dict]:
    return [c.to_dict() for c in self._repo.get_emergency_contacts()]

  def nearby(self, lat: float, lng: float, radius_km: float = 5.0) -> list[dict]:
    return self._repo.nearby_places(lat, lng, radius_km)


class FavoritesService:
  """Registered user favorites."""

  def __init__(self, repo: FavoritesRepository | None = None) -> None:
    self._repo = repo or FavoritesRepository()

  def list_favorites(self, user_id: int) -> list[dict]:
    return [f.to_dict() for f in self._repo.list_for_user(user_id)]

  def add_favorite(self, user_id: int, payload: dict) -> dict:
    favorite = self._repo.add(
      user_id=user_id,
      place_type=payload["place_type"],
      place_id=payload.get("place_id"),
      label=payload["label"],
      latitude=payload.get("latitude"),
      longitude=payload.get("longitude"),
      category=payload.get("category"),
      metadata_json=json.dumps(payload.get("metadata", {})),
    )
    return favorite.to_dict()

  def remove_favorite(self, user_id: int, favorite_id: int) -> bool:
    return self._repo.delete(user_id, favorite_id)


class HistoryService:
  """Registered user search history."""

  def __init__(self, repo: HistoryRepository | None = None) -> None:
    self._repo = repo or HistoryRepository()

  def list_history(self, user_id: int) -> list[dict]:
    return [h.to_dict() for h in self._repo.list_for_user(user_id)]

  def add_entry(self, user_id: int, payload: dict) -> dict:
    entry = self._repo.add(
      user_id=user_id,
      query=payload["query"],
      search_type=payload.get("search_type", "place"),
      latitude=payload.get("latitude"),
      longitude=payload.get("longitude"),
      metadata_json=json.dumps(payload.get("metadata", {})),
    )
    return entry.to_dict()

  def delete_entry(self, user_id: int, history_id: int) -> bool:
    return self._repo.delete(user_id, history_id)

  def clear_history(self, user_id: int) -> None:
    self._repo.clear(user_id)
