import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import 'khata_providers.dart';

/// Khata overview: net position + a searchable list of customers with a
/// running balance. Tapping a customer opens their dedicated khata ledger.
class KhataListScreen extends ConsumerStatefulWidget {
  const KhataListScreen({super.key});

  @override
  ConsumerState<KhataListScreen> createState() => _KhataListScreenState();
}

class _KhataListScreenState extends ConsumerState<KhataListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final balances = ref.watch(khataBalancesProvider);
    final totals = ref.watch(khataTotalsProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final canCreate =
        ref.watch(currentShopProvider)?.canCreateReceipts ?? false;
    final q = _query.trim().toLowerCase();

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openCustomerPicker(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Open khata'),
            )
          : null,
      body: Column(
        children: [
          _SummaryHeader(
            receivable: totals.receivable,
            payable: totals.payable,
            currency: currency,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: 'Search customer…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: AsyncView<List<Customer>>(
              value: customersAsync,
              onRetry: () => ref.invalidate(customersProvider),
              data: (customers) {
                final withBalance = customers
                    .where((c) => (balances[c.id] ?? 0) != 0)
                    .where((c) =>
                        q.isEmpty ||
                        c.name.toLowerCase().contains(q) ||
                        (c.phone?.contains(q) ?? false))
                    .toList()
                  ..sort((a, b) =>
                      balances[b.id]!.abs().compareTo(balances[a.id]!.abs()));
                if (withBalance.isEmpty) {
                  return EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: q.isEmpty ? 'No khata yet' : 'No matches',
                    subtitle: q.isEmpty
                        ? 'Tap "Open khata" to record a udhaar or payment.'
                        : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: withBalance.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = withBalance[i];
                    final bal = balances[c.id] ?? 0;
                    final owes = bal > 0;
                    final color = owes ? Colors.green : Colors.red;
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/khata/customer/${c.id}'),
                        leading: CircleAvatar(
                          backgroundImage: c.imageUrl != null
                              ? NetworkImage(c.imageUrl!)
                              : null,
                          child: c.imageUrl == null
                              ? Text(c.name.characters.first.toUpperCase())
                              : null,
                        ),
                        title: Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(owes ? 'Owes you' : 'You owe',
                            style: TextStyle(color: color, fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            Formatters.money(bal.abs(), currency),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold),
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
                            backgroundImage: c.imageUrl != null
                                ? NetworkImage(c.imageUrl!)
                                : null,
                            child: c.imageUrl == null
                                ? Text(c.name.characters.first.toUpperCase())
                                : null,
                          ),
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

/// Combined "you will get / you will give" summary banner.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.receivable,
    required this.payable,
    required this.currency,
  });
  final num receivable;
  final num payable;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Half(
                    icon: Icons.south_west,
                    label: 'You will get',
                    amount: Formatters.money(receivable, currency),
                    color: Colors.green,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Half(
                    icon: Icons.north_east,
                    label: 'You will give',
                    amount: Formatters.money(payable, currency),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline, fontSize: 12)),
        const SizedBox(height: 2),
        Text(amount,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }
}
