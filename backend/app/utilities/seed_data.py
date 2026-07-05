"""Seed Butuan transportation data for development."""

import json
from datetime import date

import bcrypt

from app.extensions import db
from app.models.system import Announcement
from app.models.user import User
from app.models.transport import FareMatrix, JeepneyRoute, RouteStop, TricycleZone
from app.models.places import EmergencyContact, Establishment, TouristAttraction

# Representative coordinates around Butuan City (admin-verified data placeholder).
_ROUTE_DEFINITIONS = [
  {
    "route_code": "R1",
    "route_name": "R1 — City Proper to Libertad",
    "color": "#E63946",
    "description": "Serves downtown Butuan and Libertad market area.",
    "operating_hours": "5:00 AM – 8:00 PM",
    "coordinates": [
      [125.5280, 8.9550],
      [125.5320, 8.9510],
      [125.5380, 8.9470],
      [125.5450, 8.9420],
      [125.5520, 8.9380],
    ],
    "stops": [
      ("City Hall Terminal", 8.9550, 125.5280),
      ("Guingona Park", 8.9510, 125.5320),
      ("Montilla Blvd", 8.9470, 125.5380),
      ("Libertad Market", 8.9380, 125.5520),
    ],
  },
  {
    "route_code": "R2",
    "route_name": "R2 — Junction to Robinsons",
    "color": "#F4A261",
    "description": "Connects Baan KM 3 junction to Robinsons Place Butuan.",
    "operating_hours": "5:30 AM – 8:30 PM",
    "coordinates": [
      [125.5350, 8.9600],
      [125.5400, 8.9520],
      [125.5450, 8.9460],
      [125.5500, 8.9400],
    ],
    "stops": [
      ("Baan Junction", 8.9600, 125.5350),
      ("AMPAYON Crossing", 8.9520, 125.5400),
      ("Ong Yiu", 8.9460, 125.5450),
      ("Robinsons Place", 8.9400, 125.5500),
    ],
  },
  {
    "route_code": "R3",
    "route_name": "R3 — Downtown to SM Butuan",
    "color": "#2A9D8F",
    "description": "Main corridor from city center to SM City Butuan.",
    "operating_hours": "6:00 AM – 9:00 PM",
    "coordinates": [
      [125.5300, 8.9530],
      [125.5360, 8.9490],
      [125.5420, 8.9450],
      [125.5480, 8.9410],
      [125.5540, 8.9370],
    ],
    "stops": [
      ("Downtown Terminal", 8.9530, 125.5300),
      ("J.C. Aquino Ave", 8.9490, 125.5360),
      ("Villa Kananga", 8.9450, 125.5420),
      ("SM City Butuan", 8.9370, 125.5540),
    ],
  },
  {
    "route_code": "R4",
    "route_name": "R4 — Agusan Bridge Loop",
    "color": "#457B9D",
    "description": "Crosses Agusan River connecting east and west districts.",
    "operating_hours": "5:00 AM – 7:30 PM",
    "coordinates": [
      [125.5250, 8.9480],
      [125.5320, 8.9460],
      [125.5400, 8.9440],
      [125.5480, 8.9460],
      [125.5520, 8.9500],
    ],
    "stops": [
      ("West Bridge Approach", 8.9480, 125.5250),
      ("Agusan Bridge", 8.9440, 125.5400),
      ("East Side Terminal", 8.9500, 125.5520),
    ],
  },
  {
    "route_code": "R5",
    "route_name": "R5 — Ampayon to City Proper",
    "color": "#8338EC",
    "description": "Serves Ampayon and surrounding residential areas.",
    "operating_hours": "5:00 AM – 8:00 PM",
    "coordinates": [
      [125.5480, 8.9620],
      [125.5440, 8.9550],
      [125.5400, 8.9500],
      [125.5360, 8.9450],
    ],
    "stops": [
      ("Ampayon Terminal", 8.9620, 125.5480),
      ("Baan Km 3", 8.9550, 125.5440),
      ("City Proper", 8.9450, 125.5360),
    ],
  },
  {
    "route_code": "R6",
    "route_name": "R6 — Bancasi Airport Route",
    "color": "#FB5607",
    "description": "Airport connection from city center.",
    "operating_hours": "6:00 AM – 7:00 PM",
    "coordinates": [
      [125.5360, 8.9480],
      [125.5420, 8.9440],
      [125.5500, 8.9380],
      [125.5580, 8.9300],
    ],
    "stops": [
      ("City Center", 8.9480, 125.5360),
      ("Bancasi Road", 8.9380, 125.5500),
      ("Airport Gate", 8.9300, 125.5580),
    ],
  },
  {
    "route_code": "R7",
    "route_name": "R7 — Bayanihan Route",
    "color": "#06D6A0",
    "description": "Serves Bayanihan and nearby barangays.",
    "operating_hours": "5:30 AM – 8:00 PM",
    "coordinates": [
      [125.5320, 8.9420],
      [125.5380, 8.9380],
      [125.5440, 8.9340],
      [125.5500, 8.9300],
    ],
    "stops": [
      ("Bayanihan Terminal", 8.9420, 125.5320),
      ("Doongan", 8.9380, 125.5380),
      ("Bading", 8.9300, 125.5500),
    ],
  },
]

