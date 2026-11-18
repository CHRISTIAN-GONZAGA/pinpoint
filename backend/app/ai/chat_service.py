"""RAG chat orchestration service."""

from __future__ import annotations

import uuid
from typing import Any

from flask import current_app

from app.ai.conversation_memory import ConversationMemoryManager
from app.ai.knowledge_sync import build_documents_from_database
from app.ai.language_detector import detect_language
from app.ai.llm_service import LLMService
from app.ai.vector_store import RetrievedChunk, VectorStoreManager


class ChatService:
  """Coordinates retrieval-augmented generation for PINPOINT."""

  _memory = ConversationMemoryManager()
  _vector_store: VectorStoreManager | None = None
  _llm: LLMService | None = None
  _indexed = False

  def __init__(self) -> None:
    pass

  def _ensure_services(self) -> None:
    if self._vector_store is None:
      self._vector_store = VectorStoreManager(
        use_chroma=current_app.config.get("AI_USE_CHROMA", False),
        persist_path=current_app.config.get("VECTOR_DB_PATH", "./chroma_data"),
      )
    if self._llm is None:
      self._llm = LLMService(
        model=current_app.config.get("GEMINI_MODEL"),
        api_key=current_app.config.get("GEMINI_API_KEY"),
      )

  def ensure_index(self) -> int:
    self._ensure_services()
    documents = build_documents_from_database()
    count = self._vector_store.index_documents(documents)  # type: ignore[union-attr]
    self._indexed = True
    return count

  def chat(
    self,
    *,
    message: str,
    session_id: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    response_language: str | None = None,
    history: list[dict[str, str]] | None = None,
  ) -> dict[str, Any]:
    self._ensure_services()
    if not self._indexed:
      self.ensure_index()

    session_id = session_id or str(uuid.uuid4())
    language = self._resolve_language(message, response_language)
    conversation = history if history is not None else self._memory.get(session_id).messages
    query = self._build_retrieval_query(
      message, conversation, latitude=latitude, longitude=longitude
    )
    top_k = current_app.config.get("AI_RETRIEVAL_TOP_K", 5)
    chunks = self._vector_store.search(query, top_k=top_k)  # type: ignore[union-attr]
    response = self._llm.generate(  # type: ignore[union-attr]
      query=message,
      language=language,
      chunks=chunks,
      history=conversation,
    )
    self._memory.add_exchange(session_id, message, response, language)

    return self._build_payload(
      response=response,
      language=language,
      session_id=session_id,
      chunks=chunks,
    )

  def clear_session(self, session_id: str) -> None:
    self._memory.clear(session_id)

  @staticmethod
  def _resolve_language(message: str, response_language: str | None) -> str:
    preferred = (response_language or "").strip().lower()
    if preferred and preferred not in {"auto", "mixed"}:
      return preferred
    return detect_language(message)

  @staticmethod
  def _build_retrieval_query(
    message: str,
    history: list[dict[str, str]],
    *,
    latitude: float | None = None,
    longitude: float | None = None,
  ) -> str:
    previous_questions = [
      item["content"]
      for item in history[-8:]
      if item.get("role") == "user" and item.get("content")
    ][-2:]
    query = " ".join([*previous_questions, message])
    if latitude is not None and longitude is not None and "near me" in message.lower():
      query = f"{query} Butuan City near coordinates {latitude}, {longitude}"
    return query

  def status(self) -> dict[str, Any]:
    self._ensure_services()
    return {
      "indexed": self._indexed,
      "remote_llm_enabled": bool(self._llm and self._llm.has_remote_model),
      "vector_backend": "chroma" if current_app.config.get("AI_USE_CHROMA") else "memory",
    }

  def _build_payload(
    self,
    *,
    response: str,
    language: str,
    session_id: str,
    chunks: list[RetrievedChunk],
  ) -> dict[str, Any]:
    confidence = chunks[0].score if chunks else 0.0
    return {
      "response": response,
      "language": language,
      "session_id": session_id,
      "sources": [
        {
          "title": chunk.title,
          "category": chunk.category,
          "score": chunk.score,
          "excerpt": chunk.content[:180],
        }
        for chunk in chunks[:3]
      ],
      "actions": self._extract_actions(chunks),
      "retrieval_confidence": confidence,
    }

  def _extract_actions(self, chunks: list[RetrievedChunk]) -> list[dict[str, Any]]:
    actions: list[dict[str, Any]] = []
    seen: set[str] = set()
    for chunk in chunks:
      metadata = chunk.metadata or {}
      lat = metadata.get("latitude")
      lng = metadata.get("longitude")
      if lat is None or lng is None:
        continue
      key = f"{chunk.title}:{lat}:{lng}"
      if key in seen:
        continue
      seen.add(key)
      actions.append(
        {
          "type": "view_on_map",
          "label": chunk.title,
          "latitude": float(lat),
          "longitude": float(lng),
          "place_type": metadata.get("place_type"),
          "place_id": metadata.get("place_id"),
          "route_code": metadata.get("route_code"),
        }
      )
    return actions[:3]
