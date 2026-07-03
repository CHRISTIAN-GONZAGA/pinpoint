"""Password reset token persistence."""

from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class PasswordResetToken(db.Model):
  """Single-use password reset token for a user."""

  __tablename__ = "password_reset_tokens"

  token_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False, index=True)
  token_hash = db.Column(db.String(255), nullable=False, unique=True, index=True)
  expires_at = db.Column(db.DateTime, nullable=False)
  used_at = db.Column(db.DateTime, nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
