"""AI chat history routes."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.services.user_settings_service import AiHistoryService

ai_history_bp = Blueprint("ai_history", __name__)
_service = AiHistoryService()


@ai_history_bp.get("")
@jwt_required()
def list_history():
  user_id = int(get_jwt_identity())
  session_id = request.args.get("session_id")
  items = _service.list_for_user(user_id, session_id=session_id)
  return jsonify({"messages": items}), 200


@ai_history_bp.post("")
@jwt_required()
def save_history():
  user_id = int(get_jwt_identity())
  payload = request.get_json() or {}
  session_id = (payload.get("session_id") or "").strip()
  messages = payload.get("messages") or []
  if not session_id or not messages:
    return jsonify({"message": "session_id and messages are required"}), 400
  saved = _service.append_messages(user_id, session_id, messages)
  return jsonify({"messages": saved}), 201


@ai_history_bp.delete("/<session_id>")
@jwt_required()
def clear_history(session_id: str):
  user_id = int(get_jwt_identity())
  deleted = _service.clear_session(user_id, session_id)
  return jsonify({"message": "Session history cleared", "deleted": deleted}), 200
