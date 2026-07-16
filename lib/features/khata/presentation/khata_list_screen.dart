import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import 'khata_providers.dart';

/// Khata overview: total receivable/payable + a list of customers with a
/// running balance. Tapping a customer opens their ledger (customer detail).
class KhataListScreen extends ConsumerWidget {
  const KhataListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final balances = ref.watch(khataBalancesProvider);
    final totals = ref.watch(khataTotalsProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';

    return Scaffold(
      appBar: AppBar(title: const Text('Khata')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'You will get',
                    amount: Formatters.money(totals.receivable, currency),
                    color: Colors.green,
                    icon: Icons.south_west,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'You will give',
                    amount: Formatters.money(totals.payable, currency),
                    color: Colors.red,
                    icon: Icons.north_east,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Customer>>(
              value: customersAsync,
              onRetry: () => ref.invalidate(customersProvider),
              data: (customers) {
                final withBalance = customers
                    .where((c) => (balances[c.id] ?? 0) != 0)
                    .toList()
                  ..sort((a, b) => (balances[b.id]!.abs())
                      .compareTo(balances[a.id]!.abs()));
                if (withBalance.isEmpty) {
                  return const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No khata yet',
                    subtitle:
                        'Open a customer and add a udhaar or payment entry.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: withBalance.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = withBalance[i];
                    final bal = balances[c.id] ?? 0;
                    final owes = bal > 0;
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/customers/${c.id}'),
                        leading: CircleAvatar(
                          child: Text(c.name.characters.first.toUpperCase()),
                        ),
                        title: Text(c.name),
                        subtitle:
                            Text(owes ? 'Owes you' : 'You owe'),
                        trailing: Text(
                          Formatters.money(bal.abs(), currency),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: owes ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12)),
            const SizedBox(height: 2),
            Text(amount,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          ],
        ),
      ),
    );
  }
}
