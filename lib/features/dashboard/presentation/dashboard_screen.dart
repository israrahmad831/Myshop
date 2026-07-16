import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../products/presentation/product_providers.dart';
import '../../receipts/presentation/receipt_providers.dart';
import '../../shops/presentation/shop_providers.dart';

/// Home dashboard: key counters + recent activity. All figures come from the
/// same cached providers used elsewhere, so it works offline too.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentShopProvider);
    final currency = shop?.currency ?? 'PKR';
    final todays = ref.watch(todaysReceiptsProvider);
    final customers = ref.watch(customersProvider).valueOrNull ?? const [];
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final khata = ref.watch(khataTotalsProvider);
    final recentReceipts =
        (ref.watch(receiptsProvider).valueOrNull ?? const []).take(5).toList();
    final todaysSales =
        todays.fold<num>(0, (s, r) => s + r.total);

    return Scaffold(
      appBar: AppBar(
        title: Text(shop?.name ?? 'Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: 'Reports',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            tooltip: 'Switch shop',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () async {
              await ref.read(currentShopIdProvider.notifier).select(null);
              if (context.mounted) context.go('/shops');
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(receiptsProvider);
          ref.invalidate(customersProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(khataTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  icon: Icons.receipt_long,
                  label: "Today's receipts",
                  value: '${todays.length}',
                  sub: Formatters.money(todaysSales, currency),
                  color: Colors.blue,
                ),
                _StatCard(
                  icon: Icons.people,
                  label: 'Customers',
                  value: '${customers.length}',
                  color: Colors.teal,
                ),
                _StatCard(
                  icon: Icons.inventory_2,
                  label: 'Products',
                  value: '${products.length}',
                  color: Colors.orange,
                ),
                _StatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'You will get',
                  value: Formatters.money(khata.receivable, currency),
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.red.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.north_east, color: Colors.red),
                title: const Text('You will give (payable)'),
                trailing: Text(
                  Formatters.money(khata.payable, currency),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Recent receipts',
              onSeeAll: () => context.go('/home?tab=2'),
            ),
            if (recentReceipts.isEmpty)
              const _EmptyLine('No receipts yet')
            else
              ...recentReceipts.map((r) => Card(
                    child: ListTile(
                      onTap: () => context.push('/receipts/${r.id}'),
                      leading: CircleAvatar(
                          child: Text('#${r.receiptNumber}',
                              style: const TextStyle(fontSize: 11))),
                      title: Text(r.customerName ?? 'Walk-in customer'),
                      subtitle: Text(Formatters.dateTime(r.date)),
                      trailing:
                          Text(Formatters.money(r.total, currency)),
                    ),
                  )),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Recent customers',
              onSeeAll: () => context.go('/home?tab=3'),
            ),
            if (customers.isEmpty)
              const _EmptyLine('No customers yet')
            else
              ...customers.take(5).map((c) => Card(
                    child: ListTile(
                      onTap: () => context.push('/customers/${c.id}'),
                      leading: CircleAvatar(
                          child:
                              Text(c.name.characters.first.toUpperCase())),
                      title: Text(c.name),
                      subtitle: c.phone != null ? Text(c.phone!) : null,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
            if (sub != null)
              Text(sub!, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}
