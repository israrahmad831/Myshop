import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/expenses_repository.dart';
import '../domain/expense.dart';

final expensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return const [];
  return ref.watch(expensesRepositoryProvider).list(shopId);
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (saved == true) ref.invalidate(expensesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final shop = ref.watch(currentShopProvider);
    final canCreate = shop?.canCreateReceipts ?? false;
    final currency = shop?.currency ?? 'PKR';

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'expenses-fab',
              onPressed: () => _addExpense(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            )
          : null,
      body: AsyncView<List<Expense>>(
        value: expenses,
        onRetry: () => ref.invalidate(expensesProvider),
        data: (items) {
          final total = items.fold<num>(0, (sum, item) => sum + item.amount);
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.payments_outlined,
              title: 'No expenses',
              subtitle: canCreate ? 'Record your first shop expense.' : null,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(expensesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text('Total expenses'),
                      trailing: Text(Formatters.money(total, currency),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  );
                }
                final expense = items[index - 1];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_iconFor(expense.category)),
                    ),
                    title: Text(
                      expense.category?.trim().isNotEmpty == true
                          ? expense.category!
                          : 'Shop expense',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text([
                      Formatters.date(expense.date),
                      if (expense.note?.trim().isNotEmpty == true)
                        expense.note!,
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Formatters.money(expense.amount, currency),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        if (shop?.canManage == true)
                          IconButton(
                            tooltip: 'Delete expense',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await confirmDialog(context,
                                  title: 'Delete expense?',
                                  message: 'This cannot be undone.',
                                  confirmLabel: 'Delete',
                                  destructive: true);
                              if (!ok) return;
                              await ref
                                  .read(expensesRepositoryProvider)
                                  .delete(expense.id);
                              ref.invalidate(expensesProvider);
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static IconData _iconFor(String? category) {
    switch (category?.toLowerCase()) {
      case 'rent':
        return Icons.home_work_outlined;
      case 'salary':
        return Icons.badge_outlined;
      case 'utility':
      case 'utilities':
        return Icons.bolt_outlined;
      case 'transport':
        return Icons.local_shipping_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog();

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(expensesRepositoryProvider).create(Expense(
            id: _uuid.v4(),
            shopId: shopId,
            amount: num.parse(_amount.text.trim()),
            date: _date,
            category:
                _category.text.trim().isEmpty ? null : _category.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Add expense',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixIcon: Icon(Icons.payments_outlined)),
                    validator: (value) {
                      final required =
                          Validators.required(value, field: 'Amount');
                      if (required != null) return required;
                      final amount = num.tryParse(value!.trim());
                      return amount == null || amount <= 0
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(Formatters.date(_date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Note',
                        prefixIcon: Icon(Icons.note_outlined)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save expense'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
