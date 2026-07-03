"""Synchronize SQL knowledge documents into the vector store."""

from __future__ import annotations

import json

from app.ai.chunking import chunk_text
from app.extensions import db
from app.models.knowledge import KnowledgeDocument
from app.models.places import EmergencyContact, Establishment, TouristAttraction
from app.models.transport import FareMatrix, JeepneyRoute, TricycleZone


def build_documents_from_database() -> list[dict]:
  """Create retrieval documents from verified database content."""
  documents: list[dict] = []

  for doc in KnowledgeDocument.query.filter_by(active_status=True).all():
    documents.append(_to_index_doc(doc.to_dict()))

  for route in JeepneyRoute.query.filter_by(active_status=True).all():
    stops = ", ".join(stop.stop_name for stop in route.stops)
    content = (
      f"{route.route_name} ({route.route_code}) serves Butuan City. "
      f"Description: {route.description or 'Official jeepney route.'} "
      f"Operating hours: {route.operating_hours or 'Varies'}. "
      f"Stops include: {stops}."
    )
    documents.append(
      {
        "document_id": f"route-{route.route_id}",
        "title": route.route_name,
        "category": "transport",
        "chunks": chunk_text(content),
        "metadata": {
          "route_code": route.route_code,
          "route_id": route.route_id,
        },
      }
    )

  for fare in FareMatrix.query.all():
    content = (
      f"The {fare.transport_type} minimum fare is PHP {fare.minimum_fare:.2f}. "
      f"Each succeeding kilometer costs PHP {fare.succeeding_rate:.2f}. "
      f"Effective date: {fare.effective_date.isoformat()}."
    )
    documents.append(
      {
        "document_id": f"fare-{fare.fare_id}",
        "title": f"{fare.transport_type.title()} Fare Matrix",
        "category": "fare",
        "chunks": chunk_text(content),
        "metadata": {"transport_type": fare.transport_type},
      }
    )

  for zone in TricycleZone.query.filter_by(active_status=True).all():
    content = (
      f"Tricycle {zone.zone_name} has a base fare of PHP {zone.base_fare:.2f}. "
      f"Notes: {zone.notes or 'Official tricycle service zone in Butuan City.'}"
    )
    documents.append(
      {
        "document_id": f"zone-{zone.zone_id}",
        "title": zone.zone_name,
        "category": "transport",
        "chunks": chunk_text(content),
        "metadata": {"zone_id": zone.zone_id},
      }
    )

  for attraction in TouristAttraction.query.filter_by(active_status=True).all():
    content = (
      f"{attraction.name} is a tourist attraction in Butuan City at {attraction.address or 'Butuan'}. "
      f"{attraction.description or ''} "
      f"Entrance fee: {attraction.entrance_fee or 'Not specified'}. "
      f"Hours: {attraction.opening_hours or 'Not specified'}."
    )
    documents.append(
      {
        "document_id": f"attraction-{attraction.attraction_id}",
        "title": attraction.name,
        "category": "tourism",
        "chunks": chunk_text(content),
        "metadata": {
          "place_type": "attraction",
          "place_id": attraction.attraction_id,
          "latitude": attraction.latitude,
          "longitude": attraction.longitude,
        },
      }
    )

  for est in Establishment.query.filter_by(active_status=True).all():
    content = (
      f"{est.name} is a {est.category.replace('_', ' ')} in Butuan City. "
      f"Address: {est.address or 'Butuan City'}. "
      f"Contact: {est.contact_information or 'Not listed'}."
    )
    documents.append(
      {
        "document_id": f"establishment-{est.establishment_id}",
        "title": est.name,
        "category": est.category,
        "chunks": chunk_text(content),
        "metadata": {
          "place_type": "establishment",
          "place_id": est.establishment_id,
          "latitude": est.latitude,
          "longitude": est.longitude,
        },
      }
    )

  for contact in EmergencyContact.query.filter_by(active_status=True).all():
    content = (
      f"Emergency contact: {contact.agency}. Hotline: {contact.hotline}. "
      f"Category: {contact.category}. Availability: {contact.availability or '24/7'}."
    )
    metadata = {"category": contact.category, "hotline": contact.hotline}
    if contact.latitude is not None and contact.longitude is not None:
      metadata.update({"latitude": contact.latitude, "longitude": contact.longitude})
    documents.append(
      {
        "document_id": f"emergency-{contact.contact_id}",
        "title": contact.agency,
        "category": "emergency",
        "chunks": chunk_text(content),
        "metadata": metadata,
      }
    )

  return documents


def seed_knowledge_documents() -> None:
  """Insert FAQ documents if the knowledge base is empty."""
  if KnowledgeDocument.query.count() > 0:
    return

  faqs = [
    (
      "PINPOINT Transportation Scope",
      "PINPOINT provides verified jeepney routes R1 to R7, tricycle zones, fare information, tourist attractions, and emergency contacts for Butuan City only.",
      "general",
    ),
    (
      "Jeepney Route Tip",
      "Route R2 connects Baan Junction to Robinsons Place Butuan. Route R3 serves downtown to SM City Butuan.",
      "transport",
    ),
    (
      "Fare Reminder",
      "Jeepney and tricycle fares in PINPOINT are based on administrator-maintained fare matrices and may change when updated by officials.",
      "fare",
    ),
    (
      "Emergency Reminder",
      "For immediate danger, call 911. Butuan Medical Center and Caraga Regional Hospital are major hospitals in the city.",
      "emergency",
    ),
  ]

  for title, content, category in faqs:
    db.session.add(
      KnowledgeDocument(
        title=title,
        content=content,
        category=category,
        language="en",
        metadata_json=json.dumps({}),
        embedding_status="indexed",
        active_status=True,
      )
    )
  db.session.commit()


def _to_index_doc(doc: dict) -> dict:
  return {
    "document_id": f"kb-{doc['document_id']}",
    "title": doc["title"],
    "category": doc["category"],
    "chunks": chunk_text(doc["content"]),
    "metadata": doc.get("metadata", {}),
  }
