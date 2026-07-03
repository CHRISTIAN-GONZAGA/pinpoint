"""Export PINPOINT seed data to Flutter asset JSON files."""

from __future__ import annotations

import json
from pathlib import Path

from app.utilities.seed_data import (
  _ATTRACTIONS,
  _EMERGENCY,
  _ESTABLISHMENTS,
  _FARES,
  _ROUTE_DEFINITIONS,
  _TRICYCLE_ZONES,
  _line_geojson,
  _polygon_geojson,
)


def _routes() -> list[dict]:
  routes: list[dict] = []
  for index, route_def in enumerate(_ROUTE_DEFINITIONS, start=1):
    stops = []
    for order, (name, lat, lng) in enumerate(route_def["stops"], start=1):
      stops.append(
        {
          "stop_id": index * 10 + order,
          "route_id": index,
          "stop_name": name,
          "latitude": lat,
          "longitude": lng,
          "stop_order": order,
        }
      )
    routes.append(
      {
        "route_id": index,
        "route_code": route_def["route_code"],
        "route_name": route_def["route_name"],
        "color": route_def["color"],
        "description": route_def["description"],
        "operating_hours": route_def["operating_hours"],
        "geojson": json.loads(_line_geojson(route_def["coordinates"])),
        "active_status": True,
        "stops": stops,
      }
    )
  return routes


def _zones() -> list[dict]:
  zones: list[dict] = []
  for index, zone_def in enumerate(_TRICYCLE_ZONES, start=1):
    zones.append(
      {
        "zone_id": index,
        "zone_name": zone_def["zone_name"],
        "polygon_geojson": json.loads(_polygon_geojson(zone_def["polygon"])),
        "base_fare": zone_def["base_fare"],
        "notes": zone_def["notes"],
        "active_status": True,
      }
    )
  return zones


def _fares() -> list[dict]:
  fares: list[dict] = []
  for index, fare_def in enumerate(_FARES, start=1):
    fares.append(
      {
        "fare_id": index,
        "transport_type": fare_def["transport_type"],
        "minimum_fare": fare_def["minimum_fare"],
        "succeeding_rate": fare_def["succeeding_rate"],
        "effective_date": "2026-01-01",
      }
    )
  return fares


def _attractions() -> list[dict]:
  items: list[dict] = []
  for index, item in enumerate(_ATTRACTIONS, start=1):
    payload = dict(item)
    payload["attraction_id"] = index
    payload["place_type"] = "attraction"
    payload["images"] = []
    items.append(payload)
  return items


def _establishments() -> list[dict]:
  items: list[dict] = []
  for index, (name, category, lat, lng, address) in enumerate(_ESTABLISHMENTS, start=1):
    items.append(
      {
        "establishment_id": index,
        "place_type": "establishment",
        "name": name,
        "category": category,
        "latitude": lat,
        "longitude": lng,
        "address": address,
        "active_status": True,
      }
    )
  return items


def _emergency() -> list[dict]:
  items: list[dict] = []
  for index, (agency, hotline, category, lat, lng, availability) in enumerate(_EMERGENCY, start=1):
    items.append(
      {
        "contact_id": index,
        "agency": agency,
        "hotline": hotline,
        "category": category,
        "latitude": float(lat) if lat else None,
        "longitude": float(lng) if lng else None,
        "availability": availability,
        "active_status": True,
      }
    )
  return items


