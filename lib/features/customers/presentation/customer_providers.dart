import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shops/presentation/shop_providers.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

final customersProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(customersRepositoryProvider).list(shopId);
});

final customerSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredCustomersProvider =
    Provider.autoDispose<AsyncValue<List<Customer>>>((ref) {
  final q = ref.watch(customerSearchProvider).trim().toLowerCase();
  return ref.watch(customersProvider).whenData((list) {
    if (q.isEmpty) return list;
    return list
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.phone?.contains(q) ?? false))
        .toList();
  });
});

/// A single customer by id from cache (used by detail/edit screens).
final customerByIdProvider =
    Provider.autoDispose.family<Customer?, String>((ref, id) {
  final list = ref.watch(customersProvider).valueOrNull ?? const [];
  for (final c in list) {
    if (c.id == id) return c;
  }
  return ref.watch(customersRepositoryProvider).getCached(id);
});
