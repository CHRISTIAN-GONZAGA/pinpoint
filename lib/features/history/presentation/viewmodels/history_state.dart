import 'package:equatable/equatable.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

class HistoryState extends Equatable {
  const HistoryState({
    this.isLoading = false,
    this.items = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<HistoryItem> items;
  final String? errorMessage;

  HistoryState copyWith({
    bool? isLoading,
    List<HistoryItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, items];
}
