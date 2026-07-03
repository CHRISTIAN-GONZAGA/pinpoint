"""Extended user personalization and device models."""

from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class AiChatHistory(db.Model):
  """Persisted AI conversation messages for registered users."""

  __tablename__ = "ai_chat_history"

  history_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False, index=True)
  session_id = db.Column(db.String(64), nullable=False, index=True)
  role = db.Column(db.String(20), nullable=False)
  content = db.Column(db.Text, nullable=False)
  language = db.Column(db.String(10), nullable=False, default="en")
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

  def to_dict(self) -> dict:
    return {
      "history_id": self.history_id,
      "session_id": self.session_id,
      "role": self.role,
      "content": self.content,
      "language": self.language,
      "created_at": self.created_at.isoformat(),
    }


class DeviceToken(db.Model):
  """Push notification device registration."""

  __tablename__ = "device_tokens"

  token_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False, index=True)
  token = db.Column(db.String(512), nullable=False, unique=True)
  platform = db.Column(db.String(20), nullable=False, default="android")
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  updated_at = db.Column(
    db.DateTime, nullable=False, default=utcnow, onupdate=utcnow
  )

  def to_dict(self) -> dict:
    return {
      "token_id": self.token_id,
      "platform": self.platform,
      "created_at": self.created_at.isoformat(),
    }
