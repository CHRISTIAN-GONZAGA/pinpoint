"""Transportation business logic."""

from app.repositories.transport_repository import TransportRepository
from app.utilities.ttl_cache import ttl_cache


class TransportService:
  """Provides jeepney routes, tricycle zones, and fare data."""

  def __init__(self, repo: TransportRepository | None = None) -> None:
    self._repo = repo or TransportRepository()

  @ttl_cache(seconds=60)
  def list_routes(self) -> list[dict]:
    return [route.to_dict() for route in self._repo.get_active_routes()]

  def get_route(self, route_id: int) -> dict | None:
    route = self._repo.get_route_by_id(route_id)
    return route.to_dict() if route else None

  def search_routes(self, query: str) -> list[dict]:
    return [route.to_dict(include_stops=False) for route in self._repo.search_routes(query)]

  @ttl_cache(seconds=60)
  def list_tricycle_zones(self) -> list[dict]:
    return [zone.to_dict() for zone in self._repo.get_active_tricycle_zones()]

  @ttl_cache(seconds=300)
  def list_fares(self) -> list[dict]:
    return [fare.to_dict() for fare in self._repo.get_fare_matrix()]