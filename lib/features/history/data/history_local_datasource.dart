import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';

/// Local Hive storage for search history.
class HistoryLocalDataSource {
  Box<dynamic>? _box;

  Future<Box<dynamic>> get _historyBox async {
    return _box ??= await Hive.openBox(AppConstants.historyBoxName);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final box = await _historyBox;
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> add(Map<String, dynamic> item) async {
    final box = await _historyBox;
    await box.add(item);
  }

  Future<void> remove(String id) async {
    final box = await _historyBox;
    for (final key in box.keys) {
      final value = Map<String, dynamic>.from(box.get(key) as Map);
      if (value['id'] == id) {
        await box.delete(key);
        return;
      }
    }
  }

  Future<void> clear() async {
    final box = await _historyBox;
    await box.clear();
  }
}
