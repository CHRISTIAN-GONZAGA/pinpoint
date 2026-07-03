"""Fare matrix API routes."""

from flask import Blueprint, jsonify

from app.services.transport_service import TransportService

fares_bp = Blueprint("fares", __name__)
_transport = TransportService()


@fares_bp.get("")
def list_fares():
  return jsonify({"fares": _transport.list_fares()}), 200
