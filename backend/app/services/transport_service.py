"""Transportation business logic."""

from app.models.transport import JeepneyRoute
from app.repositories.transport_repository import TransportRepository
from app.utilities.ttl_cache import ttl_cache


class TransportService:
  """Provides jeepney routes, tricycle zones, and fare data."""

  def __init__(self, repo: TransportRepository | None = None) -> None:
    self._repo = repo or TransportRepository()

  @ttl_cache(seconds=60)
  def list_routes(self) -> list[dict]:
    return [route.to_dict() for route in self._repo.get_active_routes()]

  def list_all_routes(self) -> list[dict]:
    return [route.to_dict() for route in self._repo.get_all_routes()]

  def get_route(self, route_id: int, *, active_only: bool = True) -> dict | None:
    route = self._repo.get_route_by_id(route_id, active_only=active_only)
    return route.to_dict() if route else None

  def search_routes(self, query: str) -> list[dict]:
    return [route.to_dict(include_stops=False) for route in self._repo.search_routes(query)]

  def create_route(self, payload: dict) -> dict:
    route = self._repo.create_route(payload)
    self._bust_route_cache()
    return route.to_dict()

  def update_route(self, route_id: int, payload: dict) -> dict | None:
    route = self._repo.get_route_by_id(route_id, active_only=False)
    if not route:
      return None
    updated = self._repo.update_route(route, payload)
    self._bust_route_cache()
    return updated.to_dict()

  def replace_stops(self, route_id: int, stops: list) -> dict | None:
    route = self._repo.get_route_by_id(route_id, active_only=False)
    if not route:
      return None
    updated = self._repo.replace_stops(route, stops)
    self._bust_route_cache()
    return updated.to_dict()

  def delete_route(self, route_id: int) -> bool:
    route = self._repo.get_route_by_id(route_id, active_only=False)
    if not route:
      return False
    self._repo.delete_route(route)
    self._bust_route_cache()
    return True

  def _bust_route_cache(self) -> None:
    clear = getattr(self.list_routes, "cache_clear", None)
    if callable(clear):
      clear()

  @ttl_cache(seconds=60)
  def list_tricycle_zones(self) -> list[dict]:
    return [zone.to_dict() for zone in self._repo.get_active_tricycle_zones()]

  @ttl_cache(seconds=300)
  def list_fares(self) -> list[dict]:
    return [fare.to_dict() for fare in self._repo.get_fare_matrix()]
