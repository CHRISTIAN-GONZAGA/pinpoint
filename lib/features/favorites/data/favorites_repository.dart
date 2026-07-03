import 'package:pinpoint/features/explore/data/places_remote_datasource.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/favorites/data/favorites_local_datasource.dart';

/// Favorites with local storage and optional API sync for registered users.
class FavoritesRepository {
  FavoritesRepository({
    required PlacesRemoteDataSource remote,
    required FavoritesLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final PlacesRemoteDataSource _remote;
  final FavoritesLocalDataSource _local;

  Future<List<FavoriteItem>> getFavorites({bool isAuthenticated = false}) async {
    if (isAuthenticated) {
      try {
        final remote = await _remote.fetchFavorites();
        await _local.saveAll(remote.map((f) => f.toJson()).toList());
        return remote;
      } catch (_) {
        // Fall back to local cache when offline.
      }
    }
    final local = await _local.getAll();
    return local.map(FavoriteItem.fromJson).toList();
  }

  Future<FavoriteItem> addFavorite({
    required FavoriteItem item,
    required bool isAuthenticated,
  }) async {
    if (isAuthenticated) {
      try {
        final saved = await _remote.addFavorite({
          'place_type': item.placeType,
          'place_id': item.placeId,
          'label': item.label,
          'latitude': item.latitude,
          'longitude': item.longitude,
          'category': item.category,
        });
        await _local.add(saved.toJson());
        return saved;
      } catch (_) {
        // Continue with local save if API fails.
      }
    }
    final localItem = item.copyWithLocal();
    await _local.add(localItem.toJson());
    return localItem;
  }

  Future<void> removeFavorite({
    required FavoriteItem item,
    required bool isAuthenticated,
  }) async {
    if (isAuthenticated && !item.isLocal) {
      final id = int.tryParse(item.id);
      if (id != null) {
        try {
          await _remote.deleteFavorite(id);
        } catch (_) {}
      }
    }
    await _local.remove(item.id);
  }

  Future<bool> isFavorite({
    required String placeType,
    required int placeId,
  }) async {
    final items = await _local.getAll();
    return items.any(
      (f) => f['place_type'] == placeType && f['place_id'] == placeId,
    );
  }
}

extension on FavoriteItem {
  FavoriteItem copyWithLocal() {
    return FavoriteItem(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      placeType: placeType,
      placeId: placeId,
      latitude: latitude,
      longitude: longitude,
      category: category,
      createdAt: DateTime.now(),
      isLocal: true,
    );
  }
}
