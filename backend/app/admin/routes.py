"""Administrator API routes."""

from flask import Blueprint, jsonify, request

from app.extensions import db
from app.models.places import Establishment, TouristAttraction
from app.models.system import Announcement, UserReport
from app.models.transport import JeepneyRoute
from app.models.user import User
from app.services.analytics_service import AnalyticsService
from app.services.notification_service import NotificationService
from app.services.transport_service import TransportService
from app.utils.decorators import admin_required

admin_bp = Blueprint("admin", __name__)
_analytics = AnalyticsService()
_notifications = NotificationService()
_transport = TransportService()


@admin_bp.get("/dashboard")
@admin_required()
def dashboard():
  overview = _analytics.overview()
  overview.update(
    {
      "open_reports": UserReport.query.filter_by(status="open").count(),
      "active_announcements": Announcement.query.filter_by(active_status=True).count(),
      "total_users": User.query.count(),
      "establishments": Establishment.query.filter_by(active_status=True).count(),
      "routes": JeepneyRoute.query.filter_by(active_status=True).count(),
    }
  )
  return jsonify(overview), 200


@admin_bp.get("/users")
@admin_required()
def list_users():
  users = User.query.order_by(User.created_at.desc()).limit(100).all()
  return jsonify({"users": [user.to_dict() for user in users]}), 200


@admin_bp.get("/announcements")
@admin_required()
def admin_announcements():
  return jsonify({"announcements": _notifications.list_announcements(active_only=False)}), 200


@admin_bp.post("/announcements")
@admin_required()
def create_announcement():
  payload = request.get_json() or {}
  title = (payload.get("title") or "").strip()
  content = (payload.get("content") or "").strip()
  if not title or not content:
    return jsonify({"message": "title and content are required"}), 400
  announcement = _notifications.publish_announcement(payload)
  return jsonify(announcement), 201


@admin_bp.patch("/announcements/<int:announcement_id>")
@admin_required()
def update_announcement(announcement_id: int):
  announcement = db.session.get(Announcement, announcement_id)
  if not announcement:
    return jsonify({"message": "Announcement not found"}), 404
  payload = request.get_json() or {}
  if "active_status" in payload:
    announcement.active_status = bool(payload["active_status"])
  if "title" in payload:
    announcement.title = payload["title"]
  if "content" in payload:
    announcement.content = payload["content"]
  db.session.commit()
  return jsonify(announcement.to_dict()), 200


@admin_bp.get("/reports")
@admin_required()
def list_reports():
  status = request.args.get("status")
  query = UserReport.query.order_by(UserReport.created_at.desc())
  if status:
    query = query.filter_by(status=status)
  reports = query.limit(100).all()
  return jsonify({"reports": [report.to_dict() for report in reports]}), 200


@admin_bp.patch("/reports/<int:report_id>")
@admin_required()
def update_report(report_id: int):
  report = db.session.get(UserReport, report_id)
  if not report:
    return jsonify({"message": "Report not found"}), 404
  payload = request.get_json() or {}
  if "status" in payload:
    report.status = payload["status"]
  if "admin_notes" in payload:
    report.admin_notes = payload["admin_notes"]
  db.session.commit()
  return jsonify(report.to_dict()), 200


@admin_bp.get("/routes")
@admin_required()
def admin_list_routes():
  return jsonify({"routes": _transport.list_all_routes()}), 200


@admin_bp.post("/routes")
@admin_required()
def admin_create_route():
  payload = request.get_json() or {}
  try:
    route = _transport.create_route(payload)
  except ValueError as error:
    return jsonify({"message": str(error)}), 400
  return jsonify(route), 201


@admin_bp.get("/routes/<int:route_id>")
@admin_required()
def admin_get_route(route_id: int):
  route = _transport.get_route(route_id, active_only=False)
  if not route:
    return jsonify({"message": "Route not found"}), 404
  return jsonify(route), 200


@admin_bp.patch("/routes/<int:route_id>")
@admin_required()
def admin_update_route(route_id: int):
  payload = request.get_json() or {}
  try:
    route = _transport.update_route(route_id, payload)
  except ValueError as error:
    return jsonify({"message": str(error)}), 400
  if not route:
    return jsonify({"message": "Route not found"}), 404
  return jsonify(route), 200


@admin_bp.delete("/routes/<int:route_id>")
@admin_required()
def admin_delete_route(route_id: int):
  deleted = _transport.delete_route(route_id)
  if not deleted:
    return jsonify({"message": "Route not found"}), 404
  return jsonify({"message": "Route deleted"}), 200


@admin_bp.put("/routes/<int:route_id>/stops")
@admin_required()
def admin_replace_stops(route_id: int):
  payload = request.get_json() or {}
  stops = payload.get("stops") if isinstance(payload, dict) else payload
  if not isinstance(stops, list):
    return jsonify({"message": "stops must be a list"}), 400
  try:
    route = _transport.replace_stops(route_id, stops)
  except ValueError as error:
    return jsonify({"message": str(error)}), 400
  if not route:
    return jsonify({"message": "Route not found"}), 404
  return jsonify(route), 200
