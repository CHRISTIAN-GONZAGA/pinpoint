#!/usr/bin/env python3
"""Force re-import LPTRP routes from assets into the database (Render / local)."""

from app import create_app
from app.utilities.lptrp_loader import import_lptrp_routes


def main() -> None:
  app = create_app()
  with app.app_context():
    count = import_lptrp_routes(force=True)
    print(f"Imported {count} LPTRP routes from assets.")


if __name__ == "__main__":
  main()
