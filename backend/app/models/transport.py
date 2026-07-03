"""Transportation and fare database models."""

import json
from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class JeepneyRoute(db.Model):
  """Official jeepney route (R1–R7)."""

  __tablename__ = "jeepney_routes"

  route_id = db.Column(db.Integer, primary_key=True)
  route_code = db.Column(db.String(10), unique=True, nullable=False, index=True)
  route_name = db.Column(db.String(120), nullable=False)
  color = db.Column(db.String(20), nullable=False)
  description = db.Column(db.Text, nullable=True)
  operating_hours = db.Column(db.String(80), nullable=True)
  geojson = db.Column(db.Text, nullable=False)
  active_status = db.Column(db.Boolean, nullable=False, default=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  updated_at = db.Column(
    db.DateTime, nullable=False, default=utcnow, onupdate=utcnow
  )

  stops = db.relationship(
    "RouteStop", back_populates="route", cascade="all, delete-orphan"
  )

  def to_dict(self, include_stops: bool = True) -> dict:
    data = {
      "route_id": self.route_id,
      "route_code": self.route_code,
      "route_name": self.route_name,
      "color": self.color,
      "description": self.description,
      "operating_hours": self.operating_hours,
      "geojson": json.loads(self.geojson),
      "active_status": self.active_status,
    }
    if include_stops:
      data["stops"] = [stop.to_dict() for stop in self.stops]
    return data


class RouteStop(db.Model):
  """Jeepney route stop."""

  __tablename__ = "route_stops"

  stop_id = db.Column(db.Integer, primary_key=True)
  route_id = db.Column(
    db.Integer, db.ForeignKey("jeepney_routes.route_id"), nullable=False
  )
  stop_name = db.Column(db.String(120), nullable=False)
  latitude = db.Column(db.Float, nullable=False)
  longitude = db.Column(db.Float, nullable=False)
  stop_order = db.Column(db.Integer, nullable=False)

  route = db.relationship("JeepneyRoute", back_populates="stops")

  def to_dict(self) -> dict:
    return {
      "stop_id": self.stop_id,
      "route_id": self.route_id,
      "stop_name": self.stop_name,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "stop_order": self.stop_order,
    }


class TricycleZone(db.Model):
  """Tricycle service zone polygon."""

  __tablename__ = "tricycle_zones"

  zone_id = db.Column(db.Integer, primary_key=True)
  zone_name = db.Column(db.String(120), nullable=False)
  polygon_geojson = db.Column(db.Text, nullable=False)
  base_fare = db.Column(db.Float, nullable=False)
  notes = db.Column(db.Text, nullable=True)
  active_status = db.Column(db.Boolean, nullable=False, default=True)

  def to_dict(self) -> dict:
    return {
      "zone_id": self.zone_id,
      "zone_name": self.zone_name,
      "polygon_geojson": json.loads(self.polygon_geojson),
      "base_fare": self.base_fare,
      "notes": self.notes,
      "active_status": self.active_status,
    }


class FareMatrix(db.Model):
  """Administrator-maintained fare configuration."""

  __tablename__ = "fare_matrix"

  fare_id = db.Column(db.Integer, primary_key=True)
  transport_type = db.Column(db.String(30), nullable=False)
  minimum_fare = db.Column(db.Float, nullable=False)
  succeeding_rate = db.Column(db.Float, nullable=False, default=0)
  student_discount = db.Column(db.Float, nullable=False, default=0.2)
  senior_discount = db.Column(db.Float, nullable=False, default=0.2)
  pwd_discount = db.Column(db.Float, nullable=False, default=0.2)
  effective_date = db.Column(db.Date, nullable=False)

  def to_dict(self) -> dict:
    return {
      "fare_id": self.fare_id,
      "transport_type": self.transport_type,
      "minimum_fare": self.minimum_fare,
      "succeeding_rate": self.succeeding_rate,
      "student_discount": self.student_discount,
      "senior_discount": self.senior_discount,
      "pwd_discount": self.pwd_discount,
      "effective_date": self.effective_date.isoformat(),
    }
