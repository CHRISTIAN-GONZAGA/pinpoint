"""In-memory session memory for AI conversations."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class SessionState:
  """Lightweight per-session conversation context."""

  language: str = "en"
  messages: list[dict[str, str]] = field(default_factory=list)
  last_destination: str | None = None


class ConversationMemoryManager:
  """Stores recent session messages without persistent sensitive storage."""

  def __init__(self, max_messages: int = 8) -> None:
    self._sessions: dict[str, SessionState] = {}
    self._max_messages = max_messages

  def get(self, session_id: str) -> SessionState:
    return self._sessions.setdefault(session_id, SessionState())

  def add_exchange(self, session_id: str, question: str, answer: str, language: str) -> None:
    state = self.get(session_id)
    state.language = language
    state.messages.append({"role": "user", "content": question})
    state.messages.append({"role": "assistant", "content": answer})
    state.messages = state.messages[-self._max_messages :]

  def clear(self, session_id: str) -> None:
    self._sessions.pop(session_id, None)
