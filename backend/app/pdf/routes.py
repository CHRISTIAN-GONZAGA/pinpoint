"""PDF export API routes."""

from flask import Blueprint, jsonify, request, send_file
from io import BytesIO

from app.services.pdf_service import PdfService

pdf_bp = Blueprint("pdf", __name__)
_service = PdfService()


@pdf_bp.post("/route")
def export_route_pdf():
  payload = request.get_json() or {}
  if not payload.get("destination_label"):
    return jsonify({"message": "destination_label is required"}), 400
  pdf_bytes = _service.generate_route_pdf(payload)
  return send_file(
    BytesIO(pdf_bytes),
    mimetype="application/pdf",
    as_attachment=True,
    download_name="pinpoint-route.pdf",
  )
