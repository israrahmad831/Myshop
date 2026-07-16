import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/offline_repository.dart';
import '../../../core/local/local_cache.dart';
import '../../../core/local/outbox.dart';
import '../../../core/local/sync_engine.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/product.dart';

class ProductsRepository with OfflineRepository {
  ProductsRepository({
    required this.client,
    required this.cache,
    required this.outbox,
    required this.isOnline,
  });

  @override
  final SupabaseClient client;
  @override
  final LocalCache cache;
  @override
  final Outbox outbox;
  @override
  final bool isOnline;

  static const _table = AppConstants.tblProducts;

  Future<List<Product>> list(String shopId) async {
    final rows = await readShopRows(_table, shopId);
    return rows.map(Product.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Instant type-ahead suggestions for receipts (prefix + contains match).
  /// Uses the cached list so it's fast and works offline.
  List<Product> suggest(String shopId, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final all = cache.allForShop(shopId).map(Product.fromJson);
    final matches = all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.brand?.toLowerCase().contains(q) ?? false))
        .toList();
    // Prefix matches first, then the rest, capped for the dropdown.
    matches.sort((a, b) {
      final ap = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bp = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      return ap != bp ? ap - bp : a.name.compareTo(b.name);
    });
    return matches.take(8).toList();
  }

  Product? getCached(String id) {
    final m = cache.get(id);
    return m == null ? null : Product.fromJson(m);
  }

  Future<Product> create(Product p) async {
    // Respect a caller-supplied id (e.g. one already used for the image path);
    // otherwise generate a fresh client-side UUID.
    final id = p.id.isNotEmpty ? p.id : newId();
    final row = {...p.toWrite(), 'id': id};
    final saved = await insertRow(_table, row);
    return Product.fromJson(saved);
  }

  Future<Product> update(Product p) async {
    final saved = await updateRow(_table, p.id, p.toWrite());
    return Product.fromJson(saved);
  }

  Future<void> delete(String id) => deleteRow(_table, id);

  /// Fire-and-forget analytics for the "top searched products" report.
  /// Online only; failures are ignored so search stays fast.
  Future<void> recordSearch(String shopId, String productId, String term) async {
    if (!isOnline) return;
    try {
      await client.rpc(AppConstants.rpcRecordSearch, params: {
        'p_shop': shopId,
        'p_product': productId,
        'p_term': term,
      });
    } catch (_) {}
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(
    client: ref.watch(supabaseProvider),
    cache: LocalCache(Hive.box<Map>(AppConstants.boxProducts)),
    outbox: ref.watch(outboxProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
});
