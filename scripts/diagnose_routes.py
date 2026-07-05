#!/usr/bin/env python3
"""Phase 0 diagnostic: dump route data summary."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROD = ROOT / "assets/data/routes/jeepney_routes.json"
REVIEW = ROOT / "data/geocode_review.json"

with open(PROD) as f:
    data = json.load(f)

print("=== PRODUCTION ROUTES ===\n")
for r in data["routes"]:
    stops = r["ordered_stops"]
    verified = [s for s in stops if s.get("verified")]
    coords = r.get("corridor_geojson", {}).get("coordinates", [])
    print(f"=== {r['code']}: {r['name']} ===")
    print(f"  termini: {r.get('termini')}")
    print(f"  verified stops: {len(verified)}/{len(stops)}")
    for s in stops[:3]:
        print(f"    first: {s['name']} ({s.get('lat')}, {s.get('lng')}) v={s.get('verified')}")
    for s in stops[-3:]:
        print(f"    last: {s['name']} ({s.get('lat')}, {s.get('lng')}) v={s.get('verified')}")
    print(f"  corridor points: {len(coords)}")
    print()

print("\n=== PENDING STOPS IN REVIEW ===\n")
with open(REVIEW) as f:
    review = json.load(f)
for s in review.get("stops", []):
    name = s.get("stop_name", "")
    if any(x in name for x in ["City Proper Loop", "Ampayon Triangle", "Santo Niño", "Montilla Drive"]):
        c = (s.get("candidates") or [{}])[0]
        print(f"  {s['stop_id']}: {name}")
        print(f"    verified={s.get('verified')} lat={c.get('lat')} lng={c.get('lng')}")
        print(f"    notes: {s.get('review_notes', '')[:100]}")
        print()
