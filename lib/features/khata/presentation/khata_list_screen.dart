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
/// running balance. Tapping a customer opens their dedicated khata ledger page.
class KhataListScreen extends ConsumerWidget {
  const KhataListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final balances = ref.watch(khataBalancesProvider);
    final totals = ref.watch(khataTotalsProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final canCreate =
        ref.watch(currentShopProvider)?.canCreateReceipts ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Khata')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openCustomerPicker(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Open khata'),
            )
          : null,
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
                        onTap: () =>
                            context.push('/khata/customer/${c.id}'),
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

  /// Bottom sheet to pick any customer and open their khata page — so you can
  /// start/manage a khata even for customers with no balance yet.
  void _openCustomerPicker(BuildContext context, WidgetRef ref) {
    final all = ref.read(customersProvider).valueOrNull ?? const [];
    final query = ValueNotifier<String>('');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (ctx, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  hintText: 'Search customer…',
                  leading: const Icon(Icons.search),
                  onChanged: (v) => query.value = v,
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Add new customer'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/customers/new');
                },
              ),
              const Divider(height: 1),
              const SizedBox(height: 4),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: query,
                  builder: (ctx, q, _) {
                    final filtered = q.trim().isEmpty
                        ? all
                        : all
                            .where((c) => c.name
                                .toLowerCase()
                                .contains(q.trim().toLowerCase()))
                            .toList();
                    if (all.isEmpty) {
                      return const EmptyState(
                        icon: Icons.people_outline,
                        title: 'No customers yet',
                        subtitle: 'Add a customer first from the Customers tab.',
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                              child: Text(
                                  c.name.characters.first.toUpperCase())),
                          title: Text(c.name),
                          subtitle: c.phone != null ? Text(c.phone!) : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/khata/customer/${c.id}');
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
