#!/usr/bin/env python3
"""Precompute OSRM driving corridor polylines for bundled jeepney routes.

Run offline/CI-time only — never on device during trip planning.

Usage:
  python scripts/build_corridors.py

Reads/writes: assets/data/routes/jeepney_routes.json
"""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROUTES = ROOT / "assets/data/routes/jeepney_routes.json"
OSRM = "https://router.project-osrm.org"
USER_AGENT = "PINPOINT-Butuan/2.0 (corridor-build; contact: thesis-local)"
TIMEOUT = 8
PAUSE_SEC = 0.35


def osrm_route(from_lng: float, from_lat: float, to_lng: float, to_lat: float) -> list[list[float]]:
    coords = f"{from_lng},{from_lat};{to_lng},{to_lat}"
    params = urllib.parse.urlencode(
        {"overview": "full", "geometries": "geojson", "steps": "false"}
    )
    url = f"{OSRM}/route/v1/driving/{coords}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        data = json.loads(resp.read().decode())
    routes = data.get("routes") or []
    if not routes:
        return [[from_lng, from_lat], [to_lng, to_lat]]
    geometry = routes[0]["geometry"]["coordinates"]
    return [[float(c[0]), float(c[1])] for c in geometry]


def build_corridor(stops: list[dict]) -> list[list[float]]:
    if len(stops) < 2:
        return []
    line: list[list[float]] = []
    for i in range(len(stops) - 1):
        a, b = stops[i], stops[i + 1]
        leg = osrm_route(a["lng"], a["lat"], b["lng"], b["lat"])
        if not line:
            line.extend(leg)
        else:
            line.extend(leg[1:])
        time.sleep(PAUSE_SEC)
    return line


def main() -> None:
    doc = json.loads(ROUTES.read_text(encoding="utf-8"))
    for route in doc.get("routes", []):
        stops = [s for s in route.get("ordered_stops", []) if s.get("verified")]
        if len(stops) < 2:
            print(f"SKIP {route['code']}: fewer than 2 verified stops")
            continue
        print(f"Building corridor for {route['code']} ({len(stops)} stops)...")
        try:
            coords = build_corridor(stops)
        except Exception as exc:
            print(f"  WARN {route['code']}: OSRM failed ({exc}), keeping straight-line corridor")
            coords = [[s["lng"], s["lat"]] for s in stops]
        route["corridor_geojson"] = {"type": "LineString", "coordinates": coords}
        print(f"  -> {len(coords)} points")

    ROUTES.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\nUpdated {ROUTES}")


if __name__ == "__main__":
    main()
