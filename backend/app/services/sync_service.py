"""User data synchronization service."""

from __future__ import annotations

from datetime import datetime, timezone

from app.extensions import db
from app.models.places import Favorite, SearchHistory
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.services.notification_service import NotificationService


class SyncService:
  """Coordinates pull/push sync for registered users."""

  def __init__(self) -> None:
    self._users = UserRepository()
    self._notifications = NotificationService()

  def pull(self, user_id: int) -> dict:
    user = self._users.get_by_id(user_id)
    if not user:
      return {}

    favorites = Favorite.query.filter_by(user_id=user_id).order_by(Favorite.created_at.desc()).all()
    history = (
      db.session.query(SearchHistory)
      .filter_by(user_id=user_id)
      .order_by(SearchHistory.created_at.desc())
      .limit(50)
      .all()
    )

    return {
      "synced_at": datetime.now(timezone.utc).isoformat(),
      "profile": user.to_dict(),
      "favorites": [item.to_dict() for item in favorites],
      "history": [item.to_dict() for item in history],
      "unread_notifications": self._notifications.unread_count(user_id),
    }

  def push_preferences(self, user_id: int, payload: dict) -> dict:
    user = db.session.get(User, user_id)
    if not user:
      return {}
    if "language_preference" in payload:
      user.language_preference = payload["language_preference"]
    if "theme_preference" in payload:
      user.theme_preference = payload["theme_preference"]
    db.session.commit()
    return user.to_dict()

  def merge_favorites(self, user_id: int, items: list[dict]) -> list[dict]:
    saved: list[dict] = []
    for item in items:
      place_type = item.get("place_type")
      place_id = item.get("place_id")
      if not place_type or place_id is None:
        continue
      existing = Favorite.query.filter_by(
        user_id=user_id, place_type=place_type, place_id=place_id
      ).first()
      if existing:
        saved.append(existing.to_dict())
        continue
      favorite = Favorite(
        user_id=user_id,
        place_type=place_type,
        place_id=int(place_id),
        label=item.get("label") or f"{place_type} #{place_id}",
        latitude=item.get("latitude"),
        longitude=item.get("longitude"),
        category=item.get("category"),
      )
      db.session.add(favorite)
      db.session.flush()
      saved.append(favorite.to_dict())
    db.session.commit()
    return saved
