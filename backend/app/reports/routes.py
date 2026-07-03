"""User report submission and tracking."""

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.extensions import db
from app.models.system import UserReport

reports_bp = Blueprint("reports", __name__)


@reports_bp.post("")
@jwt_required()
def submit_report():
  payload = request.get_json() or {}
  category = (payload.get("category") or "").strip()
  description = (payload.get("description") or "").strip()
  if not category or not description:
    return jsonify({"message": "category and description are required"}), 400

  report = UserReport(
    user_id=int(get_jwt_identity()),
    category=category,
    description=description,
    latitude=payload.get("latitude"),
    longitude=payload.get("longitude"),
  )
  db.session.add(report)
  db.session.commit()
  return jsonify(report.to_dict()), 201


@reports_bp.get("/mine")
@jwt_required()
def my_reports():
  user_id = int(get_jwt_identity())
  reports = (
    UserReport.query.filter_by(user_id=user_id)
    .order_by(UserReport.created_at.desc())
    .limit(50)
    .all()
  )
  return jsonify({"reports": [report.to_dict() for report in reports]}), 200
