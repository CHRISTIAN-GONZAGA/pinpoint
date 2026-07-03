"""Places and tourism data access."""

import math

from app.extensions import db
from app.models.places import (
  EmergencyContact,
  Establishment,
  Favorite,
  SearchHistory,
  TouristAttraction,
)


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
  r = 6371.0
  d_lat = math.radians(lat2 - lat1)
  d_lng = math.radians(lng2 - lng1)
  a = (
    math.sin(d_lat / 2) ** 2
    + math.cos(math.radians(lat1))
    * math.cos(math.radians(lat2))
    * math.sin(d_lng / 2) ** 2
  )
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class PlacesRepository:
  """Repository for tourism, establishments, and emergency data."""

  def get_attractions(self, category: str | None = None) -> list[TouristAttraction]:
    query = TouristAttraction.query.filter_by(active_status=True)
    if category:
      query = query.filter(TouristAttraction.category.ilike(category))
    return query.order_by(TouristAttraction.name).all()

  def get_attraction(self, attraction_id: int) -> TouristAttraction | None:
    return TouristAttraction.query.filter_by(
      attraction_id=attraction_id, active_status=True
    ).first()

  def search_attractions(self, query_text: str) -> list[TouristAttraction]:
    pattern = f"%{query_text}%"
    return (
      TouristAttraction.query.filter(
        TouristAttraction.active_status.is_(True),
        db.or_(
          TouristAttraction.name.ilike(pattern),
          TouristAttraction.description.ilike(pattern),
        ),
      )
      .order_by(TouristAttraction.name)
      .all()
    )

  def get_establishments(self, category: str | None = None) -> list[Establishment]:
    query = Establishment.query.filter_by(active_status=True)
    if category:
      query = query.filter(Establishment.category.ilike(category))
    return query.order_by(Establishment.name).all()

  def get_establishment(self, establishment_id: int) -> Establishment | None:
    return Establishment.query.filter_by(
      establishment_id=establishment_id, active_status=True
    ).first()

  def get_emergency_contacts(self) -> list[EmergencyContact]:
    return (
      EmergencyContact.query.filter_by(active_status=True)
      .order_by(EmergencyContact.category, EmergencyContact.agency)
      .all()
    )

  def nearby_places(
    self, lat: float, lng: float, radius_km: float = 5.0
  ) -> list[dict]:
    results: list[dict] = []
    for attraction in self.get_attractions():
      dist = _haversine_km(lat, lng, attraction.latitude, attraction.longitude)
      if dist <= radius_km:
        item = attraction.to_dict()
        item["distance_km"] = round(dist, 2)
        results.append(item)
    for est in self.get_establishments():
      dist = _haversine_km(lat, lng, est.latitude, est.longitude)
      if dist <= radius_km:
        item = est.to_dict()
        item["distance_km"] = round(dist, 2)
        results.append(item)
    results.sort(key=lambda x: x["distance_km"])
    return results


class FavoritesRepository:
  """User favorites persistence."""

  def list_for_user(self, user_id: int) -> list[Favorite]:
    return (
      Favorite.query.filter_by(user_id=user_id)
      .order_by(Favorite.created_at.desc())
      .all()
    )

  def add(self, **kwargs) -> Favorite:
    favorite = Favorite(**kwargs)
    db.session.add(favorite)
    db.session.commit()
    return favorite

  def delete(self, user_id: int, favorite_id: int) -> bool:
    favorite = Favorite.query.filter_by(
      user_id=user_id, favorite_id=favorite_id
    ).first()
    if not favorite:
      return False
    db.session.delete(favorite)
    db.session.commit()
    return True


class HistoryRepository:
  """User search history persistence."""

  def list_for_user(self, user_id: int, limit: int = 50) -> list[SearchHistory]:
    return (
      SearchHistory.query.filter_by(user_id=user_id)
      .order_by(SearchHistory.created_at.desc())
      .limit(limit)
      .all()
    )

  def add(self, **kwargs) -> SearchHistory:
    entry = SearchHistory(**kwargs)
    db.session.add(entry)
    db.session.commit()
    return entry

  def delete(self, user_id: int, history_id: int) -> bool:
    entry = SearchHistory.query.filter_by(
      user_id=user_id, history_id=history_id
    ).first()
    if not entry:
      return False
    db.session.delete(entry)
    db.session.commit()
    return True

  def clear(self, user_id: int) -> None:
    SearchHistory.query.filter_by(user_id=user_id).delete()
    db.session.commit()
