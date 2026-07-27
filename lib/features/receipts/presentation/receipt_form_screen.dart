import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../products/domain/product.dart';
import '../../products/data/products_repository.dart';
import '../../products/presentation/product_providers.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/receipts_repository.dart';
import '../domain/receipt.dart';
import 'receipt_providers.dart';

/// Create a new receipt. Adding products offers instant type-ahead suggestions
/// (e.g. typing "be" suggests "Berger …"). Selecting fills name + selling
/// price; the user may still edit the price.
class ReceiptFormScreen extends ConsumerStatefulWidget {
  const ReceiptFormScreen({super.key});
  @override
  ConsumerState<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends ConsumerState<ReceiptFormScreen> {
  static const _uuid = Uuid();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _note = TextEditingController();
  final List<ReceiptItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _discount.dispose();
    _note.dispose();
    super.dispose();
  }

  num get _subtotal =>
      _items.fold<num>(0, (s, i) => s + i.lineTotal);
  num get _total => _subtotal - (num.tryParse(_discount.text.trim()) ?? 0);

  void _addProduct(Product p) {
    setState(() {
      _items.add(ReceiptItem(
        id: _uuid.v4(),
        productId: p.id,
        productName: p.name,
        quantity: 1,
        price: p.sellingPrice,
      ));
    });
    // Feed the "top searched products" report (fire-and-forget).
    final shopId = ref.read(currentShopIdProvider);
    if (shopId != null) {
      ref.read(productsRepositoryProvider).recordSearch(shopId, p.id, p.name);
    }
  }

  void _addCustomItem(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _items.add(ReceiptItem(id: _uuid.v4(), productName: name.trim()));
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      showSnack(context, 'Add at least one product', error: true);
      return;
    }
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _saving = true);
    try {
      final draft = Receipt(
        id: '',
        shopId: shopId,
        receiptNumber: 0,
        date: DateTime.now(),
        customerName: _customerName.text.trim().isEmpty
            ? null
            : _customerName.text.trim(),
        customerPhone: _customerPhone.text.trim().isEmpty
            ? null
            : _customerPhone.text.trim(),
        discount: num.tryParse(_discount.text.trim()) ?? 0,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        items: _items,
      );
      final saved =
          await ref.read(receiptsRepositoryProvider).create(draft);
      ref.invalidate(receiptsProvider);
      if (mounted) {
        showSnack(context, 'Receipt #${saved.receiptNumber} saved');
        context.pushReplacement('/receipts/${saved.id}');
      }
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure products are loaded so the type-ahead cache is warm.
    ref.watch(productsProvider);
    final currency = ref.watch(currentShopProvider)?.currency ?? 'PKR';
    final shopId = ref.watch(currentShopIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New receipt')),
      bottomNavigationBar: _TotalBar(
        total: Formatters.money(_total, currency),
        saving: _saving,
        onSave: _save,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Customer (optional) --------------------------------------
          Text('Customer (optional)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _customerName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _customerPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // --- Product type-ahead ---------------------------------------
          Text('Add product',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _ProductTypeAhead(
            onSelected: _addProduct,
            onCustom: _addCustomItem,
            suggest: (query) => shopId == null
                ? const <Product>[]
                : ref
                    .read(productsRepositoryProvider)
                    .suggest(shopId, query),
          ),
          const SizedBox(height: 16),

          // --- Line items -----------------------------------------------
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No products added yet')),
            )
          else
            ..._items.asMap().entries.map((e) => _LineItemCard(
                  key: ValueKey(e.value.id),
                  item: e.value,
                  currency: currency,
                  onChanged: (updated) =>
                      setState(() => _items[e.key] = updated),
                  onRemove: () => setState(() => _items.removeAt(e.key)),
                )),

          const SizedBox(height: 16),
          // --- Discount + note ------------------------------------------
          Row(children: [
            Expanded(
              child: TextField(
                controller: _discount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Discount (whole receipt)'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Subtotal', value: Formatters.money(_subtotal, currency)),
          _SummaryRow(
              label: 'Discount',
              value:
                  '- ${Formatters.money(num.tryParse(_discount.text.trim()) ?? 0, currency)}'),
          const Divider(),
          _SummaryRow(
              label: 'Total',
              value: Formatters.money(_total, currency),
              bold: true),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Autocomplete field over products. Also allows adding a custom item.
class _ProductTypeAhead extends StatefulWidget {
  const _ProductTypeAhead({
    required this.onSelected,
    required this.onCustom,
    required this.suggest,
  });
  final void Function(Product) onSelected;
  final void Function(String) onCustom;
  final List<Product> Function(String query) suggest;

  @override
  State<_ProductTypeAhead> createState() => _ProductTypeAheadState();
}

class _ProductTypeAheadState extends State<_ProductTypeAhead> {
  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return const Iterable<Product>.empty();
        return widget.suggest(value.text);
      },
      onSelected: (p) => widget.onSelected(p),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Type to search products…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Add as custom item',
              icon: const Icon(Icons.add),
              onPressed: () {
                widget.onCustom(controller.text);
                controller.clear();
              },
            ),
          ),
          onSubmitted: (v) {
            widget.onCustom(v);
            controller.clear();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options
                    .map((p) => ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: p.brand != null ? Text(p.brand!) : null,
                          trailing: Text(p.sellingPrice.toString()),
                          onTap: () => onSelected(p),
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({
    super.key,
    required this.item,
    required this.currency,
    required this.onChanged,
    required this.onRemove,
  });
  final ReceiptItem item;
  final String currency;
  final ValueChanged<ReceiptItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(Formatters.money(item.lineTotal, currency),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(children: [
              Expanded(
                child: _MiniField(
                  label: 'Qty',
                  initial: item.quantity,
                  onChanged: (v) => onChanged(item.copyWith(quantity: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniField(
                  label: 'Price',
                  initial: item.price,
                  onChanged: (v) => onChanged(item.copyWith(price: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniField(
                  label: 'Disc.',
                  initial: item.discount,
                  onChanged: (v) => onChanged(item.copyWith(discount: v)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });
  final String label;
  final num initial;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial == initial.toInt()
          ? initial.toInt().toString()
          : initial.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onChanged: (v) => onChanged(num.tryParse(v.trim()) ?? 0),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 18 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar(
      {required this.total, required this.saving, required this.onSave});
  final String total;
  final bool saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total'),
                  Text(total,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Save receipt'),
            ),
          ],
        ),
      ),
    );
  }
}