def _knowledge() -> list[dict]:
  return [
    {
      "id": "routes-overview",
      "category": "transport",
      "keywords": ["jeep", "jeepney", "route", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "saan", "which"],
      "title": "Jeepney Routes",
      "content_en": "PINPOINT covers official Butuan jeepney routes R1 through R7, including City Proper, Libertad, Robinsons, SM City Butuan, Ampayon, Bancasi Airport, and Bayanihan corridors.",
      "content_tl": "Saklaw ng PINPOINT ang opisyal na ruta ng jeepney R1 hanggang R7 sa Butuan, kasama ang City Proper, Libertad, Robinsons, SM City Butuan, Ampayon, Bancasi Airport, at Bayanihan.",
      "content_ceb": "Gisakop sa PINPOINT ang opisyal nga ruta sa jeepney R1 hangtod R7 sa Butuan, apil ang City Proper, Libertad, Robinsons, SM City Butuan, Ampayon, Bancasi Airport, ug Bayanihan.",
    },
    {
      "id": "fares",
      "category": "transport",
      "keywords": ["fare", "pamasahe", "magkano", "presyo", "how much", "bayad"],
      "title": "Fare Matrix",
      "content_en": "Jeepney minimum fare is PHP 13.00 with PHP 1.80 per succeeding kilometer. Tricycle base fares start at PHP 15–25 depending on the zone.",
      "content_tl": "Ang minimum na pamasahe sa jeepney ay PHP 13.00 at PHP 1.80 bawat susunod na kilometro. Ang tricycle ay nagsisimula sa PHP 15–25 depende sa zone.",
      "content_ceb": "Ang minimum nga pamasahe sa jeepney kay PHP 13.00 ug PHP 1.80 kada sunod nga kilometro. Ang tricycle nagsugod sa PHP 15–25 depende sa zone.",
    },
    {
      "id": "emergency",
      "category": "emergency",
      "keywords": ["emergency", "911", "hospital", "police", "fire", "tulong", "emergency number"],
      "title": "Emergency Contacts",
      "content_en": "Dial 911 for police and fire emergencies. Butuan Medical Center: (085) 342-0123. Caraga Regional Hospital: (085) 225-8001.",
      "content_tl": "Tumawag sa 911 para sa pulisya at bumbero. Butuan Medical Center: (085) 342-0123. Caraga Regional Hospital: (085) 225-8001.",
      "content_ceb": "Tawagi ang 911 para sa pulisya ug bombero. Butuan Medical Center: (085) 342-0123. Caraga Regional Hospital: (085) 225-8001.",
    },
    {
      "id": "tourism",
      "category": "tourism",
      "keywords": ["tourist", "attraction", "museum", "park", "libot", "bisita", "spot"],
      "title": "Tourist Attractions",
      "content_en": "Popular spots include Balangay Shrine Museum, Butuan National Museum, Guingona Park, and Delta Discovery Park.",
      "content_tl": "Kasama sa mga sikat na lugar ang Balangay Shrine Museum, Butuan National Museum, Guingona Park, at Delta Discovery Park.",
      "content_ceb": "Apil sa sikat nga lugar ang Balangay Shrine Museum, Butuan National Museum, Guingona Park, ug Delta Discovery Park.",
    },
    {
      "id": "sm-robinsons",
      "category": "transport",
      "keywords": ["sm", "robinsons", "mall", "shopping"],
      "title": "Mall Routes",
      "content_en": "Route R2 serves Robinsons Place Butuan. Route R3 serves SM City Butuan from downtown.",
      "content_tl": "Ang Ruta R2 ay papunta sa Robinsons Place Butuan. Ang Ruta R3 ay papunta sa SM City Butuan mula downtown.",
      "content_ceb": "Ang Ruta R2 moagi sa Robinsons Place Butuan. Ang Ruta R3 moagi sa SM City Butuan gikan sa downtown.",
    },
  ]


def _announcements() -> list[dict]:
  return [
    {
      "announcement_id": 1,
      "title": "Welcome to PINPOINT",
      "content": "Your official digital mobility companion for Butuan City jeepney routes, fares, and tourism.",
      "category": "general",
      "priority": "normal",
      "active_status": True,
    },
    {
      "announcement_id": 2,
      "title": "Offline Mode Active",
      "content": "Core PINPOINT features run locally on your device. Connect to the server later for cloud sync.",
      "category": "general",
      "priority": "high",
      "active_status": True,
    },
  ]


def main() -> None:
  root = Path(__file__).resolve().parents[2] / "assets" / "data"
  root.mkdir(parents=True, exist_ok=True)

  files = {
    "routes/jeepney_routes.json": {"routes": _routes()},
    "transport/tricycle_zones.json": {"zones": _zones()},
    "transport/fares.json": {"fares": _fares()},
    "tourism/attractions.json": {"attractions": _attractions()},
    "tourism/establishments.json": {"establishments": _establishments()},
    "emergency/emergency.json": {"contacts": _emergency()},
    "knowledge/knowledge_base.json": {"documents": _knowledge()},
    "system/announcements.json": {"announcements": _announcements()},
  }

  for relative, payload in files.items():
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Wrote {path}")


if __name__ == "__main__":
  main()
