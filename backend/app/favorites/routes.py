"""Favorites API routes (registered users only)."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.services.places_service import FavoritesService

favorites_bp = Blueprint("favorites", __name__)
_favorites = FavoritesService()


@favorites_bp.get("")
@jwt_required()
def list_favorites():
  user_id = int(get_jwt_identity())
  return jsonify({"favorites": _favorites.list_favorites(user_id)}), 200


@favorites_bp.post("")
@jwt_required()
def add_favorite():
  user_id = int(get_jwt_identity())
  payload = request.get_json() or {}
  if not payload.get("label") or not payload.get("place_type"):
    return jsonify({"message": "label and place_type are required"}), 400
  favorite = _favorites.add_favorite(user_id, payload)
  return jsonify(favorite), 201


@favorites_bp.delete("/<int:favorite_id>")
@jwt_required()
def delete_favorite(favorite_id: int):
  user_id = int(get_jwt_identity())
  if not _favorites.remove_favorite(user_id, favorite_id):
    return jsonify({"message": "Favorite not found"}), 404
  return jsonify({"message": "Favorite removed"}), 200
