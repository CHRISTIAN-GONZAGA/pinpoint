"""Transportation API routes."""

from flask import Blueprint, jsonify, request

from app.services.transport_service import TransportService

routes_bp = Blueprint("routes", __name__)
_transport = TransportService()


@routes_bp.get("")
def list_routes():
  return jsonify({"routes": _transport.list_routes()}), 200


@routes_bp.get("/search")
def search_routes():
  query = request.args.get("q", "").strip()
  if not query:
    return jsonify({"routes": []}), 200
  return jsonify({"routes": _transport.search_routes(query)}), 200


@routes_bp.get("/<int:route_id>")
def get_route(route_id: int):
  route = _transport.get_route(route_id)
  if not route:
    return jsonify({"message": "Route not found"}), 404
  return jsonify(route), 200
