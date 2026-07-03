"""PINPOINT Flask application factory."""

from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from sqlalchemy import text

from app.config.config import Config
from app.extensions import db
from app.middleware.security import register_security_headers
from app.utilities.logging_config import configure_logging


def create_app(config_class: type[Config] = Config) -> Flask:
    """Create and configure the Flask application."""
    app = Flask(__name__)
    app.config.from_object(config_class)

    configure_logging(debug=app.config.get("DEBUG", False))
    db.init_app(app)
    Migrate(app, db)
    JWTManager(app)
    CORS(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})
    register_security_headers(app)

    from app.auth.routes import auth_bp
    from app.users.routes import users_bp
    from app.routes.transport_routes import routes_bp
    from app.maps.routes import maps_bp
    from app.fares.routes import fares_bp
    from app.tourism.routes import tourism_bp
    from app.establishments.routes import establishments_bp
    from app.emergency.routes import emergency_bp
    from app.favorites.routes import favorites_bp
    from app.history.routes import history_bp
    from app.ai.history_routes import ai_history_bp
    from app.ai.routes import ai_bp
    from app.ai.chat_service import ChatService
    from app.ai.knowledge_sync import seed_knowledge_documents
    from app.admin.routes import admin_bp
    from app.notifications.routes import notifications_bp
    from app.analytics.routes import analytics_bp
    from app.reports.routes import reports_bp
    from app.sync.routes import sync_bp
    from app.pdf.routes import pdf_bp
    from app.utilities.seed_data import (
      seed_admin_user,
      seed_places_data,
      seed_system_data,
      seed_transport_data,
    )

    api_prefix = app.config["API_PREFIX"]
    app.register_blueprint(auth_bp, url_prefix=f"{api_prefix}/auth")
    app.register_blueprint(users_bp, url_prefix=f"{api_prefix}/users")
    app.register_blueprint(routes_bp, url_prefix=f"{api_prefix}/routes")
    app.register_blueprint(maps_bp, url_prefix=f"{api_prefix}/maps")
    app.register_blueprint(fares_bp, url_prefix=f"{api_prefix}/fares")
    app.register_blueprint(tourism_bp, url_prefix=f"{api_prefix}/tourism")
    app.register_blueprint(establishments_bp, url_prefix=f"{api_prefix}/establishments")
    app.register_blueprint(emergency_bp, url_prefix=f"{api_prefix}/emergency")
    app.register_blueprint(favorites_bp, url_prefix=f"{api_prefix}/favorites")
    app.register_blueprint(history_bp, url_prefix=f"{api_prefix}/history")
    app.register_blueprint(ai_bp, url_prefix=f"{api_prefix}/ai")
    app.register_blueprint(ai_history_bp, url_prefix=f"{api_prefix}/ai/history")
    app.register_blueprint(admin_bp, url_prefix=f"{api_prefix}/admin")
    app.register_blueprint(notifications_bp, url_prefix=f"{api_prefix}/notifications")
    app.register_blueprint(analytics_bp, url_prefix=f"{api_prefix}/analytics")
    app.register_blueprint(reports_bp, url_prefix=f"{api_prefix}/reports")
    app.register_blueprint(sync_bp, url_prefix=f"{api_prefix}/sync")
    app.register_blueprint(pdf_bp, url_prefix=f"{api_prefix}/pdf")

    from app.models.password_reset import PasswordResetToken  # noqa: F401

    if app.config.get("AUTO_SEED", True):
        with app.app_context():
            db.create_all()
            seed_transport_data()
            seed_places_data()
            seed_knowledge_documents()
            seed_admin_user()
            seed_system_data()
            try:
                ChatService().ensure_index()
            except Exception:
                pass
    else:
        with app.app_context():
            db.create_all()

    @app.get("/health")
    def health_check():
        db_status = "ok"
        try:
            db.session.execute(text("SELECT 1"))
        except Exception:
            db_status = "error"
        status = "healthy" if db_status == "ok" else "degraded"
        code = 200 if db_status == "ok" else 503
        return jsonify(
            {
                "status": status,
                "service": "pinpoint-api",
                "version": app.config.get("APP_VERSION", "1.0.0"),
                "database": db_status,
            }
        ), code

    return app
