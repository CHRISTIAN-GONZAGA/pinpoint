"""Maps overlay API routes."""

from flask import Blueprint, jsonify

from app.services.transport_service import TransportService

maps_bp = Blueprint("maps", __name__)
_transport = TransportService()


@maps_bp.get("/tricycle-zones")
def list_tricycle_zones():
  return jsonify({"zones": _transport.list_tricycle_zones()}), 200
