"""Emergency contacts API routes."""

from flask import Blueprint, jsonify

from app.services.places_service import PlacesService

emergency_bp = Blueprint("emergency", __name__)
_places = PlacesService()


@emergency_bp.get("")
def list_emergency():
  return jsonify({"contacts": _places.list_emergency()}), 200
