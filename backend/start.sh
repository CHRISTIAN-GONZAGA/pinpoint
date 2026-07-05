#!/bin/sh
set -e
PORT="${PORT:-5000}"

# Seed once in the master process before gunicorn forks workers (avoids FK races).
if [ "${AUTO_SEED:-false}" = "true" ]; then
  python -c "from wsgi import app" 2>/dev/null || python -c "from wsgi import app"
fi

exec env AUTO_SEED=false gunicorn \
  --bind "0.0.0.0:${PORT}" \
  --workers 2 \
  --threads 4 \
  --timeout 120 \
  wsgi:app
