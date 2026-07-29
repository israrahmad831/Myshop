import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/image_uploader.dart';
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
  late final TextEditingController _ownerName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _currency;
  late final TextEditingController _footer;
  bool _saving = false;

  Uint8List? _headerBytes;
  String _headerExt = 'jpg';
  String? _headerUrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name);
    _ownerName = TextEditingController(text: s?.ownerName);
    _address = TextEditingController(text: s?.address);
    _phone = TextEditingController(text: s?.phone);
    _currency = TextEditingController(text: s?.currency ?? 'PKR');
    _footer = TextEditingController(text: s?.receiptFooter);
    _headerUrl = s?.receiptHeaderUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _ownerName.dispose();
    _address.dispose();
    _phone.dispose();
    _currency.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _pickHeader() async {
    final xfile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (mounted) {
      setState(() {
        _headerBytes = bytes;
        _headerExt = xfile.name.contains('.')
            ? xfile.name.split('.').last.toLowerCase()
            : 'jpg';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(shopsRepositoryProvider);
    try {
      final draft =
          (widget.existing ?? const Shop(id: '', ownerId: '', name: '')).copyWith(
        name: _name.text.trim(),
        ownerName: _ownerName.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        currency: _currency.text.trim().isEmpty ? 'PKR' : _currency.text.trim(),
        receiptFooter: _footer.text.trim(),
        receiptHeaderUrl: _headerUrl,
      );
      var saved =
          _isEdit ? await repo.updateShop(draft) : await repo.createShop(draft);

      // Upload the header image now that we have a shop id, then persist its url.
      if (_headerBytes != null) {
        final url = await ref.read(imageUploaderProvider).uploadShopImage(
              shopId: saved.id,
              kind: 'header',
              bytes: _headerBytes!,
              fileExt: _headerExt,
            );
        saved = await repo.updateShop(saved.copyWith(receiptHeaderUrl: url));
      }

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
                    controller: _ownerName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Owner name',
                      prefixIcon: Icon(Icons.person_outline),
                      helperText: 'Shown on the receipt stamp',
                    ),
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
                  const SizedBox(height: 24),

                  // --- Receipt header image ---------------------------------
                  Text('Receipt header image',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Shown as a banner at the top of printed receipts',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 8),
                  _HeaderPicker(
                    bytes: _headerBytes,
                    url: _headerUrl,
                    onTap: _pickHeader,
                    onClear: (_headerBytes != null || _headerUrl != null)
                        ? () => setState(() {
                              _headerBytes = null;
                              _headerUrl = null;
                            })
                        : null,
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

class _HeaderPicker extends StatelessWidget {
  const _HeaderPicker({
    required this.bytes,
    required this.url,
    required this.onTap,
    this.onClear,
  });
  final Uint8List? bytes;
  final String? url;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
              image: bytes != null
                  ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
                  : (url != null
                      ? DecorationImage(
                          image: NetworkImage(url!), fit: BoxFit.cover)
                      : null),
            ),
            child: (bytes == null && url == null)
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 32),
                        SizedBox(height: 6),
                        Text('Add header image'),
                      ],
                    ),
                  )
                : null,
          ),
        ),
        if (onClear != null)
          Positioned(
            top: 6,
            right: 6,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black54,
              child: IconButton(
                iconSize: 18,
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClear,
              ),
            ),
          ),
      ],
    );
  }
}
