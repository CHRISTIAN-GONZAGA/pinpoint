"""Build grounded prompts for the LLM."""

from __future__ import annotations

from app.ai.vector_store import RetrievedChunk

SYSTEM_INSTRUCTIONS = """You are PINPOINT, a specialized transportation and tourism assistant for Butuan City, Philippines.
Answer ONLY using the verified context provided below.
Never invent routes, fares, schedules, or locations.
If the context does not contain the answer, clearly say the information is unavailable.
Respond in the same language style as the user.
Keep answers concise, helpful, and practical for commuters and tourists."""


def build_prompt(
  *,
  query: str,
  language: str,
  chunks: list[RetrievedChunk],
  history: list[dict[str, str]] | None = None,
) -> list[dict[str, str]]:
  """Construct chat messages for an OpenAI-compatible API."""
  context = _format_context(chunks)
  history_text = ""
  if history:
    history_text = "\n".join(
      f"{item['role']}: {item['content']}" for item in history[-4:]
    )

  user_prompt = f"""Language preference: {language}
Conversation history:
{history_text or 'None'}

Verified context:
{context or 'No relevant verified information was retrieved.'}

User question:
{query}

Instructions:
- Use only the verified context.
- If context is insufficient, say you do not have verified information.
- Mention jeepney route codes when relevant.
- Do not answer unrelated general knowledge questions."""

  return [
    {"role": "system", "content": SYSTEM_INSTRUCTIONS},
    {"role": "user", "content": user_prompt},
  ]


def _format_context(chunks: list[RetrievedChunk]) -> str:
  if not chunks:
    return ""
  lines: list[str] = []
  for idx, chunk in enumerate(chunks, start=1):
    lines.append(
      f"[{idx}] {chunk.title} ({chunk.category}, score={chunk.score})\n{chunk.content}"
    )
  return "\n\n".join(lines)
