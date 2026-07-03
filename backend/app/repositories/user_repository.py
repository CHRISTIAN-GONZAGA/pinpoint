"""User data access layer."""

from app.extensions import db
from app.models.user import User


class UserRepository:
  """Repository for user persistence operations."""

  def get_by_email(self, email: str) -> User | None:
    return User.query.filter_by(email=email.lower()).first()

  def get_by_id(self, user_id: int) -> User | None:
    return db.session.get(User, user_id)

  def create(
    self,
    *,
    full_name: str,
    email: str,
    password_hash: str,
    mobile_number: str | None = None,
    role: str = "user",
  ) -> User:
    user = User(
      full_name=full_name.strip(),
      email=email.lower().strip(),
      password_hash=password_hash,
      mobile_number=mobile_number,
      role=role,
    )
    db.session.add(user)
    db.session.commit()
    return user
