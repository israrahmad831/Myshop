import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/khata_repository.dart';
import '../domain/khata_transaction.dart';
import 'khata_providers.dart';

/// Add or edit a khata transaction for a customer. Pass [existing] to edit.
class KhataEntryScreen extends ConsumerStatefulWidget {
  const KhataEntryScreen({
    super.key,
    required this.customerId,
    this.existing,
    this.initialType = KhataType.udhaarGiven,
  });
  final String customerId;
  final KhataTransaction? existing;
  final KhataType initialType;

  @override
  ConsumerState<KhataEntryScreen> createState() => _KhataEntryScreenState();
}

class _KhataEntryScreenState extends ConsumerState<KhataEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  late KhataType _type;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _amount.text = e.amount.toString();
      _note.text = e.note ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(khataRepositoryProvider);
    try {
      final txn = KhataTransaction(
        id: widget.existing?.id ?? '',
        shopId: shopId,
        customerId: widget.customerId,
        type: _type,
        amount: num.tryParse(_amount.text.trim()) ?? 0,
        date: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (_isEdit) {
        await repo.update(txn);
      } else {
        await repo.create(txn);
      }
      ref.invalidate(khataTransactionsProvider);
      if (mounted) {
        showSnack(context, _isEdit ? 'Entry updated' : 'Entry added');
        context.pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit entry' : 'Add khata entry')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _type == KhataType.udhaarGiven
                          ? 'Maine diye'
                          : 'Maine liye',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _amount,
                      focusNode: _amountFocus,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 42, fontWeight: FontWeight.w700),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixIcon: Icon(Icons.payments_outlined),
                        hintText: '0',
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      ),
                      validator: (v) {
                        final base = Validators.required(v, field: 'Amount');
                        if (base != null) return base;
                        final n = num.tryParse(v!.trim());
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Date'),
                      subtitle: Text('${_date.toLocal()}'.split(' ')[0]),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        prefixIcon: Icon(Icons.note_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isEdit ? 'Save changes' : 'Add entry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
