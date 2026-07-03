"""Tourism, establishments, emergency, favorites, and history models."""

import json
from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class TouristAttraction(db.Model):
  """Tourist attraction in Butuan City."""

  __tablename__ = "tourist_attractions"

  attraction_id = db.Column(db.Integer, primary_key=True)
  name = db.Column(db.String(150), nullable=False)
  description = db.Column(db.Text, nullable=True)
  address = db.Column(db.String(255), nullable=True)
  latitude = db.Column(db.Float, nullable=False)
  longitude = db.Column(db.Float, nullable=False)
  entrance_fee = db.Column(db.String(80), nullable=True)
  opening_hours = db.Column(db.String(120), nullable=True)
  category = db.Column(db.String(50), nullable=False, default="attraction")
  contact_information = db.Column(db.String(120), nullable=True)
  images = db.Column(db.Text, nullable=True)
  active_status = db.Column(db.Boolean, nullable=False, default=True)

  def to_dict(self) -> dict:
    return {
      "attraction_id": self.attraction_id,
      "name": self.name,
      "description": self.description,
      "address": self.address,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "entrance_fee": self.entrance_fee,
      "opening_hours": self.opening_hours,
      "category": self.category,
      "contact_information": self.contact_information,
      "images": json.loads(self.images) if self.images else [],
      "place_type": "attraction",
    }


class Establishment(db.Model):
  """Public establishment (restaurant, hospital, etc.)."""

  __tablename__ = "establishments"

  establishment_id = db.Column(db.Integer, primary_key=True)
  name = db.Column(db.String(150), nullable=False)
  category = db.Column(db.String(50), nullable=False, index=True)
  description = db.Column(db.Text, nullable=True)
  address = db.Column(db.String(255), nullable=True)
  latitude = db.Column(db.Float, nullable=False)
  longitude = db.Column(db.Float, nullable=False)
  contact_information = db.Column(db.String(120), nullable=True)
  opening_hours = db.Column(db.String(120), nullable=True)
  active_status = db.Column(db.Boolean, nullable=False, default=True)

  def to_dict(self) -> dict:
    return {
      "establishment_id": self.establishment_id,
      "name": self.name,
      "category": self.category,
      "description": self.description,
      "address": self.address,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "contact_information": self.contact_information,
      "opening_hours": self.opening_hours,
      "place_type": "establishment",
    }


class EmergencyContact(db.Model):
  """Emergency agency contact and location."""

  __tablename__ = "emergency_contacts"

  contact_id = db.Column(db.Integer, primary_key=True)
  agency = db.Column(db.String(120), nullable=False)
  hotline = db.Column(db.String(30), nullable=False)
  category = db.Column(db.String(50), nullable=False)
  address = db.Column(db.String(255), nullable=True)
  latitude = db.Column(db.Float, nullable=True)
  longitude = db.Column(db.Float, nullable=True)
  availability = db.Column(db.String(80), nullable=True)
  instructions = db.Column(db.Text, nullable=True)
  active_status = db.Column(db.Boolean, nullable=False, default=True)

  def to_dict(self) -> dict:
    return {
      "contact_id": self.contact_id,
      "agency": self.agency,
      "hotline": self.hotline,
      "category": self.category,
      "address": self.address,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "availability": self.availability,
      "instructions": self.instructions,
    }


class Favorite(db.Model):
  """User-saved favorite place or route."""

  __tablename__ = "favorites"

  favorite_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False)
  place_type = db.Column(db.String(30), nullable=False)
  place_id = db.Column(db.Integer, nullable=True)
  label = db.Column(db.String(150), nullable=False)
  latitude = db.Column(db.Float, nullable=True)
  longitude = db.Column(db.Float, nullable=True)
  category = db.Column(db.String(50), nullable=True)
  metadata_json = db.Column(db.Text, nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

  def to_dict(self) -> dict:
    return {
      "favorite_id": self.favorite_id,
      "place_type": self.place_type,
      "place_id": self.place_id,
      "label": self.label,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "category": self.category,
      "metadata": json.loads(self.metadata_json) if self.metadata_json else {},
      "created_at": self.created_at.isoformat(),
    }


class SearchHistory(db.Model):
  """User search and navigation history entry."""

  __tablename__ = "search_history"

  history_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False)
  query = db.Column(db.String(255), nullable=False)
  search_type = db.Column(db.String(30), nullable=False, default="place")
  latitude = db.Column(db.Float, nullable=True)
  longitude = db.Column(db.Float, nullable=True)
  metadata_json = db.Column(db.Text, nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

  def to_dict(self) -> dict:
    return {
      "history_id": self.history_id,
      "query": self.query,
      "search_type": self.search_type,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "metadata": json.loads(self.metadata_json) if self.metadata_json else {},
      "created_at": self.created_at.isoformat(),
    }
