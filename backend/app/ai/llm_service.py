"""LLM abstraction with OpenAI-compatible API and grounded fallback."""

from __future__ import annotations

import os

from app.ai.prompt_builder import build_prompt
from app.ai.vector_store import RetrievedChunk

_UNAVAILABLE = {
  "en": "I don't have verified information about that in the PINPOINT knowledge base yet. Please try asking about jeepney routes, fares, tourist spots, or emergency contacts in Butuan City.",
  "tl": "Wala pa akong verified na impormasyon tungkol diyan sa PINPOINT knowledge base. Subukan mong magtanong tungkol sa jeepney routes, pamasahe, tourist spots, o emergency contacts sa Butuan City.",
  "ceb": "Wala pa koy verified nga impormasyon bahin ana sa PINPOINT knowledge base. Palihog pangutana bahin sa jeepney routes, plete, tourist spots, o emergency contacts sa Butuan City.",
  "mixed": "Wala pa koy verified nga impormasyon / impormasyon tungkol diyan. Please ask about jeepney routes, fares, tourist spots, or emergency contacts in Butuan City.",
}


class LLMService:
  """Generate grounded responses via API or local template."""

  def __init__(
    self,
    *,
    model: str | None = None,
    api_key: str | None = None,
    base_url: str | None = None,
  ) -> None:
    self._model = model or os.getenv("AI_MODEL", "gpt-4o-mini")
    self._api_key = api_key or os.getenv("OPENAI_API_KEY") or os.getenv("OPENROUTER_KEY", "")
    self._base_url = base_url or os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")

  @property
  def has_remote_model(self) -> bool:
    return bool(self._api_key)

  def generate(
    self,
    *,
    query: str,
    language: str,
    chunks: list[RetrievedChunk],
    history: list[dict[str, str]] | None = None,
  ) -> str:
    if not chunks:
      return _UNAVAILABLE.get(language, _UNAVAILABLE["en"])

    if self.has_remote_model:
      try:
        return self._generate_remote(
          query=query, language=language, chunks=chunks, history=history
        )
      except Exception:
        pass

    return self._generate_grounded(language=language, chunks=chunks)

  def _generate_remote(
    self,
    *,
    query: str,
    language: str,
    chunks: list[RetrievedChunk],
    history: list[dict[str, str]] | None,
  ) -> str:
    from openai import OpenAI

    client = OpenAI(api_key=self._api_key, base_url=self._base_url)
    messages = build_prompt(
      query=query, language=language, chunks=chunks, history=history
    )
    response = client.chat.completions.create(
      model=self._model,
      messages=messages,
      temperature=0.2,
      max_tokens=500,
    )
    content = response.choices[0].message.content
    return content.strip() if content else self._generate_grounded(language, chunks)

  def _generate_grounded(self, language: str, chunks: list[RetrievedChunk]) -> str:
    intro = {
      "en": "Based on verified PINPOINT information:",
      "tl": "Ayon sa verified na impormasyon ng PINPOINT:",
      "ceb": "Base sa verified nga impormasyon sa PINPOINT:",
      "mixed": "Based sa verified PINPOINT information:",
    }.get(language, "Based on verified PINPOINT information:")

    body = "\n\n".join(f"• {chunk.content}" for chunk in chunks[:3])
    return f"{intro}\n\n{body}"
