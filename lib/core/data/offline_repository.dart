import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../error/error_mapper.dart';
import '../local/local_cache.dart';
import '../local/outbox.dart';

/// Shared read/write logic for shop-scoped, offline-capable repositories.
///
/// Reads: try the network, cache the snapshot, and transparently fall back to
/// the Hive cache when offline. Writes: when online they hit Supabase and
/// update the cache; when offline they update the cache optimistically and
/// queue the mutation in the [Outbox] for later replay.
mixin OfflineRepository {
  static const uuid = Uuid();

  SupabaseClient get client;
  LocalCache get cache;
  Outbox get outbox;
  bool get isOnline;

  /// Fetch a fresh shop snapshot from [table], cache it, and return the rows.
  /// Falls back to cache on any network error.
  Future<List<Map<String, dynamic>>> readShopRows(
    String table,
    String shopId, {
    String orderBy = 'updated_at',
    bool ascending = false,
  }) async {
    if (!isOnline) return cache.allForShop(shopId);
    try {
      final rows = await client
          .from(table)
          .select()
          .eq('shop_id', shopId)
          .order(orderBy, ascending: ascending);
      final list = (rows as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      await cache.replaceShop(shopId, list);
      return list;
    } catch (_) {
      return cache.allForShop(shopId);
    }
  }

  /// Insert [row] (must already contain a client-generated `id`).
  Future<Map<String, dynamic>> insertRow(
      String table, Map<String, dynamic> row) async {
    await cache.put(row);
    if (!isOnline) {
      await outbox.enqueue(OutboxEntry(
        id: row['id'] as String,
        table: table,
        op: OutboxOp.insert,
        payload: row,
        createdAt: DateTime.now(),
      ));
      return row;
    }
    try {
      final saved =
          await client.from(table).upsert(row).select().single();
      final map = saved.cast<String, dynamic>();
      await cache.put(map);
      return map;
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<Map<String, dynamic>> updateRow(
      String table, String id, Map<String, dynamic> row) async {
    await cache.put({...?cache.get(id), ...row, 'id': id});
    if (!isOnline) {
      await outbox.enqueue(OutboxEntry(
        id: id,
        table: table,
        op: OutboxOp.update,
        payload: row,
        createdAt: DateTime.now(),
      ));
      return cache.get(id)!;
    }
    try {
      final saved = await client
          .from(table)
          .update(row)
          .eq('id', id)
          .select()
          .single();
      final map = saved.cast<String, dynamic>();
      await cache.put(map);
      return map;
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> deleteRow(String table, String id) async {
    await cache.delete(id);
    if (!isOnline) {
      await outbox.enqueue(OutboxEntry(
        id: id,
        table: table,
        op: OutboxOp.delete,
        payload: const {},
        createdAt: DateTime.now(),
      ));
      return;
    }
    try {
      await client.from(table).delete().eq('id', id);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// A fresh client-side UUID for optimistic inserts.
  String newId() => uuid.v4();
}
