"""User synchronization API routes."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.services.sync_service import SyncService

sync_bp = Blueprint("sync", __name__)
_service = SyncService()


@sync_bp.get("/pull")
@jwt_required()
def pull_sync():
  user_id = int(get_jwt_identity())
  return jsonify(_service.pull(user_id)), 200


@sync_bp.post("/preferences")
@jwt_required()
def push_preferences():
  user_id = int(get_jwt_identity())
  payload = request.get_json() or {}
  profile = _service.push_preferences(user_id, payload)
  return jsonify({"profile": profile}), 200


@sync_bp.post("/favorites")
@jwt_required()
def merge_favorites():
  user_id = int(get_jwt_identity())
  payload = request.get_json() or {}
  items = payload.get("favorites", [])
  saved = _service.merge_favorites(user_id, items)
  return jsonify({"favorites": saved}), 200
