import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../domain/receipt.dart';
import 'receipt_providers.dart';

class ReceiptsListScreen extends ConsumerWidget {
  const ReceiptsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredReceiptsProvider);
    final range = ref.watch(receiptRangeProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final canCreate =
        ref.watch(currentShopProvider)?.canCreateReceipts ?? false;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/receipts/new'),
              icon: const Icon(Icons.add),
              label: const Text('New receipt'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search by #, customer, phone…',
              leading: const Icon(Icons.search),
              onChanged: (v) =>
                  ref.read(receiptSearchProvider.notifier).state = v,
            ),
          ),
          // Date-range filter chips.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final r in ReceiptRange.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(r.label),
                      selected: range == r,
                      onSelected: (_) =>
                          ref.read(receiptRangeProvider.notifier).state = r,
                    ),
                  ),
              ],
            ),
          ),
          // Total for the current filter.
          filtered.maybeWhen(
            data: (receipts) => receipts.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${receipts.length} receipts',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outline)),
                        Text(
                          Formatters.money(
                              receipts.fold<num>(0, (s, r) => s + r.total),
                              currency),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: AsyncView<List<Receipt>>(
              value: filtered,
              onRetry: () => ref.invalidate(receiptsProvider),
              data: (receipts) {
                if (receipts.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts',
                    subtitle: canCreate
                        ? 'Create your first receipt.'
                        : 'No receipts have been created yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(receiptsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: receipts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = receipts[i];
                      return Card(
                        child: ListTile(
                          onTap: () => context.push('/receipts/${r.id}'),
                          leading: CircleAvatar(
                            child: Text('#${r.receiptNumber}',
                                style: const TextStyle(fontSize: 11)),
                          ),
                          title: Text(r.customerName ?? 'Walk-in customer'),
                          subtitle: Text(
                              '${Formatters.dateTime(r.date)} · ${r.items.length} items'),
                          trailing: Text(
                            Formatters.money(r.total, currency),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
