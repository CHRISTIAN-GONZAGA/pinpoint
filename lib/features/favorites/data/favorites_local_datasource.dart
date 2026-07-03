import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';

/// Local Hive storage for guest favorites.
class FavoritesLocalDataSource {
  Box<dynamic>? _box;

  Future<Box<dynamic>> get _favoritesBox async {
    return _box ??= await Hive.openBox(AppConstants.favoritesBoxName);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final box = await _favoritesBox;
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveAll(List<Map<String, dynamic>> items) async {
    final box = await _favoritesBox;
    await box.clear();
    for (var i = 0; i < items.length; i++) {
      await box.put(i, items[i]);
    }
  }

  Future<void> add(Map<String, dynamic> item) async {
    final box = await _favoritesBox;
    await box.add(item);
  }

  Future<void> remove(String id) async {
    final box = await _favoritesBox;
    final keysToRemove = <dynamic>[];
    for (final key in box.keys) {
      final value = Map<String, dynamic>.from(box.get(key) as Map);
      if (value['id'] == id) keysToRemove.add(key);
    }
    for (final key in keysToRemove) {
      await box.delete(key);
    }
  }

  Future<void> clear() async {
    final box = await _favoritesBox;
    await box.clear();
  }
}
