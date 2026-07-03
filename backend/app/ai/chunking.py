"""Text chunking for knowledge base indexing."""

from __future__ import annotations


def chunk_text(
  text: str,
  *,
  chunk_size: int = 500,
  overlap: int = 80,
) -> list[str]:
  """Split text into overlapping semantic chunks without breaking sentences."""
  text = " ".join(text.split())
  if len(text) <= chunk_size:
    return [text]

  sentences = _split_sentences(text)
  chunks: list[str] = []
  current = ""

  for sentence in sentences:
    if len(current) + len(sentence) + 1 <= chunk_size:
      current = f"{current} {sentence}".strip()
      continue
    if current:
      chunks.append(current)
    if len(sentence) <= chunk_size:
      current = sentence
    else:
      for i in range(0, len(sentence), chunk_size - overlap):
        part = sentence[i : i + chunk_size]
        if part.strip():
          chunks.append(part.strip())
      current = ""

  if current:
    chunks.append(current)

  if overlap > 0 and len(chunks) > 1:
    merged: list[str] = []
    prev_tail = ""
    for chunk in chunks:
      merged.append(f"{prev_tail} {chunk}".strip() if prev_tail else chunk)
      prev_tail = chunk[-overlap:] if len(chunk) > overlap else chunk
    return merged

  return chunks


def _split_sentences(text: str) -> list[str]:
  parts: list[str] = []
  start = 0
  for idx, char in enumerate(text):
    if char in ".!?\n" and idx > start:
      parts.append(text[start : idx + 1].strip())
      start = idx + 1
  if start < len(text):
    parts.append(text[start:].strip())
  return [part for part in parts if part]
