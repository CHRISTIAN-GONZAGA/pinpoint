import 'package:equatable/equatable.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

class FavoritesState extends Equatable {
  const FavoritesState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<FavoriteItem> items;
  final String? errorMessage;

  FavoritesState copyWith({
    bool? isLoading,
    List<FavoriteItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FavoritesState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, items];
}
