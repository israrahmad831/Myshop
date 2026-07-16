import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/shops_repository.dart';
import '../domain/shop.dart';
import 'shop_providers.dart';

/// Create or edit a shop. Pass [existing] to edit.
class ShopFormScreen extends ConsumerStatefulWidget {
  const ShopFormScreen({super.key, this.existing});
  final Shop? existing;

  @override
  ConsumerState<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends ConsumerState<ShopFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _currency;
  late final TextEditingController _footer;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name);
    _address = TextEditingController(text: s?.address);
    _phone = TextEditingController(text: s?.phone);
    _currency = TextEditingController(text: s?.currency ?? 'PKR');
    _footer = TextEditingController(text: s?.receiptFooter);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _currency.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(shopsRepositoryProvider);
    try {
      final draft = (widget.existing ??
              const Shop(id: '', ownerId: '', name: ''))
          .copyWith(
        name: _name.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        currency: _currency.text.trim().isEmpty ? 'PKR' : _currency.text.trim(),
        receiptFooter: _footer.text.trim(),
      );
      final saved =
          _isEdit ? await repo.updateShop(draft) : await repo.createShop(draft);
      ref.invalidate(myShopsProvider);
      if (!_isEdit) {
        await ref.read(currentShopIdProvider.notifier).select(saved.id);
      }
      if (mounted) {
        showSnack(context, _isEdit ? 'Shop updated' : 'Shop created');
        context.go('/');
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit shop' : 'New shop')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Shop name *',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (v) => Validators.required(v, field: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _currency,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      prefixIcon: Icon(Icons.attach_money),
                      helperText: 'e.g. PKR, USD, INR',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _footer,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Receipt footer',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      helperText: 'Shown at the bottom of printed receipts',
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Save changes' : 'Create shop'),
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
