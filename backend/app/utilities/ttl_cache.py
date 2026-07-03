"""TTL memoization for read-heavy service methods."""

from __future__ import annotations

import time
from functools import wraps
from typing import Any, Callable


def ttl_cache(seconds: int = 60) -> Callable:
  """Cache function results keyed by arguments for a short TTL window."""

  def decorator(fn: Callable) -> Callable:
    store: dict[str, tuple[float, Any]] = {}

    @wraps(fn)
    def wrapper(*args: Any, **kwargs: Any):
      key = repr((args, tuple(sorted(kwargs.items()))))
      now = time.time()
      entry = store.get(key)
      if entry and now < entry[0]:
        return entry[1]
      value = fn(*args, **kwargs)
      store[key] = (now + seconds, value)
      return value

    def cache_clear() -> None:
      store.clear()

    wrapper.cache_clear = cache_clear  # type: ignore[attr-defined]
    return wrapper

  return decorator
