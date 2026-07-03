"""Authentication business logic."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
from flask import current_app
from marshmallow import ValidationError

from app.extensions import db
from app.models.extensions import AiChatHistory, DeviceToken
from app.models.password_reset import PasswordResetToken
from app.models.places import Favorite, SearchHistory
from app.models.system import AnalyticsEvent, Notification, UserReport
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user_schema import (
  ForgotPasswordSchema,
  LoginSchema,
  RegisterSchema,
  ResetPasswordSchema,
)


class AuthService:
  """Handles registration, login, password reset, and account deletion."""

  def __init__(self, user_repo: UserRepository | None = None) -> None:
    self._users = user_repo or UserRepository()
    self._register_schema = RegisterSchema()
    self._login_schema = LoginSchema()
    self._forgot_schema = ForgotPasswordSchema()
    self._reset_schema = ResetPasswordSchema()

  def register(self, payload: dict) -> dict:
    data = self._register_schema.load(payload)
    email = data["email"].lower().strip()

    if self._users.get_by_email(email):
      raise ValidationError({"email": ["Email is already registered."]})

    password_hash = bcrypt.hashpw(
      data["password"].encode("utf-8"), bcrypt.gensalt()
    ).decode("utf-8")

    user = self._users.create(
      full_name=data["full_name"],
      email=email,
      password_hash=password_hash,
      mobile_number=data.get("mobile_number"),
    )
    return user.to_dict()

  def login(self, payload: dict) -> dict:
    data = self._login_schema.load(payload)
    user = self._users.get_by_email(data["email"])

    if not user or not self._verify_password(data["password"], user.password_hash):
      raise ValidationError({"message": "Invalid email or password."})

    return user.to_dict()

  def get_user(self, user_id: int) -> dict:
    user = self._users.get_by_id(user_id)
    if not user:
      raise ValidationError({"message": "User not found."})
    return user.to_dict()

  def request_password_reset(self, payload: dict) -> dict:
    data = self._forgot_schema.load(payload)
    email = data["email"].lower().strip()
    user = self._users.get_by_email(email)

    response = {
      "message": "If that email is registered, password reset instructions have been sent.",
    }

    if not user:
      return response

    raw_token = secrets.token_urlsafe(32)
    token_hash = self._hash_token(raw_token)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

    PasswordResetToken.query.filter_by(user_id=user.user_id, used_at=None).delete()
    db.session.add(
      PasswordResetToken(
        user_id=user.user_id,
        token_hash=token_hash,
        expires_at=expires_at,
      )
    )
    db.session.commit()

    if current_app.config.get("DEBUG", False):
      response["reset_token"] = raw_token

    return response

  def reset_password(self, payload: dict) -> dict:
    data = self._reset_schema.load(payload)
    token_hash = self._hash_token(data["token"])
    entry = PasswordResetToken.query.filter_by(token_hash=token_hash, used_at=None).first()

    if not entry:
      raise ValidationError({"message": "Invalid or expired reset token."})

    expires_at = entry.expires_at
    if expires_at.tzinfo is None:
      expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at < datetime.now(timezone.utc):
      raise ValidationError({"message": "Invalid or expired reset token."})

    user = self._users.get_by_id(entry.user_id)
    if not user:
      raise ValidationError({"message": "Invalid or expired reset token."})

    user.password_hash = bcrypt.hashpw(
      data["password"].encode("utf-8"), bcrypt.gensalt()
    ).decode("utf-8")
    entry.used_at = datetime.now(timezone.utc)
    db.session.commit()

    return {"message": "Password updated successfully. You can sign in now."}

  def delete_account(self, user_id: int) -> None:
    user = self._users.get_by_id(user_id)
    if not user:
      raise ValidationError({"message": "User not found."})
    if user.role == "admin":
      raise ValidationError({"message": "Administrator accounts cannot be deleted from the app."})

    AiChatHistory.query.filter_by(user_id=user_id).delete()
    DeviceToken.query.filter_by(user_id=user_id).delete()
    PasswordResetToken.query.filter_by(user_id=user_id).delete()
    Favorite.query.filter_by(user_id=user_id).delete()
    db.session.query(SearchHistory).filter_by(user_id=user_id).delete()
    Notification.query.filter_by(user_id=user_id).delete()
    UserReport.query.filter_by(user_id=user_id).delete()
    AnalyticsEvent.query.filter_by(user_id=user_id).update({"user_id": None})
    db.session.delete(user)
    db.session.commit()

  @staticmethod
  def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

  @staticmethod
  def _verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
