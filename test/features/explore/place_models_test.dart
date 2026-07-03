import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

void main() {
  test('Place parses attraction json', () {
    final place = Place.fromJson({
      'attraction_id': 1,
      'name': 'Balangay Shrine Museum',
      'place_type': 'attraction',
      'latitude': 8.9385,
      'longitude': 125.5455,
      'category': 'museum',
    });
    expect(place.id, 1);
    expect(place.placeType, 'attraction');
  });

  test('FavoriteItem fromPlace creates local favorite', () {
    final place = Place.fromJson({
      'establishment_id': 2,
      'name': 'SM City',
      'latitude': 8.93,
      'longitude': 125.55,
      'category': 'shopping_center',
    });
    final fav = FavoriteItem.fromPlace(place);
    expect(fav.label, 'SM City');
    expect(fav.isLocal, isTrue);
  });
}
