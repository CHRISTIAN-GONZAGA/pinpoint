"""Simple in-memory rate limiting for sensitive auth endpoints."""

from __future__ import annotations

import time
from collections import defaultdict, deque
from functools import wraps
from typing import Callable

from flask import current_app, jsonify, request


class RateLimiter:
  """Tracks request timestamps per client key."""

  def __init__(self) -> None:
    self._requests: dict[str, deque[float]] = defaultdict(deque)

  def allow(self, key: str, *, limit: int, window_seconds: int) -> bool:
    now = time.time()
    bucket = self._requests[key]
    while bucket and now - bucket[0] > window_seconds:
      bucket.popleft()
    if len(bucket) >= limit:
      return False
    bucket.append(now)
    return True


_limiter = RateLimiter()


def rate_limit(
  limit: int = 10,
  window_seconds: int = 60,
  *,
  key_func: Callable[[], str] | None = None,
):
  """Decorator limiting requests by IP or a caller-provided identity key."""

  def decorator(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
      client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")
      identity = key_func() if key_func else client_ip
      key = f"{request.endpoint}:{identity}"
      if not _limiter.allow(key, limit=limit, window_seconds=window_seconds):
        return jsonify({"message": "Too many requests. Please try again later."}), 429
      return view(*args, **kwargs)

    return wrapped

  return decorator


def reset_rate_limiter() -> None:
  """Clear rate limit state (used in tests)."""
  _limiter._requests.clear()
