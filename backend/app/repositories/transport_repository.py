"""Transportation data repositories."""

from __future__ import annotations

import json

from app.extensions import db
from app.models.transport import (
  ALLOWED_VEHICLE_TYPES,
  FareMatrix,
  JeepneyRoute,
  RouteStop,
  TricycleZone,
)


class TransportRepository:
  """Data access for jeepney routes, tricycle zones, and fares."""

  def get_active_routes(self) -> list[JeepneyRoute]:
    return (
      JeepneyRoute.query.filter_by(active_status=True)
      .order_by(JeepneyRoute.route_code)
      .all()
    )

  def get_all_routes(self) -> list[JeepneyRoute]:
    return JeepneyRoute.query.order_by(JeepneyRoute.route_code).all()

  def get_route_by_id(
    self, route_id: int, *, active_only: bool = True
  ) -> JeepneyRoute | None:
    query = JeepneyRoute.query.filter_by(route_id=route_id)
    if active_only:
      query = query.filter_by(active_status=True)
    return query.first()

  def get_route_by_code(
    self, route_code: str, *, active_only: bool = True
  ) -> JeepneyRoute | None:
    query = JeepneyRoute.query.filter_by(route_code=route_code.upper())
    if active_only:
      query = query.filter_by(active_status=True)
    return query.first()

  def search_routes(self, query: str) -> list[JeepneyRoute]:
    pattern = f"%{query}%"
    return (
      JeepneyRoute.query.filter(
        JeepneyRoute.active_status.is_(True),
        db.or_(
          JeepneyRoute.route_code.ilike(pattern),
          JeepneyRoute.route_name.ilike(pattern),
        ),
      )
      .order_by(JeepneyRoute.route_code)
      .all()
    )

  def get_active_tricycle_zones(self) -> list[TricycleZone]:
    return (
      TricycleZone.query.filter_by(active_status=True)
      .order_by(TricycleZone.zone_name)
      .all()
    )

  def get_fare_matrix(self) -> list[FareMatrix]:
    return FareMatrix.query.order_by(FareMatrix.transport_type).all()

  @staticmethod
  def _normalize_geojson(payload: dict | list | str) -> str:
    if isinstance(payload, str):
      parsed = json.loads(payload)
    else:
      parsed = payload

    if isinstance(parsed, dict) and parsed.get("type") == "Feature":
      geometry = parsed.get("geometry") or {}
    elif isinstance(parsed, dict) and parsed.get("type") == "FeatureCollection":
      features = parsed.get("features") or []
      geometry = (features[0] or {}).get("geometry") if features else {}
    elif isinstance(parsed, dict) and "coordinates" in parsed:
      geometry = parsed
    else:
      raise ValueError("geojson must be a LineString, Feature, or FeatureCollection")

    if geometry.get("type") != "LineString":
      raise ValueError("corridor geometry must be a LineString")
    coords = geometry.get("coordinates") or []
    if len(coords) < 2:
      raise ValueError("corridor must contain at least 2 coordinates")

    return json.dumps(
      {
        "type": "Feature",
        "properties": {},
        "geometry": {
          "type": "LineString",
          "coordinates": coords,
        },
      }
    )

  @staticmethod
  def _normalize_stops(raw_stops: list | None) -> list[dict]:
    stops = raw_stops or []
    normalized: list[dict] = []
    orders: set[int] = set()
    for index, item in enumerate(stops):
      name = (item.get("stop_name") or item.get("name") or "").strip()
      if not name:
        raise ValueError(f"stop at index {index} is missing a name")
      lat = item.get("latitude", item.get("lat"))
      lng = item.get("longitude", item.get("lng"))
      if lat is None or lng is None:
        raise ValueError(f"stop '{name}' is missing coordinates")
      order = int(item.get("stop_order") or item.get("order") or (index + 1))
      if order in orders:
        raise ValueError(f"duplicate stop_order: {order}")
      orders.add(order)
      normalized.append(
        {
          "stop_name": name,
          "latitude": float(lat),
          "longitude": float(lng),
          "stop_order": order,
          "description": (item.get("description") or None),
        }
      )
    normalized.sort(key=lambda s: s["stop_order"])
    return normalized

  def create_route(self, payload: dict) -> JeepneyRoute:
    code = (payload.get("route_code") or payload.get("code") or "").strip().upper()
    name = (payload.get("route_name") or payload.get("name") or "").strip()
    color = (payload.get("color") or "#1A3A6B").strip()
    vehicle_type = (payload.get("vehicle_type") or "jeepney").strip().lower()

    if not code or not name:
      raise ValueError("route_code and route_name are required")
    if vehicle_type not in ALLOWED_VEHICLE_TYPES:
      raise ValueError(
        f"vehicle_type must be one of: {', '.join(sorted(ALLOWED_VEHICLE_TYPES))}"
      )
    if self.get_route_by_code(code, active_only=False):
      raise ValueError(f"route_code '{code}' already exists")

    corridor = payload.get("corridor_geojson") or payload.get("geojson")
    if corridor is None:
      raise ValueError("corridor_geojson is required")
    geojson_text = self._normalize_geojson(corridor)

    route = JeepneyRoute(
      route_code=code,
      route_name=name,
      color=color,
      description=payload.get("description"),
      operating_hours=payload.get("operating_hours"),
      geojson=geojson_text,
      active_status=bool(payload.get("active_status", True)),
      vehicle_type=vehicle_type,
      base_fare=payload.get("base_fare"),
      additional_fare=payload.get("additional_fare"),
    )
    db.session.add(route)
    db.session.flush()

    for stop in self._normalize_stops(payload.get("stops") or payload.get("ordered_stops")):
      db.session.add(
        RouteStop(
          route_id=route.route_id,
          stop_name=stop["stop_name"],
          latitude=stop["latitude"],
          longitude=stop["longitude"],
          stop_order=stop["stop_order"],
          description=stop["description"],
        )
      )
    db.session.commit()
    return route

  def update_route(self, route: JeepneyRoute, payload: dict) -> JeepneyRoute:
    if "route_code" in payload or "code" in payload:
      code = (payload.get("route_code") or payload.get("code") or "").strip().upper()
      if not code:
        raise ValueError("route_code cannot be empty")
      existing = self.get_route_by_code(code, active_only=False)
      if existing and existing.route_id != route.route_id:
        raise ValueError(f"route_code '{code}' already exists")
      route.route_code = code

    if "route_name" in payload or "name" in payload:
      name = (payload.get("route_name") or payload.get("name") or "").strip()
      if not name:
        raise ValueError("route_name cannot be empty")
      route.route_name = name

    if "color" in payload and payload["color"]:
      route.color = str(payload["color"]).strip()
    if "description" in payload:
      route.description = payload.get("description")
    if "operating_hours" in payload:
      route.operating_hours = payload.get("operating_hours")
    if "active_status" in payload:
      route.active_status = bool(payload["active_status"])
    if "base_fare" in payload:
      route.base_fare = payload.get("base_fare")
    if "additional_fare" in payload:
      route.additional_fare = payload.get("additional_fare")
    if "vehicle_type" in payload:
      vehicle_type = str(payload.get("vehicle_type") or "").strip().lower()
      if vehicle_type not in ALLOWED_VEHICLE_TYPES:
        raise ValueError(
          f"vehicle_type must be one of: {', '.join(sorted(ALLOWED_VEHICLE_TYPES))}"
        )
      route.vehicle_type = vehicle_type

    corridor = payload.get("corridor_geojson", payload.get("geojson", None))
    if corridor is not None:
      route.geojson = self._normalize_geojson(corridor)

    if "stops" in payload or "ordered_stops" in payload:
      self.replace_stops(route, payload.get("stops") or payload.get("ordered_stops") or [])

    db.session.commit()
    return route

  def replace_stops(self, route: JeepneyRoute, raw_stops: list) -> JeepneyRoute:
    normalized = self._normalize_stops(raw_stops)
    route.stops.clear()
    db.session.flush()
    for stop in normalized:
      route.stops.append(
        RouteStop(
          route_id=route.route_id,
          stop_name=stop["stop_name"],
          latitude=stop["latitude"],
          longitude=stop["longitude"],
          stop_order=stop["stop_order"],
          description=stop["description"],
        )
      )
    db.session.commit()
    return route

  def delete_route(self, route: JeepneyRoute) -> None:
    db.session.delete(route)
    db.session.commit()