_TRICYCLE_ZONES = [
  {
    "zone_name": "Zone A — City Proper",
    "base_fare": 15.0,
    "notes": "Covers downtown and Guingona Park area.",
    "polygon": [
      [125.5250, 8.9580],
      [125.5550, 8.9580],
      [125.5550, 8.9350],
      [125.5250, 8.9350],
      [125.5250, 8.9580],
    ],
  },
  {
    "zone_name": "Zone B — Libertad",
    "base_fare": 20.0,
    "notes": "Libertad market and surrounding barangays.",
    "polygon": [
      [125.5450, 8.9450],
      [125.5650, 8.9450],
      [125.5650, 8.9280],
      [125.5450, 8.9280],
      [125.5450, 8.9450],
    ],
  },
  {
    "zone_name": "Zone C — Ampayon",
    "base_fare": 25.0,
    "notes": "Ampayon residential and commercial zone.",
    "polygon": [
      [125.5380, 8.9680],
      [125.5600, 8.9680],
      [125.5600, 8.9500],
      [125.5380, 8.9500],
      [125.5380, 8.9680],
    ],
  },
]

_FARES = [
  {"transport_type": "jeepney", "minimum_fare": 13.0, "succeeding_rate": 1.80},
  {"transport_type": "tricycle", "minimum_fare": 15.0, "succeeding_rate": 2.00},
]


def _line_geojson(coordinates: list[list[float]]) -> str:
  return json.dumps(
    {
      "type": "Feature",
      "geometry": {"type": "LineString", "coordinates": coordinates},
      "properties": {},
    }
  )


def _polygon_geojson(coordinates: list[list[float]]) -> str:
  return json.dumps(
    {
      "type": "Feature",
      "geometry": {"type": "Polygon", "coordinates": [coordinates]},
      "properties": {},
    }
  )


def seed_transport_data() -> None:
  """Populate jeepney routes, tricycle zones, and fares if empty."""
  from app.utilities.lptrp_loader import import_lptrp_routes, needs_lptrp_upgrade

  if needs_lptrp_upgrade():
    import_lptrp_routes(force=JeepneyRoute.query.count() > 0)

  if JeepneyRoute.query.count() == 0:
    for route_def in _ROUTE_DEFINITIONS:
      route = JeepneyRoute(
        route_code=route_def["route_code"],
        route_name=route_def["route_name"],
        color=route_def["color"],
        description=route_def["description"],
        operating_hours=route_def["operating_hours"],
        geojson=_line_geojson(route_def["coordinates"]),
        active_status=True,
      )
      db.session.add(route)
      db.session.flush()

      for order, (name, lat, lng) in enumerate(route_def["stops"], start=1):
        db.session.add(
          RouteStop(
            route_id=route.route_id,
            stop_name=name,
            latitude=lat,
            longitude=lng,
            stop_order=order,
          )
        )

  if TricycleZone.query.count() == 0:
    for zone_def in _TRICYCLE_ZONES:
      db.session.add(
        TricycleZone(
          zone_name=zone_def["zone_name"],
          polygon_geojson=_polygon_geojson(zone_def["polygon"]),
          base_fare=zone_def["base_fare"],
          notes=zone_def["notes"],
          active_status=True,
        )
      )

  if FareMatrix.query.count() == 0:
    today = date.today()
    for fare_def in _FARES:
      db.session.add(
        FareMatrix(
          transport_type=fare_def["transport_type"],
          minimum_fare=fare_def["minimum_fare"],
          succeeding_rate=fare_def["succeeding_rate"],
          effective_date=today,
        )
      )

  db.session.commit()


_ATTRACTIONS = [
  {
    "name": "Balangay Shrine Museum",
    "description": "Home to the oldest known balangay boats in the Philippines, showcasing Butuan's maritime heritage.",
    "address": "Brgy. Libertad, Butuan City",
    "latitude": 8.9385,
    "longitude": 125.5455,
    "entrance_fee": "₱50",
    "opening_hours": "9:00 AM – 5:00 PM",
    "category": "museum",
    "contact_information": "(085) 342-1234",
  },
  {
    "name": "Butuan National Museum",
    "description": "Exhibits archaeological finds and cultural artifacts from Agusan del Norte.",
    "address": "Jose S. Aquino Ave, Butuan City",
    "latitude": 8.9490,
    "longitude": 125.5360,
    "entrance_fee": "Free",
    "opening_hours": "8:00 AM – 5:00 PM",
    "category": "museum",
    "contact_information": "(085) 225-7924",
  },
  {
    "name": "Guingona Park",
    "description": "Historic park in the heart of downtown Butuan, popular for leisure and events.",
    "address": "J.C. Aquino Ave, Butuan City",
    "latitude": 8.9510,
    "longitude": 125.5320,
    "entrance_fee": "Free",
    "opening_hours": "Open 24 hours",
    "category": "park",
    "contact_information": None,
  },
  {
    "name": "Delta Discovery Park",
    "description": "Nature park along the Agusan River with walking trails and river views.",
    "address": "Brgy. Bonbon, Butuan City",
    "latitude": 8.9620,
    "longitude": 125.5280,
    "entrance_fee": "₱30",
    "opening_hours": "7:00 AM – 6:00 PM",
    "category": "park",
    "contact_information": None,
  },
]

