import 'package:equatable/equatable.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Explore screen state.
class ExploreState extends Equatable {
  const ExploreState({
    this.isLoading = false,
    this.isSearching = false,
    this.errorMessage,
    this.attractions = const [],
    this.searchResults = const [],
    this.nearbyPlaces = const [],
    this.selectedCategory,
  });

  final bool isLoading;
  final bool isSearching;
  final String? errorMessage;
  final List<Place> attractions;
  final List<Place> searchResults;
  final List<Place> nearbyPlaces;
  final String? selectedCategory;

  ExploreState copyWith({
    bool? isLoading,
    bool? isSearching,
    String? errorMessage,
    List<Place>? attractions,
    List<Place>? searchResults,
    List<Place>? nearbyPlaces,
    String? selectedCategory,
    bool clearError = false,
  }) {
    return ExploreState(
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      attractions: attractions ?? this.attractions,
      searchResults: searchResults ?? this.searchResults,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  @override
  List<Object?> get props => [isLoading, attractions.length, searchResults, nearbyPlaces];
}
