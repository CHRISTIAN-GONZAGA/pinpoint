"""User notification API routes."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.services.notification_service import NotificationService

notifications_bp = Blueprint("notifications", __name__)
_service = NotificationService()


@notifications_bp.get("")
@jwt_required()
def list_notifications():
  user_id = int(get_jwt_identity())
  unread_only = request.args.get("unread") == "true"
  items = _service.list_for_user(user_id, unread_only=unread_only)
  return jsonify(
    {
      "notifications": items,
      "unread_count": _service.unread_count(user_id),
    }
  ), 200


@notifications_bp.get("/announcements")
def public_announcements():
  return jsonify({"announcements": _service.list_announcements()}), 200


@notifications_bp.post("/<int:notification_id>/read")
@jwt_required()
def mark_read(notification_id: int):
  user_id = int(get_jwt_identity())
  item = _service.mark_read(user_id, notification_id)
  if not item:
    return jsonify({"message": "Notification not found"}), 404
  return jsonify(item), 200


@notifications_bp.post("/read-all")
@jwt_required()
def mark_all_read():
  user_id = int(get_jwt_identity())
  count = _service.mark_all_read(user_id)
  return jsonify({"message": "Notifications marked as read", "updated": count}), 200
