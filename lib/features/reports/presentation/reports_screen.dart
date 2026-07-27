import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_providers.dart';
import '../../receipts/domain/receipt.dart';
import '../../receipts/presentation/receipt_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/reports_repository.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sales'),
              Tab(text: 'Khata'),
              Tab(text: 'Products'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_SalesReport(), _KhataReport(), _ProductsReport()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sales: today / this month + last 7 days breakdown.
// ---------------------------------------------------------------------------
class _SalesReport extends ConsumerWidget {
  const _SalesReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider).valueOrNull ?? const [];
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final now = DateTime.now();

    bool sameDay(DateTime d, DateTime o) =>
        d.year == o.year && d.month == o.month && d.day == o.day;

    final today = receipts.where((r) => sameDay(r.date, now)).toList();
    final thisMonth = receipts
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .toList();
    num sum(List<Receipt> rs) => rs.fold<num>(0, (s, r) => s + r.total);

    // Last 7 days grouped by day.
    final days = List.generate(7, (i) => now.subtract(Duration(days: i)));
    final dayFmt = DateFormat('EEE, dd MMM');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: _MetricCard(
              label: "Today's sales",
              value: Formatters.money(sum(today), currency),
              sub: '${today.length} receipts',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'This month',
              value: Formatters.money(sum(thisMonth), currency),
              sub: '${thisMonth.length} receipts',
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...days.map((d) {
          final dayReceipts =
              receipts.where((r) => sameDay(r.date, d)).toList();
          return Card(
            child: ListTile(
              title: Text(dayFmt.format(d)),
              subtitle: Text('${dayReceipts.length} receipts'),
              trailing: Text(
                Formatters.money(sum(dayReceipts), currency),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Khata: receivable/payable totals + per-customer balances.
// ---------------------------------------------------------------------------
class _KhataReport extends ConsumerWidget {
  const _KhataReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const [];
    final balances = ref.watch(khataBalancesProvider);
    final totals = ref.watch(khataTotalsProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';

    final withBalance = customers
        .where((c) => (balances[c.id] ?? 0) != 0)
        .toList()
      ..sort((a, b) =>
          balances[b.id]!.abs().compareTo(balances[a.id]!.abs()));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: _MetricCard(
              label: 'You will get',
              value: Formatters.money(totals.receivable, currency),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'You will give',
              value: Formatters.money(totals.payable, currency),
              color: Colors.red,
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Text('Customer balances',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (withBalance.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No outstanding balances.'),
          )
        else
          ...withBalance.map((Customer c) {
            final bal = balances[c.id] ?? 0;
            final owes = bal > 0;
            return Card(
              child: ListTile(
                onTap: () => context.push('/customers/${c.id}'),
                title: Text(c.name),
                subtitle: Text(owes ? 'Owes you' : 'You owe'),
                trailing: Text(
                  Formatters.money(bal.abs(), currency),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: owes ? Colors.green : Colors.red,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Products: low stock + top searched.
// ---------------------------------------------------------------------------
class _ProductsReport extends ConsumerWidget {
  const _ProductsReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final topSearched = ref.watch(topSearchedProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';

    final lowStock = products
        .where((p) => p.currentStock <= AppConstants.lowStockThreshold)
        .toList()
      ..sort((a, b) => a.currentStock.compareTo(b.currentStock));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Low stock (manual)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (lowStock.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No low-stock products.'),
          )
        else
          ...lowStock.map((Product p) => Card(
                child: ListTile(
                  onTap: () => context.push('/products/${p.id}'),
                  title: Text(p.name),
                  subtitle: Text(Formatters.money(p.sellingPrice, currency)),
                  trailing: Text(
                    '${Formatters.qty(p.currentStock)} ${p.unit}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 20),
        Text('Top searched products',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        topSearched.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No search data yet.'),
                )
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(list[i].name),
                          trailing: Text('${list[i].count}×'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.sub,
    this.color,
  });
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            if (sub != null)
              Text(sub!,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
