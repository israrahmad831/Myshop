import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/image_uploader.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';
import 'product_providers.dart';

/// Add or edit a product. Pass [productId] to edit.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _category = TextEditingController();
  final _purchase = TextEditingController();
  final _selling = TextEditingController();
  final _stock = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();
  String _unit = 'pcs';
  String? _imageUrl;
  Uint8List? _pickedBytes; // works on web + mobile
  String _pickedExt = 'jpg';
  bool _saving = false;
  Product? _existing;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _existing =
          ref.read(productsRepositoryProvider).getCached(widget.productId!);
      final p = _existing;
      if (p != null) {
        _name.text = p.name;
        _brand.text = p.brand ?? '';
        _category.text = p.category ?? '';
        _purchase.text = p.purchasePrice.toString();
        _selling.text = p.sellingPrice.toString();
        _stock.text = p.currentStock.toString();
        _barcode.text = p.barcode ?? '';
        _description.text = p.description ?? '';
        _unit = p.unit;
        _imageUrl = p.imageUrl;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _brand, _category, _purchase, _selling, _stock,
      _barcode, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final ext = xfile.name.contains('.')
        ? xfile.name.split('.').last.toLowerCase()
        : 'jpg';
    if (mounted) {
      setState(() {
        _pickedBytes = bytes;
        _pickedExt = ext;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(productsRepositoryProvider);
    try {
      // Build the product (with a stable id so we can upload its image first).
      final id = _existing?.id ?? repo.newId();
      var imageUrl = _imageUrl;
      if (_pickedBytes != null) {
        imageUrl = await ref.read(imageUploaderProvider).uploadProductImage(
              shopId: shopId,
              productId: id,
              bytes: _pickedBytes!,
              fileExt: _pickedExt,
            );
      }
      final product = Product(
        id: id,
        shopId: shopId,
        name: _name.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        category:
            _category.text.trim().isEmpty ? null : _category.text.trim(),
        purchasePrice: num.tryParse(_purchase.text.trim()) ?? 0,
        sellingPrice: num.tryParse(_selling.text.trim()) ?? 0,
        currentStock: num.tryParse(_stock.text.trim()) ?? 0,
        unit: _unit,
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        imageUrl: imageUrl,
      );

      if (_isEdit) {
        await repo.update(product);
      } else {
        // Reuse the pre-generated id via an insert row.
        await repo.create(product);
      }
      ref.invalidate(productsProvider);
      if (mounted) {
        showSnack(context, _isEdit ? 'Product updated' : 'Product added');
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        image: _pickedBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_pickedBytes!),
                                fit: BoxFit.cover)
                            : (_imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_imageUrl!),
                                    fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_pickedBytes == null && _imageUrl == null)
                          ? const Icon(Icons.add_a_photo_outlined, size: 32)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => Validators.required(v, field: 'Name'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: 'Brand'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      decoration:
                          const InputDecoration(labelText: 'Category'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchase,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Purchase price'),
                      validator: (v) =>
                          Validators.positiveNumber(v, field: 'Price'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _selling,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Selling price'),
                      validator: (v) =>
                          Validators.positiveNumber(v, field: 'Price'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Stock (manual)'),
                      validator: (v) =>
                          Validators.positiveNumber(v, field: 'Stock'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: AppConstants.defaultUnits
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcode,
                  decoration:
                      const InputDecoration(labelText: 'Barcode (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Save changes' : 'Add product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
