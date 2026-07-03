"""WSGI entry point for Gunicorn."""

from app import create_app
from app.config.config import ProductionConfig
import os

config = ProductionConfig if os.getenv("FLASK_ENV") == "production" else None
app = create_app(config) if config else create_app()
