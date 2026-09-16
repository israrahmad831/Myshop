import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/khata_repository.dart';
import '../domain/khata_transaction.dart';
import 'khata_entry_screen.dart';
import 'khata_providers.dart';

/// Dedicated full-screen khata ledger for a single customer. Opened from the
/// Khata tab. Shows the running balance and every transaction, and lets the
/// user add / edit / delete entries — the customer's khata "account".
class KhataDetailScreen extends ConsumerWidget {
  const KhataDetailScreen({super.key, required this.customerId});
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
    final scheme = Theme.of(context).colorScheme;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Khata')),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Customer not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${customer.name} — Khata'),
        actions: [
          IconButton(
            tooltip: 'Customer profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/customers/$customerId'),
          ),
        ],
      ),
      bottomNavigationBar: canCreate
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () => context
                            .push('/khata/new?customer=$customerId&type=given'),
                        icon: const Icon(Icons.south_west),
                        label: const Text('Maine diye'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => context
                            .push('/khata/new?customer=$customerId&type=taken'),
                        icon: const Icon(Icons.north_east),
                        label: const Text('Maine liye'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          _BalanceHeader(balance: balance, currency: currency),
          if (customer.phone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => dialPhone(customer.phone!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(customer.phone!,
                          style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ledger.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions',
                    subtitle: 'Tap "Add entry" to record udhaar or a payment.',
                  )
                : Builder(builder: (context) {
                    final groups = <String, List<KhataTransaction>>{};
                    for (final txn in ledger) {
                      groups.putIfAbsent(Formatters.month(txn.date), () => [])
                          .add(txn);
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        for (final group in groups.entries) ...[
                          _MonthHeading(label: group.key),
                          for (final txn in group.value)
                            _LedgerTile(
                              txn: txn,
                              currency: currency,
                              canManage: canManage,
                              onEdit: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => KhataEntryScreen(
                                    customerId: customerId,
                                    existing: txn,
                                  ),
                                ),
                              ),
                              onDelete: () async {
                                final ok = await confirmDialog(context,
                                    title: 'Delete entry?',
                                    message:
                                        'This transaction will be removed.',
                                    confirmLabel: 'Delete',
                                    destructive: true);
                                if (!ok) return;
                                await ref
                                    .read(khataRepositoryProvider)
                                    .delete(txn.id);
                                ref.invalidate(khataTransactionsProvider);
                              },
                            ),
                        ],
                      ],
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
      title: txn.note != null && txn.note!.trim().isNotEmpty
          ? Text(txn.note!,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))
          : Text(txn.type.label,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      subtitle: Text('${txn.type.label} · ${Formatters.date(txn.date)}'),
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
