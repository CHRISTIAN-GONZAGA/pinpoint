"""Notification and announcement business logic."""

from __future__ import annotations

import json

from app.extensions import db
from app.models.system import Announcement, Notification
from app.models.user import User


class NotificationService:
  """Creates and delivers user notifications."""

  def list_for_user(self, user_id: int, *, unread_only: bool = False) -> list[dict]:
    query = Notification.query.filter_by(user_id=user_id).order_by(
      Notification.created_at.desc()
    )
    if unread_only:
      query = query.filter_by(read_status=False)
    return [item.to_dict() for item in query.limit(50).all()]

  def unread_count(self, user_id: int) -> int:
    return Notification.query.filter_by(user_id=user_id, read_status=False).count()

  def mark_read(self, user_id: int, notification_id: int) -> dict | None:
    notification = Notification.query.filter_by(
      notification_id=notification_id, user_id=user_id
    ).first()
    if not notification:
      return None
    notification.read_status = True
    db.session.commit()
    return notification.to_dict()

  def mark_all_read(self, user_id: int) -> int:
    updated = (
      Notification.query.filter_by(user_id=user_id, read_status=False)
      .update({"read_status": True})
    )
    db.session.commit()
    return updated

  def publish_announcement(self, payload: dict) -> dict:
    announcement = Announcement(
      title=payload["title"],
      content=payload["content"],
      category=payload.get("category", "general"),
      priority=payload.get("priority", "normal"),
      active_status=payload.get("active_status", True),
    )
    db.session.add(announcement)
    db.session.flush()

    users = User.query.filter(User.role.in_(["user", "admin"])).all()
    for user in users:
      db.session.add(
        Notification(
          user_id=user.user_id,
          title=announcement.title,
          body=announcement.content,
          category=announcement.category,
          metadata_json=json.dumps(
            {"announcement_id": announcement.announcement_id, "priority": announcement.priority}
          ),
        )
      )
    db.session.commit()
    return announcement.to_dict()

  def list_announcements(self, *, active_only: bool = True) -> list[dict]:
    query = Announcement.query.order_by(Announcement.published_at.desc())
    if active_only:
      query = query.filter_by(active_status=True)
    return [item.to_dict() for item in query.all()]
