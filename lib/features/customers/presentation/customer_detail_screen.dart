import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../khata/data/khata_repository.dart';
import '../../khata/domain/khata_transaction.dart';
import '../../khata/presentation/khata_entry_screen.dart';
import '../../khata/presentation/khata_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import 'customer_providers.dart';

/// Customer profile + khata ledger (running balance, history, edit/delete).
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerByIdProvider(customerId));
    final ledger = ref.watch(customerLedgerProvider(customerId));
    final balance = ref.watch(customerBalanceProvider(customerId));
    final shop = ref.watch(currentShopProvider);
    final currency = shop?.currency ?? 'PKR';
    final canManage = shop?.canManage ?? false;
    final canCreate = shop?.canCreateReceipts ?? false;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Customer not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/customers/$customerId/edit'),
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/khata/new?customer=$customerId'),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            )
          : null,
      body: Column(
        children: [
          _BalanceHeader(balance: balance, currency: currency),
          if (customer.phone != null || customer.address != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (customer.phone != null) ...[
                    const Icon(Icons.phone_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(customer.phone!),
                    const SizedBox(width: 16),
                  ],
                  if (customer.address != null)
                    Expanded(
                      child: Text(customer.address!,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: ledger.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions',
                    subtitle: 'Add a udhaar or payment entry.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: ledger.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _LedgerTile(
                      txn: ledger[i],
                      currency: currency,
                      canManage: canManage,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KhataEntryScreen(
                            customerId: customerId,
                            existing: ledger[i],
                          ),
                        ),
                      ),
                      onDelete: () async {
                        final ok = await confirmDialog(context,
                            title: 'Delete entry?',
                            message: 'This transaction will be removed.',
                            confirmLabel: 'Delete',
                            destructive: true);
                        if (!ok) return;
                        await ref
                            .read(khataRepositoryProvider)
                            .delete(ledger[i].id);
                        ref.invalidate(khataTransactionsProvider);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance, required this.currency});
  final num balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final owes = balance > 0;
    final settled = balance == 0;
    final color = settled
        ? Theme.of(context).colorScheme.outline
        : (owes ? Colors.green : Colors.red);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            settled
                ? 'Settled up'
                : (owes ? 'Customer owes you' : 'You owe customer'),
            style: TextStyle(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.money(balance.abs(), currency),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({
    required this.txn,
    required this.currency,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });
  final KhataTransaction txn;
  final String currency;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final positive = txn.signedAmount > 0; // increases receivable
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            (positive ? Colors.green : Colors.red).withValues(alpha: 0.15),
        child: Icon(positive ? Icons.south_west : Icons.north_east,
            color: positive ? Colors.green : Colors.red, size: 20),
      ),
      title: Text(txn.type.label),
      subtitle: Text([
        Formatters.date(txn.date),
        if (txn.note != null) txn.note,
      ].whereType<String>().join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Formatters.money(txn.amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: positive ? Colors.green : Colors.red,
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