_ESTABLISHMENTS = [
  ("Robinsons Place Butuan", "shopping_center", 8.9400, 125.5500, "Robinsons Place, J.C. Aquino Ave"),
  ("SM City Butuan", "shopping_center", 8.9370, 125.5540, "J.C. Aquino Ave, Butuan City"),
  ("Butuan Medical Center", "hospital", 8.9480, 125.5380, "J.C. Aquino Ave, Butuan City"),
  ("Caraga Regional Hospital", "hospital", 8.9530, 125.5290, "Rizal St, Butuan City"),
  ("Butuan City Police Station", "police", 8.9505, 125.5335, "City Hall Complex, Butuan City"),
  ("BFP Butuan City", "fire", 8.9500, 125.5340, "City Hall Complex, Butuan City"),
  ("Mercury Drug - Downtown", "pharmacy", 8.9495, 125.5355, "Montilla Blvd, Butuan City"),
  ("Hotel Almont", "hotel", 8.9460, 125.5410, "J.C. Aquino Ave, Butuan City"),
  ("Aling Fopings Panciteria", "restaurant", 8.9500, 125.5365, "Downtown, Butuan City"),
  ("City Hall of Butuan", "government", 8.9515, 125.5315, "City Hall Complex, Butuan City"),
  ("BDO ATM - Robinsons", "atm", 8.9402, 125.5502, "Robinsons Place Butuan"),
  ("Petron Gas Station", "gas_station", 8.9440, 125.5470, "J.C. Aquino Ave, Butuan City"),
  ("7-Eleven Montilla", "convenience_store", 8.9485, 125.5375, "Montilla Blvd, Butuan City"),
]

_EMERGENCY = [
  ("Philippine National Police", "911", "police", "8.9505", "125.5335", "24/7"),
  ("Bureau of Fire Protection", "911", "fire", "8.9500", "125.5340", "24/7"),
  ("Butuan Medical Center", "(085) 342-0123", "hospital", "8.9480", "125.5380", "24/7"),
  ("Caraga Regional Hospital", "(085) 225-8001", "hospital", "8.9530", "125.5290", "24/7"),
  ("Butuan City Disaster Risk Reduction", "(085) 342-5600", "disaster", None, None, "24/7"),
  ("Butuan City Tourism Office", "(085) 342-0256", "tourism", "8.9515", "125.5315", "Mon–Fri 8AM–5PM"),
]


def seed_places_data() -> None:
  """Populate tourism, establishments, and emergency contacts if empty."""
  if TouristAttraction.query.count() > 0:
    return

  for item in _ATTRACTIONS:
    db.session.add(TouristAttraction(**item, images="[]"))

  for name, category, lat, lng, address in _ESTABLISHMENTS:
    db.session.add(
      Establishment(
        name=name,
        category=category,
        latitude=lat,
        longitude=lng,
        address=address,
        active_status=True,
      )
    )

  for agency, hotline, category, lat, lng, availability in _EMERGENCY:
    db.session.add(
      EmergencyContact(
        agency=agency,
        hotline=hotline,
        category=category,
        latitude=float(lat) if lat else None,
        longitude=float(lng) if lng else None,
        availability=availability,
        active_status=True,
      )
    )

  db.session.commit()


def seed_admin_user() -> None:
  """Create default administrator account for development."""
  email = "admin@pinpoint.local"
  if User.query.filter_by(email=email).first():
    return
  password_hash = bcrypt.hashpw(b"AdminPass1", bcrypt.gensalt()).decode("utf-8")
  db.session.add(
    User(
      full_name="PINPOINT Administrator",
      email=email,
      password_hash=password_hash,
      role="admin",
    )
  )
  db.session.commit()


def seed_system_data() -> None:
  """Seed announcements for notifications and home feed."""
  if Announcement.query.count() > 0:
    return
  db.session.add(
    Announcement(
      title="Welcome to PINPOINT",
      content="Your official digital mobility companion for Butuan City jeepney routes, fares, and tourism.",
      category="general",
      priority="normal",
      active_status=True,
    )
  )
  db.session.add(
    Announcement(
      title="Fare Update Reminder",
      content="Jeepney and tricycle fares follow the latest administrator-published fare matrix in the app.",
      category="transport",
      priority="high",
      active_status=True,
    )
  )
  db.session.commit()
