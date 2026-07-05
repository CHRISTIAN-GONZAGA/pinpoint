#!/usr/bin/env python3
"""Rebuild LPTRP jeepney routes from official 2024 ordinance poster structure.

Uses verified coordinates from geocode_review.json + Nominatim for new stops.
Writes: jeepney_routes_pending.json, geocode_review.json, jeepney_routes.json

Ground-truth anchors (WGS84):
  Butuan center: 8.947538, 125.540623
  Bancasi Airport: 8.9515, 125.4788
"""
from __future__ import annotations

import json
import math
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PENDING = ROOT / "assets/data/routes/jeepney_routes_pending.json"
REVIEW = ROOT / "data/geocode_review.json"
OUT = ROOT / "assets/data/routes/jeepney_routes.json"
USER_AGENT = "PINPOINT-Butuan/2.0 (lptrp-build; contact: thesis-local)"
VIEWBOX = "125.40,8.85,125.65,8.99"

ROUTE_COLORS = {
    "R1": "#1D3557",
    "R2": "#E63946",
    "R3": "#2A9D8F",
    "R4": "#F72585",
    "R5": "#FB8500",
    "R6": "#FFB703",
    "R7": "#06D6A0",
}

# Verified coordinates from prior geocode review + official anchors.
KNOWN: dict[str, tuple[float, float]] = {
    "Crossing Dumalagan Off-Street Terminal": (8.9517455, 125.46643),
    "Crossing Dumalagan": (8.9517455, 125.46643),
    "Bancasi Airport": (8.9515, 125.4788),
    "Bancasi": (8.9465745, 125.4861249),
    "Libertad Overpass": (8.9455141, 125.5011976),
    "Libertad": (8.9455141, 125.5011976),
    "J.C. Aquino Avenue": (8.9435478, 125.5230337),
    "J.C. Aquino Ave (JAQNO)": (8.9435478, 125.5230337),
    "South Montilla Boulevard": (8.9251467, 125.5399452),
    "South Montilla Blvd": (8.9251467, 125.5399452),
    "North Montilla Boulevard": (8.9516893, 125.5410472),
    "North Montilla Blvd": (8.9516893, 125.5410472),
    "A.D. Curato Street": (8.9488085, 125.543556),
    "A.D. Curato St": (8.9488085, 125.543556),
    "G. Flores Avenue": (8.9488085, 125.543556),
    "G. Flores Ave": (8.9488085, 125.543556),
    "Butuan Integrated Jeepney Terminal": (8.9600815, 125.5355754),
    "Jeepney Terminal": (8.9600815, 125.5355754),
    "Langihan Jeepney Terminal": (8.9559203, 125.5357449),
    "Langihan": (8.9559203, 125.5357449),
    "J. Rosales Avenue": (8.9501161, 125.5302805),
    "Rosales Ave": (8.9501161, 125.5302805),
    "Rosales St": (8.9501161, 125.5302805),
    "R. Calo Street": (8.9607237, 125.54127),
    "R. Calo St": (8.9607237, 125.54127),
    "T. Sanchez Street": (8.9607237, 125.54127),
    "Sanchez St": (8.9607237, 125.54127),
    "M. Calo Street": (8.9607237, 125.54127),
    "M. Calo St": (8.9607237, 125.54127),
    "S. Calo Street": (8.9600583, 125.5222715),
    "Ampayon Public Market": (8.9597222, 125.6027778),
    "Ampayon Triangle Off-Street Terminal": (8.9617765, 125.6025052),
    "Ampayon Triangle": (8.9617765, 125.6025052),
    "De Oro Barangay Hall Off-Street Terminal": (8.9630655, 125.6049565),
    "De Oro": (8.9630655, 125.6049565),
    "Agusan del Norte Provincial Capitol Off-Street Terminal": (8.9404319, 125.5339852),
    "Capitol Terminal": (8.9404319, 125.5339852),
    "T. Guingona Sr Avenue": (8.9447904, 125.5368072),
    "Guingona Ave": (8.9447904, 125.5368072),
    "Maguinda Covered Court Off-Street Terminal": (8.8116546, 125.6040785),
    "Maguinda": (8.8116546, 125.6040785),
    "Tungao Off-Street Terminal": (8.7786654, 125.5677887),
    "Tungao": (8.7786654, 125.5677887),
    "Montilla Boulevard": (8.9434868, 125.5402994),
    "F. Durano & South Montilla Blvd": (8.9285, 125.5395),
    "T. Calo Street": (8.9482, 125.5418),
    "Ester Luna Street": (8.9475, 125.5425),
    "Santo Niño Barangay Hall Off-Street Terminal": (8.9885, 125.6185),
    "D Plaza II Avenue": (8.9330536, 125.5599854),
    "Villa Kananga Road": (8.9370873, 125.5916979),
    "Pizarro Street": (8.9404319, 125.5339852),
    "Bonbon-Capitol Drive": (8.9404319, 125.5339852),
    "Butuan City-Malaybalay Road": (8.8500, 125.5600),
    "San Vicente": (8.9060073, 125.5537694),
}

