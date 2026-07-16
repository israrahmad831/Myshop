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
import '../domain/customer.dart';

class CustomersRepository with OfflineRepository {
  CustomersRepository({
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

  static const _table = AppConstants.tblCustomers;

  Future<List<Customer>> list(String shopId) async {
    final rows = await readShopRows(_table, shopId);
    return rows.map(Customer.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Customer? getCached(String id) {
    final m = cache.get(id);
    return m == null ? null : Customer.fromJson(m);
  }

  Future<Customer> create(Customer c) async {
    final id = c.id.isNotEmpty ? c.id : newId();
    final saved = await insertRow(_table, {...c.toWrite(), 'id': id});
    return Customer.fromJson(saved);
  }

  Future<Customer> update(Customer c) async {
    final saved = await updateRow(_table, c.id, c.toWrite());
    return Customer.fromJson(saved);
  }

  Future<void> delete(String id) => deleteRow(_table, id);
}

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(
    client: ref.watch(supabaseProvider),
    cache: LocalCache(Hive.box<Map>(AppConstants.boxCustomers)),
    outbox: ref.watch(outboxProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
});
