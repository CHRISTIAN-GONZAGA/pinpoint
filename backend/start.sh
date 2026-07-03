#!/bin/sh
set -e
PORT="${PORT:-5000}"
exec gunicorn \
  --bind "0.0.0.0:${PORT}" \
  --workers 2 \
  --threads 4 \
  --timeout 120 \
  wsgi:app
