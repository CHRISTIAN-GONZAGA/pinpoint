#!/usr/bin/env python3
"""Promote manually reviewed geocode candidates into production jeepney_routes.json.

Usage:
  python scripts/promote_geocode_review.py

Reads:  data/geocode_review.json (verified stops only)
        assets/data/routes/jeepney_routes_pending.json (route metadata + stop order)
Writes: assets/data/routes/jeepney_routes.json
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "data/geocode_review.json"
PENDING = ROOT / "assets/data/routes/jeepney_routes_pending.json"
OUT = ROOT / "assets/data/routes/jeepney_routes.json"

ROUTE_COLORS = {
    "R1": "#1D3557",
    "R2": "#E63946",
    "R3": "#2A9D8F",
    "R4": "#F72585",
    "R5": "#FB8500",
    "R6": "#FFB703",
    "R7": "#06D6A0",
}

ROUTE_DESCRIPTIONS = {
    "R1": "North Montilla Blvd → City Proper Loop → BCES/ANHS → South Montilla Blvd → J.C. Aquino Ave → Libertad → Bancasi → Crossing Dumalagan (vice versa).",
    "R2": "JAQNO → BCES/ANHS → A.D. Curato St → G. Flores Ave → North Montilla Blvd → Jeepney Terminal → Langihan → Rosales Ave → Libertad → Bancasi → Crossing Dumalagan (vice versa).",
    "R3": "Libertad → JAQNO → FSUU/Plaza → Ampayon Public Market → Ampayon Triangle (vice versa).",
    "R4": "Jeepney Terminal → Rosales Ave → R. Calo St → Sanchez St → M. Calo St → Ampayon → De Oro → JAQNO → R. Calo St → Rosales St → North Montilla Blvd → Jeepney Terminal (vice versa).",
    "R5": "Jeepney Terminal → North Montilla Blvd → JAQNO → T. Sanchez St → M. Calo St → Ampayon → Santo Niño → JAQNO → Rosales St → Langihan Jeepney Terminal (vice versa).",
    "R6": "Capitol Terminal → Guingona Ave → Montilla Blvd → Mahay → Lemon → Maguinda (vice versa).",
    "R7": "Capitol Terminal → Rosales Ave → Montilla Blvd → San Vicente → Tungao (vice versa).",
}


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def pick_coords(entry: dict) -> tuple[float, float] | None:
    if not entry.get("verified"):
        return None
    candidates = entry.get("candidates") or []
    if not candidates:
        return None
    c = candidates[0]
    return float(c["lat"]), float(c["lng"])


def main() -> None:
    review = json.loads(REVIEW.read_text(encoding="utf-8"))
    pending = json.loads(PENDING.read_text(encoding="utf-8"))

    by_id: dict[str, dict] = {s["stop_id"]: s for s in review.get("stops", [])}

    routes_out = []
    skipped: list[str] = []
    flagged_legs: list[str] = []

    for route in pending["routes"]:
        code = route["code"]
        stops_out = []
        coords_line: list[list[float]] = []

        for stop in route.get("ordered_stops", []):
            sid = stop["id"]
            entry = by_id.get(sid)
            if entry is None:
                skipped.append(f"{code}:{sid} (missing from review)")
                continue
            if not entry.get("verified"):
                skipped.append(f"{code}:{sid} ({entry.get('review_notes', 'unverified')[:60]})")
                continue
            latlng = pick_coords(entry)
            if latlng is None:
                skipped.append(f"{code}:{sid} (verified but no candidate)")
                continue
            lat, lng = latlng
            stops_out.append(
                {
                    "id": sid,
                    "name": stop["name"],
                    "lat": round(lat, 7),
                    "lng": round(lng, 7),
                    "verified": True,
                    "aliases": stop.get("aliases", []),
                }
            )
            coords_line.append([lng, lat])

        if len(stops_out) < 2:
            print(f"WARNING: {code} has only {len(stops_out)} verified stops — skipping route")
            continue

        for i in range(len(stops_out) - 1):
            a, b = stops_out[i], stops_out[i + 1]
            straight = haversine_m(a["lat"], a["lng"], b["lat"], b["lng"])
            if straight > 25_000:
                flagged_legs.append(
                    f"{code} {a['name']} → {b['name']}: {straight/1000:.1f} km straight-line (review corridor)"
                )

        routes_out.append(
            {
                "code": code,
                "route_id": route["route_id"],
                "name": route["name"],
                "color": ROUTE_COLORS.get(code, route.get("color", "#333333")),
                "bidirectional": True,
                "termini": route.get("termini", []),
                "street_segments": route.get("street_segments", []),
                "operating_hours": route.get("operating_hours", "5:00 AM – 8:00 PM"),
                "description": ROUTE_DESCRIPTIONS.get(code, route.get("description", "")),
                "ordered_stops": stops_out,
                "corridor_geojson": {
                    "type": "LineString",
                    "coordinates": coords_line,
                },
            }
        )

    out = {
        "ordinance": pending.get("ordinance", "City Ordinance No. 7194-2024 (LPTRP)"),
        "map_version": pending.get("map_version", "2025-10-24"),
        "unserved_road_policy": {
            "behavior": "fallback_to_tricycle_or_walk",
            "source_note": "Not every road is depicted on the official map; unserved destinations require transfer to tricycle or on foot.",
        },
        "routes": routes_out,
    }

    OUT.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    summary = review.get("verification_summary", {})
    print(f"Promoted {len(routes_out)} routes, {sum(len(r['ordered_stops']) for r in routes_out)} verified stops.")
    if summary:
        print(f"Review summary: {summary.get('verified_true', '?')} verified, {summary.get('verified_false', '?')} excluded")
    if skipped:
        print(f"\nExcluded {len(skipped)} stops:")
        for s in skipped:
            print(f"  - {s}")
    if flagged_legs:
        print(f"\nFlagged {len(flagged_legs)} long legs (check OSRM when online):")
        for leg in flagged_legs:
            print(f"  ! {leg}")
    print(f"\nWrote {OUT}")


if __name__ == "__main__":
    main()