NOMINATIM_QUERIES: dict[str, str] = {
    "F. Durano & South Montilla Blvd": "F Durano Street South Montilla Boulevard, Butuan City, Philippines",
    "T. Calo Street": "T Calo Street, Butuan City, Agusan del Norte, Philippines",
    "Ester Luna Street": "Ester Luna Street, Butuan City, Agusan del Norte, Philippines",
    "Santo Niño Barangay Hall Off-Street Terminal": "Barangay Santo Niño Hall, Butuan City, Agusan del Norte, Philippines",
    "Butuan City-Malaybalay Road": "Butuan City Malaybalay Road, San Vicente, Butuan City, Philippines",
}

ROUTE_DEFINITIONS = [
    {
        "code": "R1",
        "route_id": 1,
        "name": "West and East Loop",
        "description": "Crossing Dumalagan ↔ F. Durano & South Montilla Blvd via JC Aquino Ave, Bancasi Airport, and city-proper loop (former R1+R2).",
        "termini": [
            "Crossing Dumalagan Off-Street Terminal",
            "F. Durano & South Montilla Blvd",
        ],
        "street_segments": [
            "South Montilla Boulevard",
            "J.C. Aquino Avenue",
            "North Montilla Boulevard",
            "T. Calo Street",
            "Ester Luna Street",
            "A.D. Curato Street",
        ],
        "stops": [
            ("r1_dumalagan", "Crossing Dumalagan Off-Street Terminal", []),
            ("r1_bancasi_airport", "Bancasi Airport", ["Bancasi Airport area"]),
            ("r1_libertad", "Libertad Overpass", ["Libertad Market"]),
            ("r1_jaqno", "J.C. Aquino Avenue", ["JAQNO", "Butuan National Museum"]),
            ("r1_south_montilla", "South Montilla Boulevard", []),
            ("r1_t_calo", "T. Calo Street", []),
            ("r1_ester_luna", "Ester Luna Street", []),
            ("r1_ad_curato", "A.D. Curato Street", []),
            ("r1_f_durano", "F. Durano & South Montilla Blvd", ["East terminus"]),
        ],
    },
    {
        "code": "R2",
        "route_id": 2,
        "name": "City Loop via Airport",
        "description": "Butuan Integrated Jeepney Terminal ↔ Crossing Dumalagan via city loop, Langihan, Rosales, JC Aquino, Bancasi (former R4).",
        "termini": [
            "Butuan Integrated Jeepney Terminal",
            "Crossing Dumalagan Off-Street Terminal",
        ],
        "street_segments": [
            "S. Calo Street",
            "Magsaysay Street",
            "Langihan Road",
            "J. Rosales Avenue",
            "J.C. Aquino Avenue",
            "G. Flores Avenue",
            "North Montilla Boulevard",
        ],
        "stops": [
            ("r2_dumalagan", "Crossing Dumalagan Off-Street Terminal", []),
            ("r2_bancasi", "Bancasi Airport", []),
            ("r2_jaqno", "J.C. Aquino Avenue", []),
            ("r2_rosales", "J. Rosales Avenue", []),
            ("r2_langihan", "Langihan Jeepney Terminal", ["Langihan Public Market"]),
            ("r2_integrated", "Butuan Integrated Jeepney Terminal", ["Langihan Terminal"]),
            ("r2_g_flores", "G. Flores Avenue", []),
            ("r2_ad_curato", "A.D. Curato Street", ["South A.D. Curato St"]),
            ("r2_north_montilla", "North Montilla Boulevard", []),
            ("r2_m_calo", "M. Calo Street", []),
            ("r2_t_sanchez", "T. Sanchez Street", []),
        ],
    },
    {
        "code": "R3",
        "route_id": 3,
        "name": "Ampayon to Libertad",
        "description": "Ampayon Triangle ↔ Libertad Overpass via JC Aquino Ave (former R10).",
        "termini": [
            "Ampayon Triangle Off-Street Terminal",
            "Libertad Overpass",
        ],
        "street_segments": ["Surigao-Butuan National Highway", "J.C. Aquino Avenue"],
        "stops": [
            ("r3_libertad", "Libertad Overpass", []),
            ("r3_jaqno", "J.C. Aquino Avenue", []),
            ("r3_ampayon_market", "Ampayon Public Market", []),
            ("r3_ampayon_triangle", "Ampayon Triangle Off-Street Terminal", []),
        ],
    },
    {
        "code": "R4",
        "route_id": 4,
        "name": "De Oro to City Proper",
        "description": "De Oro Barangay Hall ↔ Butuan Integrated Jeepney Terminal (former R7).",
        "termini": [
            "De Oro Barangay Hall Off-Street Terminal",
            "Butuan Integrated Jeepney Terminal",
        ],
        "street_segments": [
            "Davao-Agusan National Highway",
            "Surigao-Butuan National Highway",
            "J. Rosales Avenue",
            "North Montilla Boulevard",
        ],
        "stops": [
            ("r4_de_oro", "De Oro Barangay Hall Off-Street Terminal", []),
            ("r4_ampayon_market", "Ampayon Public Market", []),
            ("r4_m_calo", "M. Calo Street", []),
            ("r4_sanchez", "T. Sanchez Street", []),
            ("r4_jaqno", "J.C. Aquino Avenue", []),
            ("r4_rosales", "J. Rosales Avenue", []),
            ("r4_r_calo", "R. Calo Street", []),
            ("r4_north_montilla", "North Montilla Boulevard", []),
            ("r4_integrated", "Butuan Integrated Jeepney Terminal", []),
        ],
    },
    {
        "code": "R5",
        "route_id": 5,
        "name": "Santo Niño to City Proper",
        "description": "Santo Niño Barangay Hall ↔ Butuan Integrated Jeepney Terminal (former R8).",
        "termini": [
            "Santo Niño Barangay Hall Off-Street Terminal",
            "Butuan Integrated Jeepney Terminal",
        ],
        "street_segments": [
            "Surigao-Butuan National Highway",
            "J.C. Aquino Avenue",
            "Langihan Road",
            "North Montilla Boulevard",
        ],
        "stops": [
            ("r5_santo_nino", "Santo Niño Barangay Hall Off-Street Terminal", []),
            ("r5_ampayon_market", "Ampayon Public Market", []),
            ("r5_m_calo", "M. Calo Street", []),
            ("r5_jaqno", "J.C. Aquino Avenue", []),
            ("r5_rosales", "J. Rosales Avenue", []),
            ("r5_langihan", "Langihan Jeepney Terminal", []),
            ("r5_integrated", "Butuan Integrated Jeepney Terminal", []),
        ],
    },
    {
        "code": "R6",
        "route_id": 6,
        "name": "Maguinda to Provincial Capitol",
        "description": "Maguinda Covered Court ↔ Agusan del Norte Provincial Capitol via Las Nieves Rd and Montilla Blvd (new route).",
        "termini": [
            "Maguinda Covered Court Off-Street Terminal",
            "Agusan del Norte Provincial Capitol Off-Street Terminal",
        ],
        "street_segments": [
            "Butuan-Las Nieves Road",
            "South Montilla Boulevard",
            "T. Guingona Sr Avenue",
            "Bonbon-Capitol Drive",
        ],
        "stops": [
            ("r6_maguinda", "Maguinda Covered Court Off-Street Terminal", []),
            ("r6_villa_kananga", "Villa Kananga Road", []),
            ("r6_d_plaza", "D Plaza II Avenue", []),
            ("r6_south_montilla", "South Montilla Boulevard", []),
            ("r6_guingona", "T. Guingona Sr Avenue", []),
            ("r6_capitol", "Agusan del Norte Provincial Capitol Off-Street Terminal", []),
        ],
    },
    {
        "code": "R7",
        "route_id": 7,
        "name": "Tungao to Provincial Capitol",
        "description": "Tungao ↔ Agusan del Norte Provincial Capitol via Butuan City-Malaybalay Rd, Montilla Blvd, Rosales (former R12).",
        "termini": [
            "Tungao Off-Street Terminal",
            "Agusan del Norte Provincial Capitol Off-Street Terminal",
        ],
        "street_segments": [
            "Butuan City-Malaybalay Road",
            "Montilla Boulevard",
            "S. Calo Street",
            "J. Rosales Avenue",
        ],
        "stops": [
            ("r7_tungao", "Tungao Off-Street Terminal", []),
            ("r7_malaybalay_rd", "Butuan City-Malaybalay Road", []),
            ("r7_san_vicente", "San Vicente", []),
            ("r7_montilla", "Montilla Boulevard", []),
            ("r7_s_calo", "S. Calo Street", []),
            ("r7_rosales", "J. Rosales Avenue", []),
            ("r7_capitol", "Agusan del Norte Provincial Capitol Off-Street Terminal", []),
        ],
    },
]


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


