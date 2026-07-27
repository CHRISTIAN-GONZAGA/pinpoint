"""Public featured destinations API."""

from flask import Blueprint, jsonify

from app.models.places import FeaturedDestination

destinations_bp = Blueprint("destinations", __name__)


@destinations_bp.get("/featured")
def list_featured_destinations():
  rows = (
    FeaturedDestination.query.filter_by(active_status=True)
    .order_by(FeaturedDestination.sort_order.asc(), FeaturedDestination.name.asc())
    .all()
  )
  return jsonify({"destinations": [row.to_dict() for row in rows]}), 200
