"""Authentication API routes."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import (
  create_access_token,
  create_refresh_token,
  get_jwt_identity,
  jwt_required,
)
from marshmallow import ValidationError

from app.middleware.rate_limit import rate_limit
from app.services.auth_service import AuthService

auth_bp = Blueprint("auth", __name__)
_auth_service = AuthService()


def _token_response(user: dict) -> tuple[dict, int]:
  identity = str(user["user_id"])
  return {
    "access_token": create_access_token(identity=identity),
    "refresh_token": create_refresh_token(identity=identity),
    "user": user,
    "message": "Authentication successful",
  }, 200


@auth_bp.post("/register")
@rate_limit(limit=8, window_seconds=60)
def register():
  try:
    user = _auth_service.register(request.get_json() or {})
    return _token_response(user)
  except ValidationError as err:
    messages = err.messages
    message = messages.get("message", ["Validation failed"])[0] if isinstance(messages.get("message"), list) else str(messages)
    if isinstance(messages, dict) and "email" in messages:
      message = messages["email"][0]
    return jsonify({"message": message, "errors": messages}), 400


@auth_bp.post("/login")
@rate_limit(limit=10, window_seconds=60)
def login():
  try:
    user = _auth_service.login(request.get_json() or {})
    return _token_response(user)
  except ValidationError as err:
    message = err.messages.get("message", ["Invalid email or password."])
    return jsonify({"message": message[0] if isinstance(message, list) else message}), 401


@auth_bp.post("/refresh")
def refresh():
  payload = request.get_json() or {}
  refresh_token = payload.get("refresh_token")
  if not refresh_token:
    return jsonify({"message": "Refresh token is required"}), 400

  from flask_jwt_extended import decode_token

  try:
    decoded = decode_token(refresh_token)
    user_id = decoded["sub"]
    user = _auth_service.get_user(int(user_id))
    return {
      "access_token": create_access_token(identity=user_id),
      "refresh_token": create_refresh_token(identity=user_id),
      "user": user,
    }, 200
  except Exception:
    return jsonify({"message": "Invalid or expired refresh token"}), 401


@auth_bp.post("/logout")
@jwt_required()
def logout():
  return jsonify({"message": "Logged out successfully"}), 200


@auth_bp.post("/forgot-password")
@rate_limit(limit=5, window_seconds=60)
def forgot_password():
  try:
    result = _auth_service.request_password_reset(request.get_json() or {})
    return jsonify(result), 200
  except ValidationError as err:
    messages = err.messages
    message = messages.get("email", ["Invalid email."])
    return jsonify({"message": message[0] if isinstance(message, list) else message}), 400


@auth_bp.post("/reset-password")
@rate_limit(limit=8, window_seconds=60)
def reset_password():
  try:
    result = _auth_service.reset_password(request.get_json() or {})
    return jsonify(result), 200
  except ValidationError as err:
    message = err.messages.get("message", ["Unable to reset password."])
    return jsonify({"message": message[0] if isinstance(message, list) else message}), 400
