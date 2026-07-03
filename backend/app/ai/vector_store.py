"""Keyword-based retrieval with optional ChromaDB backend."""

from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass, field
from typing import Any


@dataclass
class RetrievedChunk:
  """A knowledge chunk returned by retrieval."""

  document_id: str
  title: str
  content: str
  category: str
  score: float
  metadata: dict[str, Any] = field(default_factory=dict)


class InMemoryVectorStore:
  """Lightweight retrieval store using token overlap scoring."""

  def __init__(self) -> None:
    self._chunks: list[RetrievedChunk] = []

  def clear(self) -> None:
    self._chunks.clear()

  def add_documents(self, documents: list[dict[str, Any]]) -> int:
    self._chunks.clear()
    for doc in documents:
      for idx, chunk in enumerate(doc["chunks"]):
        self._chunks.append(
          RetrievedChunk(
            document_id=f"{doc['document_id']}:{idx}",
            title=doc["title"],
            content=chunk,
            category=doc.get("category", "general"),
            score=0.0,
            metadata=doc.get("metadata", {}),
          )
        )
    return len(self._chunks)

  def search(self, query: str, top_k: int = 5) -> list[RetrievedChunk]:
    if not self._chunks:
      return []
    query_tokens = _tokenize(query)
    if not query_tokens:
      return []

    scored: list[RetrievedChunk] = []
    for chunk in self._chunks:
      content_tokens = _tokenize(f"{chunk.title} {chunk.content}")
      if not content_tokens:
        continue
      overlap = query_tokens & content_tokens
      if not overlap:
        continue
      score = len(overlap) / math.sqrt(len(query_tokens) * len(content_tokens))
      scored.append(
        RetrievedChunk(
          document_id=chunk.document_id,
          title=chunk.title,
          content=chunk.content,
          category=chunk.category,
          score=round(score, 4),
          metadata=chunk.metadata,
        )
      )

    scored.sort(key=lambda item: item.score, reverse=True)
    return scored[:top_k]


class VectorStoreManager:
  """Facade for vector retrieval with optional ChromaDB."""

  def __init__(self, use_chroma: bool = False, persist_path: str = "./chroma_data") -> None:
    self._memory = InMemoryVectorStore()
    self._use_chroma = use_chroma
    self._persist_path = persist_path
    self._chroma_collection = None
    if use_chroma:
      self._init_chroma()

  def _init_chroma(self) -> None:
    try:
      import chromadb

      client = chromadb.PersistentClient(path=self._persist_path)
      self._chroma_collection = client.get_or_create_collection("pinpoint_kb")
    except Exception:
      self._use_chroma = False
      self._chroma_collection = None

  def index_documents(self, documents: list[dict[str, Any]]) -> int:
    count = self._memory.add_documents(documents)
    if self._use_chroma and self._chroma_collection is not None:
      try:
        ids: list[str] = []
        texts: list[str] = []
        metadatas: list[dict[str, Any]] = []
        for doc in documents:
          for idx, chunk in enumerate(doc["chunks"]):
            ids.append(f"{doc['document_id']}:{idx}")
            texts.append(chunk)
            metadatas.append(
              {
                "title": doc["title"],
                "category": doc.get("category", "general"),
                **{
                  k: v
                  for k, v in doc.get("metadata", {}).items()
                  if isinstance(v, (str, int, float, bool))
                },
              }
            )
        if ids:
          self._chroma_collection.upsert(ids=ids, documents=texts, metadatas=metadatas)
      except Exception:
        pass
    return count

  def search(self, query: str, top_k: int = 5) -> list[RetrievedChunk]:
    if self._use_chroma and self._chroma_collection is not None:
      try:
        result = self._chroma_collection.query(query_texts=[query], n_results=top_k)
        docs = result.get("documents", [[]])[0]
        metas = result.get("metadatas", [[]])[0]
        distances = result.get("distances", [[]])[0]
        ids = result.get("ids", [[]])[0]
        chunks: list[RetrievedChunk] = []
        for idx, content in enumerate(docs):
          meta = metas[idx] if idx < len(metas) else {}
          distance = distances[idx] if idx < len(distances) else 1.0
          score = max(0.0, 1.0 - distance)
          chunks.append(
            RetrievedChunk(
              document_id=ids[idx] if idx < len(ids) else str(idx),
              title=meta.get("title", "Knowledge"),
              content=content,
              category=meta.get("category", "general"),
              score=round(score, 4),
              metadata=meta,
            )
          )
        if chunks:
          return chunks
      except Exception:
        pass
    return self._memory.search(query, top_k=top_k)


def _tokenize(text: str) -> set[str]:
  tokens = re.findall(r"[a-zA-Z0-9]+", text.lower())
  stop = {"the", "a", "an", "to", "in", "of", "and", "or", "is", "sa", "ang", "ug"}
  return {token for token in tokens if token not in stop and len(token) > 1}
