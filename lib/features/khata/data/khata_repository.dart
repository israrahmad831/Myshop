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
import '../domain/khata_transaction.dart';

class KhataRepository with OfflineRepository {
  KhataRepository({
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

  static const _table = AppConstants.tblKhata;

  /// All transactions for the shop (cached). Balances are computed client-side
  /// so the ledger works offline and stays consistent with pending edits.
  Future<List<KhataTransaction>> listForShop(String shopId) async {
    final rows = await readShopRows(_table, shopId, orderBy: 'date');
    return rows.map(KhataTransaction.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<KhataTransaction> create(KhataTransaction t) async {
    final id = t.id.isNotEmpty ? t.id : newId();
    final saved = await insertRow(_table, {...t.toWrite(), 'id': id});
    return KhataTransaction.fromJson(saved);
  }

  Future<KhataTransaction> update(KhataTransaction t) async {
    final saved = await updateRow(_table, t.id, t.toWrite());
    return KhataTransaction.fromJson(saved);
  }

  Future<void> delete(String id) => deleteRow(_table, id);
}

final khataRepositoryProvider = Provider<KhataRepository>((ref) {
  return KhataRepository(
    client: ref.watch(supabaseProvider),
    cache: LocalCache(Hive.box<Map>(AppConstants.boxKhata)),
    outbox: ref.watch(outboxProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
});
