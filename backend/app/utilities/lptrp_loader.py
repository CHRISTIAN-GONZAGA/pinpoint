"""Load LPTRP 2024 jeepney routes from Flutter bundled assets into PostgreSQL."""

from __future__ import annotations

import json
from pathlib import Path

from sqlalchemy import text

from app.extensions import db
from app.models.transport import JeepneyRoute, RouteStop

# Repo root: backend/app/utilities -> backend/data (Docker) or repo/assets (local dev).
_BACKEND_DATA = Path(__file__).resolve().parents[2] / "data" / "lptrp_routes.json"
_ASSETS_ROUTES = (
  Path(__file__).resolve().parents[3] / "assets" / "data" / "routes" / "jeepney_routes.json"
)

_LPTRP_LOCK_ID = 91524001


def lptrp_asset_path() -> Path:
  if _BACKEND_DATA.exists():
    return _BACKEND_DATA
  return _ASSETS_ROUTES


def load_lptrp_document() -> dict:
  path = lptrp_asset_path()
  if not path.exists():
    raise FileNotFoundError(f"LPTRP asset not found: {path}")
  return json.loads(path.read_text(encoding="utf-8"))


def _geojson_text(route: dict) -> str:
  corridor = route.get("corridor_geojson")
  if isinstance(corridor, dict):
    return json.dumps(corridor)
  return json.dumps(
    {
      "type": "Feature",
      "geometry": {"type": "LineString", "coordinates": []},
      "properties": {},
    }
  )


def needs_lptrp_upgrade() -> bool:
  """True when DB is empty or still on pre-2024 route names."""
  if JeepneyRoute.query.count() == 0:
    return True
  r1 = JeepneyRoute.query.filter_by(route_code="R1").first()
  if r1 is None:
    return True
  return "West and East Loop" not in (r1.route_name or "")


def _try_advisory_lock() -> bool:
  if db.engine.dialect.name != "postgresql":
    return True
  return bool(
    db.session.execute(
      text("SELECT pg_try_advisory_lock(:id)"),
      {"id": _LPTRP_LOCK_ID},
    ).scalar()
  )


def _release_advisory_lock() -> None:
  if db.engine.dialect.name != "postgresql":
    return
  db.session.execute(
    text("SELECT pg_advisory_unlock(:id)"),
    {"id": _LPTRP_LOCK_ID},
  )


def _clear_all_routes() -> None:
  """Delete stops before routes — bulk ORM delete skips FK cascade."""
  db.session.execute(text("DELETE FROM route_stops"))
  db.session.execute(text("DELETE FROM jeepney_routes"))
  db.session.flush()


def import_lptrp_routes(*, force: bool = False) -> int:
  """Upsert all LPTRP routes from bundled JSON. Returns number of routes written."""
  if not force and not needs_lptrp_upgrade():
    return 0

  if not _try_advisory_lock():
    db.session.rollback()
    return 0 if not needs_lptrp_upgrade() else 0

  try:
    if not force and not needs_lptrp_upgrade():
      return 0

    doc = load_lptrp_document()
    routes = doc.get("routes") or []
    if not routes:
      return 0

    if force or needs_lptrp_upgrade():
      _clear_all_routes()

    written = 0
    for route_def in routes:
      code = route_def["code"]
      existing = JeepneyRoute.query.filter_by(route_code=code).first()
      if existing:
        db.session.delete(existing)
        db.session.flush()

      route = JeepneyRoute(
        route_code=code,
        route_name=route_def["name"],
        color=route_def["color"],
        description=route_def.get("description"),
        operating_hours=route_def.get("operating_hours", "5:00 AM – 8:00 PM"),
        geojson=_geojson_text(route_def),
        active_status=True,
      )
      db.session.add(route)
      db.session.flush()

      for order, stop in enumerate(route_def.get("ordered_stops") or [], start=1):
        if not stop.get("verified", True):
          continue
        lat, lng = stop.get("lat"), stop.get("lng")
        if lat is None or lng is None:
          continue
        db.session.add(
          RouteStop(
            route_id=route.route_id,
            stop_name=stop["name"],
            latitude=float(lat),
            longitude=float(lng),
            stop_order=order,
          )
        )
      written += 1

    db.session.commit()
    return written
  except Exception:
    db.session.rollback()
    raise
  finally:
    _release_advisory_lock()

