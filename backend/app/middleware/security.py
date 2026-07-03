"""HTTP security headers middleware."""


def register_security_headers(app) -> None:
  """Attach baseline security headers to every response."""

  @app.after_request
  def add_security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    if not app.config.get("DEBUG", False):
      response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response
