"""Search history API routes (registered users only)."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.services.places_service import HistoryService

history_bp = Blueprint("history", __name__)
_history = HistoryService()


@history_bp.get("")
@jwt_required()
def list_history():
  user_id = int(get_jwt_identity())
  return jsonify({"history": _history.list_history(user_id)}), 200


@history_bp.post("")
@jwt_required()
def add_history():
  user_id = int(get_jwt_identity())
  payload = request.get_json() or {}
  if not payload.get("query"):
    return jsonify({"message": "query is required"}), 400
  entry = _history.add_entry(user_id, payload)
  return jsonify(entry), 201


@history_bp.delete("/<int:history_id>")
@jwt_required()
def delete_history(history_id: int):
  user_id = int(get_jwt_identity())
  if not _history.delete_entry(user_id, history_id):
    return jsonify({"message": "History entry not found"}), 404
  return jsonify({"message": "Entry removed"}), 200


@history_bp.delete("")
@jwt_required()
def clear_history():
  user_id = int(get_jwt_identity())
  _history.clear_history(user_id)
  return jsonify({"message": "History cleared"}), 200
