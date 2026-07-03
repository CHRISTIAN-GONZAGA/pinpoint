"""Administrator-managed knowledge base documents."""

import json
from datetime import datetime, timezone

from app.extensions import db


def utcnow() -> datetime:
  return datetime.now(timezone.utc)


class KnowledgeDocument(db.Model):
  """Verified document indexed for RAG retrieval."""

  __tablename__ = "knowledge_documents"

  document_id = db.Column(db.Integer, primary_key=True)
  title = db.Column(db.String(200), nullable=False)
  content = db.Column(db.Text, nullable=False)
  category = db.Column(db.String(50), nullable=False, index=True)
  language = db.Column(db.String(10), nullable=False, default="en")
  metadata_json = db.Column(db.Text, nullable=True)
  embedding_status = db.Column(db.String(20), nullable=False, default="pending")
  active_status = db.Column(db.Boolean, nullable=False, default=True)
  created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
  updated_at = db.Column(
    db.DateTime, nullable=False, default=utcnow, onupdate=utcnow
  )

  def to_dict(self) -> dict:
    return {
      "document_id": self.document_id,
      "title": self.title,
      "content": self.content,
      "category": self.category,
      "language": self.language,
      "metadata": json.loads(self.metadata_json) if self.metadata_json else {},
      "embedding_status": self.embedding_status,
      "active_status": self.active_status,
    }
