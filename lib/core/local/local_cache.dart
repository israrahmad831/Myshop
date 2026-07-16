import 'package:hive/hive.dart';

/// Thin wrapper over a Hive `Box<Map>` that stores rows keyed by their `id`.
/// Each feature reads/writes plain JSON maps and (de)serialises its own model.
class LocalCache {
  LocalCache(this._box);
  final Box<Map> _box;

  /// All rows for a shop (rows are tagged with `shop_id`).
  List<Map<String, dynamic>> allForShop(String shopId) {
    return _box.values
        .cast<Map>()
        .where((m) => m['shop_id'] == shopId)
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  Map<String, dynamic>? get(String id) {
    final m = _box.get(id);
    return m?.cast<String, dynamic>();
  }

  Future<void> put(Map<String, dynamic> row) async {
    await _box.put(row['id'], row);
  }

  Future<void> putAll(List<Map<String, dynamic>> rows) async {
    await _box.putAll({for (final r in rows) r['id']: r});
  }

  /// Replaces the cached rows for a shop with a fresh server snapshot.
  Future<void> replaceShop(
      String shopId, List<Map<String, dynamic>> rows) async {
    final staleKeys = _box.keys.where((k) {
      final m = _box.get(k);
      return m != null && m['shop_id'] == shopId;
    }).toList();
    await _box.deleteAll(staleKeys);
    await putAll(rows);
  }

  Future<void> delete(String id) async => _box.delete(id);
}
