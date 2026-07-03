"""User profile API routes."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from marshmallow import ValidationError

from app.services.auth_service import AuthService
from app.services.user_settings_service import DeviceTokenService, UserSettingsService

users_bp = Blueprint("users", __name__)
_auth_service = AuthService()
_settings = UserSettingsService()
_devices = DeviceTokenService()


@users_bp.get("/profile")
@jwt_required()
def get_profile():
  user_id = int(get_jwt_identity())
  try:
    user = _auth_service.get_user(user_id)
    return jsonify(user), 200
  except Exception:
    return jsonify({"message": "User not found"}), 404


@users_bp.patch("/profile")
@jwt_required()
def update_profile():
  user_id = int(get_jwt_identity())
  profile = _settings.update_profile(user_id, request.get_json() or {})
  if not profile:
    return jsonify({"message": "User not found"}), 404
  return jsonify(profile), 200


@users_bp.post("/devices")
@jwt_required()
def register_device():
  payload = request.get_json() or {}
  token = (payload.get("token") or "").strip()
  if not token:
    return jsonify({"message": "token is required"}), 400
  user_id = int(get_jwt_identity())
  device = _devices.register(user_id, token, payload.get("platform", "android"))
  return jsonify(device), 201


@users_bp.delete("/account")
@jwt_required()
def delete_account():
  user_id = int(get_jwt_identity())
  try:
    _auth_service.delete_account(user_id)
    return jsonify({"message": "Account deleted successfully"}), 200
  except ValidationError as err:
    message = err.messages.get("message", ["Unable to delete account."])
    return jsonify({"message": message[0] if isinstance(message, list) else message}), 400
