"""Analytics API routes."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.services.analytics_service import AnalyticsService
from app.utils.decorators import admin_required

analytics_bp = Blueprint("analytics", __name__)
_service = AnalyticsService()


@analytics_bp.post("/events")
@jwt_required(optional=True)
def track_event():
  payload = request.get_json() or {}
  event_type = (payload.get("event_type") or "").strip()
  if not event_type:
    return jsonify({"message": "event_type is required"}), 400

  identity = get_jwt_identity()
  user_id = int(identity) if identity else None

  event = _service.track(
    event_type=event_type,
    user_id=user_id,
    metadata=payload.get("metadata"),
  )
  return jsonify(event.to_dict()), 201


@analytics_bp.get("/overview")
@admin_required()
def analytics_overview():
  days = int(request.args.get("days", 30))
  return jsonify(_service.overview(days=days)), 200
