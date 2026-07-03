"""Tourism API routes."""

from flask import Blueprint, jsonify, request

from app.services.places_service import PlacesService

tourism_bp = Blueprint("tourism", __name__)
_places = PlacesService()


@tourism_bp.get("")
def list_attractions():
  category = request.args.get("category")
  return jsonify({"attractions": _places.list_attractions(category)}), 200


@tourism_bp.get("/search")
def search_places():
  query = request.args.get("q", "").strip()
  if not query:
    return jsonify({"attractions": [], "establishments": []}), 200
  return jsonify(_places.search(query)), 200


@tourism_bp.get("/nearby")
def nearby_places():
  lat = request.args.get("lat", type=float)
  lng = request.args.get("lng", type=float)
  radius = request.args.get("radius", default=5.0, type=float)
  if lat is None or lng is None:
    return jsonify({"message": "lat and lng are required"}), 400
  return jsonify({"places": _places.nearby(lat, lng, radius)}), 200


@tourism_bp.get("/<int:attraction_id>")
def get_attraction(attraction_id: int):
  attraction = _places.get_attraction(attraction_id)
  if not attraction:
    return jsonify({"message": "Attraction not found"}), 404
  return jsonify(attraction), 200
