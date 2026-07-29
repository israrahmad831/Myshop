import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shops/presentation/shop_providers.dart';
import '../data/receipts_repository.dart';
import '../domain/receipt.dart';

final receiptsProvider = FutureProvider.autoDispose<List<Receipt>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(receiptsRepositoryProvider).list(shopId);
});

final receiptSearchProvider = StateProvider.autoDispose<String>((ref) => '');

/// Date-range filter for the receipts list.
enum ReceiptRange {
  all('All'),
  today('Today'),
  week('7 days'),
  month('This month');

  const ReceiptRange(this.label);
  final String label;

  bool matches(DateTime d) {
    final now = DateTime.now();
    switch (this) {
      case ReceiptRange.all:
        return true;
      case ReceiptRange.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case ReceiptRange.week:
        return d.isAfter(now.subtract(const Duration(days: 7)));
      case ReceiptRange.month:
        return d.year == now.year && d.month == now.month;
    }
  }
}

final receiptRangeProvider =
    StateProvider.autoDispose<ReceiptRange>((ref) => ReceiptRange.all);

final filteredReceiptsProvider =
    Provider.autoDispose<AsyncValue<List<Receipt>>>((ref) {
  final q = ref.watch(receiptSearchProvider).trim().toLowerCase();
  final range = ref.watch(receiptRangeProvider);
  return ref.watch(receiptsProvider).whenData((list) {
    return list.where((r) {
      final matchesRange = range.matches(r.date);
      final matchesQuery = q.isEmpty ||
          r.receiptNumber.toString().contains(q) ||
          (r.customerName?.toLowerCase().contains(q) ?? false) ||
          (r.customerPhone?.contains(q) ?? false);
      return matchesRange && matchesQuery;
    }).toList();
  });
});

final receiptByIdProvider =
    Provider.autoDispose.family<Receipt?, String>((ref, id) {
  final list = ref.watch(receiptsProvider).valueOrNull ?? const [];
  for (final r in list) {
    if (r.id == id) return r;
  }
  return ref.watch(receiptsRepositoryProvider).getCached(id);
});

/// Today's receipts (for the dashboard).
final todaysReceiptsProvider = Provider.autoDispose<List<Receipt>>((ref) {
  final list = ref.watch(receiptsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return list
      .where((r) =>
          r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day)
      .toList();
});
