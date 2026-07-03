"""System models for announcements, notifications, reports, and analytics."""

import json
from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class Announcement(db.Model):
  """City-wide or targeted announcement published by administrators."""

  __tablename__ = "announcements"

  announcement_id = db.Column(db.Integer, primary_key=True)
  title = db.Column(db.String(200), nullable=False)
  content = db.Column(db.Text, nullable=False)
  category = db.Column(db.String(50), nullable=False, default="general")
  priority = db.Column(db.String(20), nullable=False, default="normal")
  active_status = db.Column(db.Boolean, nullable=False, default=True)
  published_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  updated_at = db.Column(
    db.DateTime, nullable=False, default=utcnow, onupdate=utcnow
  )

  def to_dict(self) -> dict:
    return {
      "announcement_id": self.announcement_id,
      "title": self.title,
      "content": self.content,
      "category": self.category,
      "priority": self.priority,
      "active_status": self.active_status,
      "published_at": self.published_at.isoformat(),
      "created_at": self.created_at.isoformat(),
    }


class Notification(db.Model):
  """Per-user notification delivered from announcements or system events."""

  __tablename__ = "notifications"

  notification_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False, index=True)
  title = db.Column(db.String(200), nullable=False)
  body = db.Column(db.Text, nullable=False)
  category = db.Column(db.String(50), nullable=False, default="general")
  read_status = db.Column(db.Boolean, nullable=False, default=False)
  metadata_json = db.Column(db.Text, nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

  def to_dict(self) -> dict:
    return {
      "notification_id": self.notification_id,
      "user_id": self.user_id,
      "title": self.title,
      "body": self.body,
      "category": self.category,
      "read_status": self.read_status,
      "metadata": json.loads(self.metadata_json) if self.metadata_json else {},
      "created_at": self.created_at.isoformat(),
    }


class UserReport(db.Model):
  """User-submitted transport or tourism issue report."""

  __tablename__ = "user_reports"

  report_id = db.Column(db.Integer, primary_key=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=False, index=True)
  category = db.Column(db.String(50), nullable=False)
  description = db.Column(db.Text, nullable=False)
  status = db.Column(db.String(20), nullable=False, default="open")
  latitude = db.Column(db.Float, nullable=True)
  longitude = db.Column(db.Float, nullable=True)
  admin_notes = db.Column(db.Text, nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  updated_at = db.Column(
    db.DateTime, nullable=False, default=utcnow, onupdate=utcnow
  )

  def to_dict(self) -> dict:
    return {
      "report_id": self.report_id,
      "user_id": self.user_id,
      "category": self.category,
      "description": self.description,
      "status": self.status,
      "latitude": self.latitude,
      "longitude": self.longitude,
      "admin_notes": self.admin_notes,
      "created_at": self.created_at.isoformat(),
      "updated_at": self.updated_at.isoformat(),
    }


class AnalyticsEvent(db.Model):
  """Lightweight analytics event for usage tracking."""

  __tablename__ = "analytics_events"

  event_id = db.Column(db.Integer, primary_key=True)
  event_type = db.Column(db.String(80), nullable=False, index=True)
  user_id = db.Column(db.Integer, db.ForeignKey("users.user_id"), nullable=True, index=True)
  metadata_json = db.Column(db.Text, nullable=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow, index=True)

  def to_dict(self) -> dict:
    return {
      "event_id": self.event_id,
      "event_type": self.event_type,
      "user_id": self.user_id,
      "metadata": json.loads(self.metadata_json) if self.metadata_json else {},
      "created_at": self.created_at.isoformat(),
    }
