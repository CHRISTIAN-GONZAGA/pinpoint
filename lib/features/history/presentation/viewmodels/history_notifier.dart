import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/history/presentation/viewmodels/history_state.dart';

/// Manages search and navigation history.
class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(historyRepositoryProvider).getHistory(
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> remove(HistoryItem item) async {
    await ref.read(historyRepositoryProvider).removeEntry(
          item: item,
          isAuthenticated: ref.read(isAuthenticatedProvider),
        );
    await load();
  }

  Future<void> clearAll() async {
    await ref.read(historyRepositoryProvider).clear(
          isAuthenticated: ref.read(isAuthenticatedProvider),
        );
    await load();
  }
}

final historyNotifierProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);
