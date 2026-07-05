FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_ENV=production \
    DEBUG_MODE=false \
    AUTO_SEED=false \
    PORT=10000

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .
COPY assets/data/routes/jeepney_routes.json /app/data/lptrp_routes.json
RUN chmod +x /app/start.sh && mkdir -p /app/instance /app/chroma_data /app/data

EXPOSE 10000

CMD ["/app/start.sh"]
