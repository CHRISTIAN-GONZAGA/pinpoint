import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/favorites/presentation/viewmodels/favorites_state.dart';

/// Manages user favorites.
class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() => const FavoritesState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(favoritesRepositoryProvider).getFavorites(
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> toggleFavorite(Place place) async {
    final repo = ref.read(favoritesRepositoryProvider);
    final isAuth = ref.read(isAuthenticatedProvider);
    final exists = await repo.isFavorite(placeType: place.placeType, placeId: place.id);
    if (exists) {
      final item = state.items.firstWhere(
        (f) => f.placeType == place.placeType && f.placeId == place.id,
        orElse: () => FavoriteItem.fromPlace(place),
      );
      await repo.removeFavorite(item: item, isAuthenticated: isAuth);
    } else {
      await repo.addFavorite(item: FavoriteItem.fromPlace(place), isAuthenticated: isAuth);
    }
    await load();
    return !exists;
  }

  Future<bool> isFavorite(Place place) {
    return ref.read(favoritesRepositoryProvider).isFavorite(
          placeType: place.placeType,
          placeId: place.id,
        );
  }

  Future<void> remove(FavoriteItem item) async {
    await ref.read(favoritesRepositoryProvider).removeFavorite(
          item: item,
          isAuthenticated: ref.read(isAuthenticatedProvider),
        );
    await load();
  }
}

final favoritesNotifierProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);
