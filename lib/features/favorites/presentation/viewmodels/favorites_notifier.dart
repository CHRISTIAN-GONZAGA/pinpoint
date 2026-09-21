import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/favorites/presentation/viewmodels/favorites_state.dart';

/// Manages user favorites with optimistic local updates.
class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() => const FavoritesState();

  Future<void> load() async {
    final showSpinner = state.items.isEmpty;
    if (showSpinner) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final items = await ref.read(favoritesRepositoryProvider).getFavorites(
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  bool isFavoriteSync(Place place) {
    return state.items.any(
      (f) => f.placeType == place.placeType && f.placeId == place.id,
    );
  }

  Future<bool> toggleFavorite(Place place) async {
    final repo = ref.read(favoritesRepositoryProvider);
    final isAuth = ref.read(isAuthenticatedProvider);
    final existingIndex = state.items.indexWhere(
      (f) => f.placeType == place.placeType && f.placeId == place.id,
    );

    if (existingIndex >= 0) {
      final item = state.items[existingIndex];
      final next = [...state.items]..removeAt(existingIndex);
      state = state.copyWith(items: next);
      try {
        await repo.removeFavorite(item: item, isAuthenticated: isAuth);
      } catch (_) {
        await load();
      }
      return false;
    }

    final optimistic = FavoriteItem.fromPlace(place);
    state = state.copyWith(items: [optimistic, ...state.items]);
    try {
      final saved = await repo.addFavorite(item: optimistic, isAuthenticated: isAuth);
      final replaced = [
        for (final item in state.items)
          if (item.placeType == place.placeType && item.placeId == place.id) saved else item,
      ];
      state = state.copyWith(items: replaced);
    } catch (_) {
      await load();
    }
    return true;
  }

  Future<bool> isFavorite(Place place) async {
    if (state.items.isNotEmpty || !state.isLoading) {
      return isFavoriteSync(place);
    }
    return ref.read(favoritesRepositoryProvider).isFavorite(
          placeType: place.placeType,
          placeId: place.id,
        );
  }

  Future<void> remove(FavoriteItem item) async {
    final previous = state.items;
    state = state.copyWith(
      items: previous.where((f) => f.id != item.id).toList(),
    );
    try {
      await ref.read(favoritesRepositoryProvider).removeFavorite(
            item: item,
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }
}

final favoritesNotifierProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);
