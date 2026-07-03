"""Structured logging configuration."""

from __future__ import annotations

import logging
import sys


def configure_logging(debug: bool = False) -> None:
  """Configure application-wide logging."""
  level = logging.DEBUG if debug else logging.INFO
  logging.basicConfig(
    level=level,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
  )
  logging.getLogger("werkzeug").setLevel(logging.WARNING if not debug else logging.INFO)
