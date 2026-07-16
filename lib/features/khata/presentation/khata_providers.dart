import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shops/presentation/shop_providers.dart';
import '../data/khata_repository.dart';
import '../domain/khata_transaction.dart';

/// All khata transactions for the active shop.
final khataTransactionsProvider =
    FutureProvider.autoDispose<List<KhataTransaction>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(khataRepositoryProvider).listForShop(shopId);
});

/// Net balance per customer id (+ receivable / - payable), computed client-side.
final khataBalancesProvider =
    Provider.autoDispose<Map<String, num>>((ref) {
  final txns = ref.watch(khataTransactionsProvider).valueOrNull ?? const [];
  final map = <String, num>{};
  for (final t in txns) {
    map.update(t.customerId, (v) => v + t.signedAmount,
        ifAbsent: () => t.signedAmount);
  }
  return map;
});

/// Transactions for one customer, newest first (for their ledger).
final customerLedgerProvider = Provider.autoDispose
    .family<List<KhataTransaction>, String>((ref, customerId) {
  final txns = ref.watch(khataTransactionsProvider).valueOrNull ?? const [];
  return txns.where((t) => t.customerId == customerId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

/// A single customer's net balance.
final customerBalanceProvider =
    Provider.autoDispose.family<num, String>((ref, customerId) {
  return ref.watch(khataBalancesProvider)[customerId] ?? 0;
});

/// Shop-wide totals for the dashboard/reports.
final khataTotalsProvider = Provider.autoDispose<({num receivable, num payable})>(
    (ref) {
  final balances = ref.watch(khataBalancesProvider);
  num receivable = 0, payable = 0;
  for (final v in balances.values) {
    if (v > 0) {
      receivable += v;
    } else {
      payable += -v;
    }
  }
  return (receivable: receivable, payable: payable);
});
