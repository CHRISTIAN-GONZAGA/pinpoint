"""AI chat history and user settings services."""

from __future__ import annotations

from app.extensions import db
from app.models.extensions import AiChatHistory, DeviceToken
from app.models.user import User


class AiHistoryService:
  """Persist and retrieve AI conversations for registered users."""

  def list_for_user(self, user_id: int, *, session_id: str | None = None, limit: int = 50) -> list[dict]:
    query = AiChatHistory.query.filter_by(user_id=user_id).order_by(AiChatHistory.created_at.asc())
    if session_id:
      query = query.filter_by(session_id=session_id)
    return [item.to_dict() for item in query.limit(limit).all()]

  def append_messages(self, user_id: int, session_id: str, messages: list[dict]) -> list[dict]:
    saved: list[dict] = []
    for message in messages:
      entry = AiChatHistory(
        user_id=user_id,
        session_id=session_id,
        role=message["role"],
        content=message["content"],
        language=message.get("language", "en"),
      )
      db.session.add(entry)
      db.session.flush()
      saved.append(entry.to_dict())
    db.session.commit()
    return saved

  def clear_session(self, user_id: int, session_id: str) -> int:
    deleted = AiChatHistory.query.filter_by(user_id=user_id, session_id=session_id).delete()
    db.session.commit()
    return deleted


class UserSettingsService:
  """Update profile preferences and emergency contact."""

  def update_profile(self, user_id: int, payload: dict) -> dict | None:
    user = db.session.get(User, user_id)
    if not user:
      return None
    for field in (
      "language_preference",
      "theme_preference",
      "emergency_contact_name",
      "emergency_contact_phone",
    ):
      if field in payload:
        setattr(user, field, payload[field])
    if "large_text_enabled" in payload:
      user.large_text_enabled = bool(payload["large_text_enabled"])
    if "reduce_motion_enabled" in payload:
      user.reduce_motion_enabled = bool(payload["reduce_motion_enabled"])
    db.session.commit()
    return user.to_dict()


class DeviceTokenService:
  """Register device tokens for future push delivery."""

  def register(self, user_id: int, token: str, platform: str = "android") -> dict:
    existing = DeviceToken.query.filter_by(token=token).first()
    if existing:
      existing.user_id = user_id
      existing.platform = platform
      db.session.commit()
      return existing.to_dict()
    entry = DeviceToken(user_id=user_id, token=token, platform=platform)
    db.session.add(entry)
    db.session.commit()
    return entry.to_dict()
