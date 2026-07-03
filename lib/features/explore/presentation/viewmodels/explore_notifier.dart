import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/explore/presentation/viewmodels/explore_state.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Manages explore, search, and nearby places state.
class ExploreNotifier extends Notifier<ExploreState> {
  @override
  ExploreState build() => const ExploreState();

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final attractions = await ref.read(placesRepositoryProvider).getAttractions();
      state = state.copyWith(isLoading: false, attractions: attractions);
      await loadNearby();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _message(e));
    }
  }

  Future<void> loadNearby() async {
    final location = ref.read(mapNotifierProvider).currentLocation;
    if (location == null) return;
    try {
      final nearby = await ref.read(placesRepositoryProvider).getNearby(
            lat: location.latitude,
            lng: location.longitude,
          );
      state = state.copyWith(nearbyPlaces: nearby);
    } catch (_) {}
  }

  Future<void> search(String query) async {
    if (query.trim().length < 2) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }
    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final results = await ref.read(placesRepositoryProvider).search(query);
      state = state.copyWith(searchResults: results, isSearching: false);
      await ref.read(historyRepositoryProvider).addEntry(
            query: query,
            searchType: 'place',
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
    } catch (e) {
      state = state.copyWith(isSearching: false, errorMessage: _message(e));
    }
  }

  Future<List<Place>> loadCategory(String category) async {
    return ref.read(placesRepositoryProvider).getByCategory(category);
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.contains('AppException:')) {
      return text.replaceFirst('AppException: ', '');
    }
    return 'Unable to load places. Please try again.';
  }
}

final exploreNotifierProvider =
    NotifierProvider<ExploreNotifier, ExploreState>(ExploreNotifier.new);

final nearbyPlacesProvider = Provider((ref) {
  return ref.watch(exploreNotifierProvider).nearbyPlaces;
});
