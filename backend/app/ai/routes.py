"""AI and knowledge base API routes."""

import math
import uuid

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

from app.ai.chat_service import ChatService
from app.ai.llm_service import AIProviderError
from app.ai.knowledge_sync import build_documents_from_database
from app.middleware.rate_limit import rate_limit

ai_bp = Blueprint("ai", __name__)
_chat: ChatService | None = None
_MAX_MESSAGE_LENGTH = 4_000
_MAX_HISTORY_MESSAGES = 9
_SUPPORTED_LANGUAGES = {"auto", "en", "tl", "ceb", "mixed"}
_FALLBACK_RESPONSE = "I'm having trouble responding right now. Please try again in a moment."


def _get_chat() -> ChatService:
  global _chat
  if _chat is None:
    _chat = ChatService()
  return _chat


def _chat_requester_key() -> str:
  verify_jwt_in_request(optional=True)
  user_id = get_jwt_identity()
  if user_id is not None:
    return f"user:{user_id}"

  client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")
  return f"anonymous:{client_ip}"


def _fallback_payload(
  *, session_id: str | None, response_language: str | None
) -> dict:
  return {
    "response": _FALLBACK_RESPONSE,
    "language": response_language
    if response_language in {"en", "tl", "ceb", "mixed"}
    else "en",
    "session_id": session_id or str(uuid.uuid4()),
    "sources": [],
    "actions": [],
    "retrieval_confidence": 0.0,
  }


@ai_bp.post("/chat")
@rate_limit(limit=1, window_seconds=3, key_func=_chat_requester_key)
@rate_limit(limit=10, window_seconds=60)
def chat():
  payload = request.get_json(silent=True)
  if not isinstance(payload, dict):
    return jsonify({"message": "A JSON request body is required"}), 400

  message = payload.get("message")
  if not isinstance(message, str):
    return jsonify({"message": "message is required"}), 400
  message = message.strip()
  if not message:
    return jsonify({"message": "message is required"}), 400
  if len(message) > _MAX_MESSAGE_LENGTH:
    return jsonify({"message": "message must be 4000 characters or fewer"}), 400

  session_id = payload.get("session_id")
  if session_id is not None:
    if not isinstance(session_id, str) or not session_id.strip() or len(session_id) > 64:
      return jsonify({"message": "session_id must be a non-empty string of 64 characters or fewer"}), 400
    session_id = session_id.strip()

  response_language = payload.get("response_language")
  if response_language is not None and (
    not isinstance(response_language, str)
    or response_language not in _SUPPORTED_LANGUAGES
  ):
    return jsonify({"message": "response_language is not supported"}), 400

  history = payload.get("history")
  if history is not None:
    if not isinstance(history, list) or len(history) > _MAX_HISTORY_MESSAGES:
      return jsonify({"message": "history must contain at most 8 messages"}), 400
    validated_history = []
    for item in history:
      role = item.get("role") if isinstance(item, dict) else None
      content = item.get("content") if isinstance(item, dict) else None
      if (
        not isinstance(role, str)
        or role not in {"user", "assistant"}
        or not isinstance(content, str)
        or len(content) > _MAX_MESSAGE_LENGTH
      ):
        return jsonify({"message": "history contains an invalid message"}), 400
      if content.strip():
        validated_history.append(
          {"role": role, "content": content.strip()}
        )
    history = validated_history

  coordinates: dict[str, float | None] = {}
  for field, minimum, maximum in (
    ("latitude", -90.0, 90.0),
    ("longitude", -180.0, 180.0),
  ):
    value = payload.get(field)
    if value is None:
      coordinates[field] = None
    elif (
      isinstance(value, bool)
      or not isinstance(value, (int, float))
      or not math.isfinite(value)
      or not minimum <= value <= maximum
    ):
      return jsonify({"message": f"{field} must be a valid coordinate"}), 400
    else:
      coordinates[field] = float(value)

  try:
    result = _get_chat().chat(
      message=message,
      session_id=session_id,
      latitude=coordinates["latitude"],
      longitude=coordinates["longitude"],
      response_language=response_language,
      history=history,
    )
  except AIProviderError as error:
    current_app.logger.warning("AI chat provider failure: %s", error)
    return jsonify(
      _fallback_payload(session_id=session_id, response_language=response_language)
    ), 200
  except Exception:
    current_app.logger.exception("Unexpected AI chat failure")
    return jsonify(
      _fallback_payload(session_id=session_id, response_language=response_language)
    ), 200
  return jsonify(result), 200


@ai_bp.post("/clear")
def clear_session():
  payload = request.get_json(silent=True)
  if not isinstance(payload, dict):
    return jsonify({"message": "A JSON request body is required"}), 400
  session_id = payload.get("session_id")
  if not isinstance(session_id, str) or not session_id.strip() or len(session_id) > 64:
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