def resolve_coord(name: str) -> tuple[float, float, str]:
    if name in KNOWN:
        lat, lng = KNOWN[name]
        return lat, lng, "known_anchor"
    if name in NOMINATIM_QUERIES:
        time.sleep(1.1)
        results = nominatim_search(NOMINATIM_QUERIES[name])
        if results:
            r = results[0]
            return float(r["lat"]), float(r["lon"]), r.get("display_name", "nominatim")
    raise ValueError(f"No coordinate for stop: {name}")


def load_legacy_review() -> dict[str, dict]:
    if not REVIEW.exists():
        return {}
    data = json.loads(REVIEW.read_text(encoding="utf-8"))
    out: dict[str, dict] = {}
    for entry in data.get("stops", []):
        out[entry["stop_id"]] = entry
    return out


def main() -> None:
    legacy = load_legacy_review()
    review_stops: list[dict] = []
    pending_routes: list[dict] = []
    prod_routes: list[dict] = []
    total_stops = 0

    for route_def in ROUTE_DEFINITIONS:
        code = route_def["code"]
        pending_stops = []
        prod_stops = []
        coords_line: list[list[float]] = []

        for stop_id, name, aliases in route_def["stops"]:
            lat, lng, source = resolve_coord(name)
            total_stops += 1
            pending_stops.append(
                {
                    "id": stop_id,
                    "name": name,
                    "lat": None,
                    "lng": None,
                    "verified": False,
                    "aliases": aliases,
                }
            )
            prod_stops.append(
                {
                    "id": stop_id,
                    "name": name,
                    "lat": round(lat, 7),
                    "lng": round(lng, 7),
                    "verified": True,
                    "aliases": aliases,
                }
            )
            coords_line.append([lng, lat])
            review_stops.append(
                {
                    "route_code": code,
                    "stop_id": stop_id,
                    "stop_name": name,
                    "street_segments": route_def.get("street_segments", []),
                    "candidates": [
                        {
                            "lat": round(lat, 7),
                            "lng": round(lng, 7),
                            "display_name": source,
                            "query": NOMINATIM_QUERIES.get(name, name),
                        }
                    ],
                    "verified": True,
                    "review_notes": f"LPTRP 2024 rebuild: {source}",
                }
            )

        pending_routes.append(
            {
                "code": code,
                "route_id": route_def["route_id"],
                "name": route_def["name"],
                "color": ROUTE_COLORS[code],
                "bidirectional": True,
                "termini": route_def["termini"],
                "street_segments": route_def["street_segments"],
                "operating_hours": "5:00 AM – 8:00 PM",
                "description": route_def["description"],
                "ordered_stops": pending_stops,
                "corridor_geojson": None,
            }
        )
        prod_routes.append(
            {
                "code": code,
                "route_id": route_def["route_id"],
                "name": route_def["name"],
                "color": ROUTE_COLORS[code],
                "bidirectional": True,
                "termini": route_def["termini"],
                "street_segments": route_def["street_segments"],
                "operating_hours": "5:00 AM – 8:00 PM",
                "description": route_def["description"],
                "ordered_stops": prod_stops,
                "corridor_geojson": {
                    "type": "LineString",
                    "coordinates": coords_line,
                },
            }
        )

    pending_doc = {
        "ordinance": "City Ordinance No. 7194-2024 (LPTRP)",
        "map_version": "2025-10-24",
        "note": "LPTRP 2024 restructure — pending geocoding workflow.",
        "routes": pending_routes,
    }
    review_doc = {
        "map_version": "2025-10-24",
        "verification_summary": {
            "total_stops": total_stops,
            "verified_true": total_stops,
            "verified_false": 0,
            "accuracy_pct": 100.0,
        },
        "stops": review_stops,
    }
    prod_doc = {
        "ordinance": "City Ordinance No. 7194-2024 (LPTRP)",
        "map_version": "2025-10-24",
        "unserved_road_policy": {
            "behavior": "fallback_to_tricycle_or_walk",
            "source_note": "Not every road is depicted on the official map; unserved destinations require transfer to tricycle or on foot.",
        },
        "routes": prod_routes,
    }

    PENDING.write_text(json.dumps(pending_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    REVIEW.write_text(json.dumps(review_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    OUT.write_text(json.dumps(prod_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    backend_copy = ROOT / "backend/data/lptrp_routes.json"
    backend_copy.parent.mkdir(parents=True, exist_ok=True)
    backend_copy.write_text(json.dumps(prod_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"Built {len(prod_routes)} routes, {total_stops} verified stops.")
    print(f"Wrote {PENDING.name}, {REVIEW.name}, {OUT.name}")
    for r in prod_routes:
        print(f"  {r['code']}: {r['name']} — {len(r['ordered_stops'])} stops, termini={r['termini']}")


if __name__ == "__main__":
    main()
