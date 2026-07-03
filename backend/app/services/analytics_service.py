"""Analytics event tracking and aggregation."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

from sqlalchemy import func

from app.extensions import db
from app.models.places import TouristAttraction
from app.models.system import AnalyticsEvent
from app.models.transport import JeepneyRoute
from app.models.user import User


class AnalyticsService:
  """Records and summarizes application usage metrics."""

  def track(
    self,
    *,
    event_type: str,
    user_id: int | None = None,
    metadata: dict | None = None,
  ) -> AnalyticsEvent:
    event = AnalyticsEvent(
      event_type=event_type,
      user_id=user_id,
      metadata_json=json.dumps(metadata or {}),
    )
    db.session.add(event)
    db.session.commit()
    return event

  def overview(self, days: int = 30) -> dict:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    total_events = AnalyticsEvent.query.filter(AnalyticsEvent.created_at >= since).count()
    event_counts = (
      db.session.query(AnalyticsEvent.event_type, func.count(AnalyticsEvent.event_id))
      .filter(AnalyticsEvent.created_at >= since)
      .group_by(AnalyticsEvent.event_type)
      .order_by(func.count(AnalyticsEvent.event_id).desc())
      .limit(10)
      .all()
    )
    return {
      "period_days": days,
      "total_events": total_events,
      "registered_users": User.query.filter(User.role != "admin").count(),
      "jeepney_routes": JeepneyRoute.query.filter_by(active_status=True).count(),
      "attractions": TouristAttraction.query.filter_by(active_status=True).count(),
      "top_events": [
        {"event_type": event_type, "count": count} for event_type, count in event_counts
      ],
    }
