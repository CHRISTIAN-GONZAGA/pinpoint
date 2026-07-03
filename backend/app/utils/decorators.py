"""Route decorators for role-based access."""

from functools import wraps

from flask import jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models.user import User


def admin_required():
  """Require an authenticated administrator account."""

  def decorator(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
      user_id = int(get_jwt_identity())
      user = db.session.get(User, user_id)
      if not user or user.role != "admin":
        return jsonify({"message": "Administrator access required"}), 403
      return fn(*args, **kwargs)

    return wrapper

  return decorator
