"""Route PDF generation for sharing and offline reference."""

from __future__ import annotations

import io
from datetime import datetime, timezone

from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas


class PdfService:
  """Builds printable route summaries."""

  def generate_route_pdf(self, payload: dict) -> bytes:
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter
    y = height - inch

    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(inch, y, "PINPOINT Route Summary")
    y -= 0.35 * inch

    pdf.setFont("Helvetica", 10)
    pdf.drawString(
      inch,
      y,
      f"Generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
    )
    y -= 0.45 * inch

    origin = payload.get("origin_label", "Current location")
    destination = payload.get("destination_label", "Destination")
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(inch, y, f"From: {origin}")
    y -= 0.3 * inch
    pdf.drawString(inch, y, f"To: {destination}")
    y -= 0.45 * inch

    pdf.setFont("Helvetica", 11)
    stats = [
      f"Distance: {payload.get('distance_label', 'N/A')}",
      f"Duration: {payload.get('duration_label', 'N/A')}",
      f"Estimated fare: PHP {payload.get('estimated_fare', 0):.2f}",
    ]
    for line in stats:
      pdf.drawString(inch, y, line)
      y -= 0.28 * inch

    y -= 0.2 * inch
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(inch, y, "Directions")
    y -= 0.35 * inch
    pdf.setFont("Helvetica", 10)

    for step in payload.get("steps", []):
      instruction = step.get("instruction", "")
      duration = step.get("duration_label", "")
      line = f"• {instruction}"
      if duration:
        line += f" ({duration})"
      for wrapped in self._wrap_text(line, 88):
        if y < inch:
          pdf.showPage()
          y = height - inch
          pdf.setFont("Helvetica", 10)
        pdf.drawString(inch, y, wrapped)
        y -= 0.24 * inch
      y -= 0.05 * inch

    pdf.setFont("Helvetica-Oblique", 9)
    pdf.drawString(
      inch,
      0.75 * inch,
      "PINPOINT — Butuan City Public Transport & Tourism",
    )
    pdf.showPage()
    pdf.save()
    buffer.seek(0)
    return buffer.getvalue()

  def _wrap_text(self, text: str, max_chars: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
      candidate = f"{current} {word}".strip()
      if len(candidate) <= max_chars:
        current = candidate
      else:
        if current:
          lines.append(current)
        current = word
    if current:
      lines.append(current)
    return lines or [text[:max_chars]]
