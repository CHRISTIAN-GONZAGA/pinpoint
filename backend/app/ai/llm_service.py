"""Gemini-backed response generation for the PINPOINT RAG assistant."""

from __future__ import annotations

from typing import Any

import httpx

from app.ai.prompt_builder import build_prompt
from app.ai.vector_store import RetrievedChunk


class AIProviderError(RuntimeError):
  """An AI-provider failure with a safe message and HTTP status for clients."""

  def __init__(self, message: str, status_code: int = 503) -> None:
    super().__init__(message)
    self.public_message = message
    self.status_code = status_code


class LLMService:
  """Generate context-grounded responses with Google's Gemini API."""

  def __init__(
    self,
    *,
    model: str | None = None,
    api_key: str | None = None,
    client: Any | None = None,
  ) -> None:
    self._model = model or "gemini-3.5-flash-lite"
    self._api_key = (api_key or "").strip()
    self._client = client

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
    if not self.has_remote_model:
      raise AIProviderError(
        "Gemini is not configured on the server. Set GEMINI_API_KEY to enable AI chat."
      )

    prompt = build_prompt(
      query=query, language=language, chunks=chunks, history=history
    )
    return self._generate_remote(prompt)

  def _generate_remote(self, prompt: dict[str, Any]) -> str:
    from google import genai
    from google.genai import errors, types

    client = self._client
    if client is None:
      client = genai.Client(
        api_key=self._api_key,
        http_options=types.HttpOptions(timeout=18_000),
      )
      self._client = client

    try:
      response = client.models.generate_content(
        model=self._model,
        contents=prompt["contents"],
        config={
          "system_instruction": prompt["system_instruction"],
          "temperature": 0.2,
          "max_output_tokens": 350,
        },
      )
    except errors.APIError as error:
      code = getattr(error, "code", None)
      if code == 429 or str(code) == "429":
        raise AIProviderError(
          "Gemini's free-tier quota or rate limit has been reached. Please try again later; no paid-model fallback is used.",
          status_code=429,
        ) from None
      if str(code) == "401":
        raise AIProviderError(
          "Gemini rejected GEMINI_API_KEY. Create or rotate a Gemini API key in Google AI Studio, then update the server-side key.",
          status_code=503,
        ) from None
      if str(code) == "403":
        raise AIProviderError(
          "Google denied this key access to the configured Gemini model. Confirm the Google AI Studio project has Gemini API access and that GEMINI_MODEL is available to the key.",
          status_code=503,
        ) from None
      raise AIProviderError(
        "Gemini could not complete the request. Please try again later.",
        status_code=503,
      ) from None
    except httpx.TimeoutException:
      raise AIProviderError(
        "Gemini took too long to respond. Please try again.",
        status_code=504,
      ) from None
    except httpx.TransportError:
      raise AIProviderError(
        "Gemini is temporarily unavailable. Please try again later.",
        status_code=503,
      ) from None

    answer = response.text
    if not answer or not answer.strip():
      raise AIProviderError(
        "Gemini returned an empty response. Please try again.",
        status_code=502,
      )
    return answer.strip()
