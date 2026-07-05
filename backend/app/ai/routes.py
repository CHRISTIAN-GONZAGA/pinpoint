"""AI and knowledge base API routes."""

from flask import Blueprint, jsonify, request

from app.ai.chat_service import ChatService
from app.ai.knowledge_sync import build_documents_from_database

ai_bp = Blueprint("ai", __name__)
_chat: ChatService | None = None


def _get_chat() -> ChatService:
  global _chat
  if _chat is None:
    _chat = ChatService()
  return _chat


@ai_bp.post("/chat")
def chat():
  payload = request.get_json() or {}
  message = (payload.get("message") or "").strip()
  if not message:
    return jsonify({"message": "message is required"}), 400

  result = _get_chat().chat(
    message=message,
    session_id=payload.get("session_id"),
    latitude=payload.get("latitude"),
    longitude=payload.get("longitude"),
    response_language=payload.get("response_language"),
  )
  return jsonify(result), 200


@ai_bp.post("/clear")
def clear_session():
  payload = request.get_json() or {}
  session_id = payload.get("session_id")
  if not session_id:
    return jsonify({"message": "session_id is required"}), 400
  _get_chat().clear_session(session_id)
  return jsonify({"message": "Session cleared"}), 200


@ai_bp.get("/status")
def ai_status():
  return jsonify(_get_chat().status()), 200


@ai_bp.post("/reindex")
def reindex_knowledge():
  count = _get_chat().ensure_index()
  return jsonify({"message": "Knowledge base reindexed", "chunks_indexed": count}), 200


@ai_bp.get("/knowledge")
def knowledge_preview():
  documents = build_documents_from_database()
  return jsonify({"documents": len(documents)}), 200
