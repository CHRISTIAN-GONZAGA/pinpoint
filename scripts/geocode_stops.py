#!/usr/bin/env python3
"""
Geocode LPTRP jeepney stops via Nominatim (review workflow — NOT shipped in app).

Usage:
  python scripts/geocode_stops.py

Reads:  assets/data/routes/jeepney_routes_pending.json
Writes: data/geocode_review.json

Rate limit: 1 request/second. User-Agent required by Nominatim policy.
Manually verify each candidate before copying coords into jeepney_routes.json.
"""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PENDING = ROOT / "assets/data/routes/jeepney_routes_pending.json"
OUT = ROOT / "data/geocode_review.json"
USER_AGENT = "PINPOINT-Butuan/2.0 (geocode-review; contact: thesis-local)"
VIEWBOX = "125.40,8.85,125.65,8.99"  # rough Butuan bbox: left,bottom,right,top


def nominatim_search(query: str) -> list[dict]:
    params = urllib.parse.urlencode(
        {
            "q": query,
            "format": "json",
            "limit": 3,
            "countrycodes": "ph",
            "viewbox": VIEWBOX,
            "bounded": 1,
        }
    )
    url = f"https://nominatim.openstreetmap.org/search?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def main() -> None:
    if not PENDING.exists():
        raise SystemExit(f"Missing {PENDING}")

    catalog = json.loads(PENDING.read_text(encoding="utf-8"))
    results: list[dict] = []

    for route in catalog.get("routes", []):
        code = route.get("code", "?")
        for stop in route.get("ordered_stops", []):
            if stop.get("verified"):
                continue
            name = stop["name"]
            aliases = stop.get("aliases") or []
            queries = [f"{name}, Butuan City, Agusan del Norte, Philippines"]
            queries += [f"{a}, Butuan City, Philippines" for a in aliases]

            candidates = []
            seen = set()
            for q in queries:
                time.sleep(1.1)
                try:
                    for hit in nominatim_search(q):
                        key = (hit["lat"], hit["lon"])
                        if key in seen:
                            continue
                        seen.add(key)
                        candidates.append(
                            {
                                "lat": float(hit["lat"]),
                                "lng": float(hit["lon"]),
                                "display_name": hit.get("display_name"),
                                "query": q,
                            }
                        )
                except Exception as exc:  # noqa: BLE001
                    candidates.append({"error": str(exc), "query": q})

            results.append(
                {
                    "route_code": code,
                    "stop_id": stop["id"],
                    "stop_name": name,
                    "street_segments": route.get("street_segments", []),
                    "candidates": candidates,
                    "verified": False,
                    "review_notes": "Confirm pin sits on listed street segment before setting verified:true",
                }
            )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"), "stops": results}, indent=2), encoding="utf-8")
    print(f"Wrote {len(results)} stop review entries to {OUT}")


if __name__ == "__main__":
    main()
