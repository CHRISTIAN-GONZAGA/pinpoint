import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/history/presentation/viewmodels/history_state.dart';

/// Manages search and navigation history with optimistic updates.
class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  Future<void> load() async {
    final showSpinner = state.items.isEmpty;
    if (showSpinner) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final items = await ref.read(historyRepositoryProvider).getHistory(
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addEntry({
    required String query,
    required String searchType,
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Dedupe consecutive identical queries.
    if (state.items.isNotEmpty &&
        state.items.first.query.toLowerCase() == trimmed.toLowerCase()) {
      return;
    }

    try {
      final saved = await ref.read(historyRepositoryProvider).addEntry(
            query: trimmed,
            searchType: searchType,
            latitude: latitude,
            longitude: longitude,
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
      state = state.copyWith(items: [saved, ...state.items]);
    } catch (_) {}
  }

  Future<void> remove(HistoryItem item) async {
    final previous = state.items;
    state = state.copyWith(
      items: previous.where((h) => h.id != item.id).toList(),
    );
    try {
      await ref.read(historyRepositoryProvider).removeEntry(
            item: item,
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  Future<void> clearAll() async {
    final previous = state.items;
    state = state.copyWith(items: const []);
    try {
      await ref.read(historyRepositoryProvider).clear(
            isAuthenticated: ref.read(isAuthenticatedProvider),
          );
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }
}

final historyNotifierProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);
