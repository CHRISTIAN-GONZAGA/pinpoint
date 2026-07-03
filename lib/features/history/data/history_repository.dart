import 'package:pinpoint/features/explore/data/places_remote_datasource.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';
import 'package:pinpoint/features/history/data/history_local_datasource.dart';

/// Search history with local storage and optional API sync.
class HistoryRepository {
  HistoryRepository({
    required PlacesRemoteDataSource remote,
    required HistoryLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final PlacesRemoteDataSource _remote;
  final HistoryLocalDataSource _local;

  Future<List<HistoryItem>> getHistory({bool isAuthenticated = false}) async {
    if (isAuthenticated) {
      try {
        return await _remote.fetchHistory();
      } catch (_) {}
    }
    final local = await _local.getAll();
    return local.map(HistoryItem.fromJson).toList().reversed.toList();
  }

  Future<HistoryItem> addEntry({
    required String query,
    required String searchType,
    double? latitude,
    double? longitude,
    required bool isAuthenticated,
  }) async {
    final payload = {
      'query': query,
      'search_type': searchType,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (isAuthenticated) {
      try {
        return await _remote.addHistory(payload);
      } catch (_) {}
    }
    final item = HistoryItem(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      query: query,
      searchType: searchType,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      isLocal: true,
    );
    await _local.add(item.toJson());
    return item;
  }

  Future<void> removeEntry({
    required HistoryItem item,
    required bool isAuthenticated,
  }) async {
    if (isAuthenticated && !item.isLocal) {
      final id = int.tryParse(item.id);
      if (id != null) {
        try {
          await _remote.deleteHistory(id);
        } catch (_) {}
      }
    }
    await _local.remove(item.id);
  }

  Future<void> clear({required bool isAuthenticated}) async {
    if (isAuthenticated) {
      try {
        await _remote.clearHistory();
      } catch (_) {}
    }
    await _local.clear();
  }
}
