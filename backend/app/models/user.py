"""SQLAlchemy models for PINPOINT."""

from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class User(db.Model):
  """Registered application user."""

  __tablename__ = "users"

  user_id = db.Column(db.Integer, primary_key=True)
  full_name = db.Column(db.String(120), nullable=False)
  email = db.Column(db.String(120), unique=True, nullable=False, index=True)
  password_hash = db.Column(db.String(255), nullable=False)
  mobile_number = db.Column(db.String(20), nullable=True)
  role = db.Column(db.String(20), nullable=False, default="user")
  language_preference = db.Column(db.String(10), nullable=False, default="en")
  theme_preference = db.Column(db.String(10), nullable=False, default="system")
  profile_photo = db.Column(db.String(255), nullable=True)
  large_text_enabled = db.Column(db.Boolean, nullable=False, default=False)
  reduce_motion_enabled = db.Column(db.Boolean, nullable=False, default=False)
  emergency_contact_name = db.Column(db.String(120), nullable=True)
  emergency_contact_phone = db.Column(db.String(30), nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  updated_at = db.Column(
    db.DateTime, nullable=False, default=utcnow, onupdate=utcnow
  )

  def to_dict(self) -> dict:
    return {
      "user_id": self.user_id,
      "full_name": self.full_name,
      "email": self.email,
      "mobile_number": self.mobile_number,
      "role": self.role,
      "language_preference": self.language_preference,
      "theme_preference": self.theme_preference,
      "profile_photo": self.profile_photo,
      "large_text_enabled": bool(self.large_text_enabled),
      "reduce_motion_enabled": bool(self.reduce_motion_enabled),
      "emergency_contact_name": self.emergency_contact_name,
      "emergency_contact_phone": self.emergency_contact_phone,
      "created_at": self.created_at.isoformat() if self.created_at else None,
      "updated_at": self.updated_at.isoformat() if self.updated_at else None,
    }
