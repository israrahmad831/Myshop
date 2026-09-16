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
import '../domain/expense.dart';

class ExpensesRepository with OfflineRepository {
  ExpensesRepository({
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

  static const _table = AppConstants.tblExpenses;

  Future<List<Expense>> list(String shopId) async {
    final rows = await readShopRows(_table, shopId, orderBy: 'date');
    return rows.map(Expense.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<Expense> create(Expense expense) async {
    final id = expense.id.isNotEmpty ? expense.id : newId();
    final saved = await insertRow(_table, {...expense.toWrite(), 'id': id});
    return Expense.fromJson(saved);
  }

  Future<void> delete(String id) => deleteRow(_table, id);
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(
    client: ref.watch(supabaseProvider),
    cache: LocalCache(Hive.box<Map>(AppConstants.boxExpenses)),
    outbox: ref.watch(outboxProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
});
