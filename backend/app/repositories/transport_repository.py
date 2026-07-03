"""Transportation data repositories."""

from app.extensions import db
from app.models.transport import FareMatrix, JeepneyRoute, TricycleZone


class TransportRepository:
  """Data access for jeepney routes, tricycle zones, and fares."""

  def get_active_routes(self) -> list[JeepneyRoute]:
    return (
      JeepneyRoute.query.filter_by(active_status=True)
      .order_by(JeepneyRoute.route_code)
      .all()
    )

  def get_route_by_id(self, route_id: int) -> JeepneyRoute | None:
    return JeepneyRoute.query.filter_by(
      route_id=route_id, active_status=True
    ).first()

  def get_route_by_code(self, route_code: str) -> JeepneyRoute | None:
    return JeepneyRoute.query.filter_by(
      route_code=route_code.upper(), active_status=True
    ).first()

  def search_routes(self, query: str) -> list[JeepneyRoute]:
    pattern = f"%{query}%"
    return (
      JeepneyRoute.query.filter(
        JeepneyRoute.active_status.is_(True),
        db.or_(
          JeepneyRoute.route_code.ilike(pattern),
          JeepneyRoute.route_name.ilike(pattern),
        ),
      )
      .order_by(JeepneyRoute.route_code)
      .all()
    )

  def get_active_tricycle_zones(self) -> list[TricycleZone]:
    return (
      TricycleZone.query.filter_by(active_status=True)
      .order_by(TricycleZone.zone_name)
      .all()
    )

  def get_fare_matrix(self) -> list[FareMatrix]:
    return FareMatrix.query.order_by(FareMatrix.transport_type).all()
