"""Establishments API routes."""

from flask import Blueprint, jsonify, request

from app.services.places_service import PlacesService

establishments_bp = Blueprint("establishments", __name__)
_places = PlacesService()


@establishments_bp.get("")
def list_establishments():
  category = request.args.get("category")
  return jsonify({"establishments": _places.list_establishments(category)}), 200


@establishments_bp.get("/<int:establishment_id>")
def get_establishment(establishment_id: int):
  item = _places.get_establishment(establishment_id)
  if not item:
    return jsonify({"message": "Establishment not found"}), 404
  return jsonify(item), 200
