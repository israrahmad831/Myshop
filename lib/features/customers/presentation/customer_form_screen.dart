import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/image_uploader.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';
import 'customer_providers.dart';

/// Add or edit a customer. Pass [customerId] to edit.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});
  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  Customer? _existing;

  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  String? _imageUrl;

  bool get _isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _existing =
          ref.read(customersRepositoryProvider).getCached(widget.customerId!);
      final c = _existing;
      if (c != null) {
        _name.text = c.name;
        _phone.text = c.phone ?? '';
        _address.text = c.address ?? '';
        _notes.text = c.notes ?? '';
        _imageUrl = c.imageUrl;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _imageExt = xfile.name.contains('.')
            ? xfile.name.split('.').last.toLowerCase()
            : 'jpg';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(customersRepositoryProvider);
    try {
      final id = _existing?.id ?? repo.newId();
      // Upload the (optional) image first so we can store its url.
      var imageUrl = _imageUrl;
      if (_imageBytes != null) {
        imageUrl = await ref.read(imageUploaderProvider).uploadCustomerImage(
              shopId: shopId,
              customerId: id,
              bytes: _imageBytes!,
              fileExt: _imageExt,
            );
      }
      final customer = Customer(
        id: id,
        shopId: shopId,
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address:
            _address.text.trim().isEmpty ? null : _address.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        imageUrl: imageUrl,
      );
      if (_isEdit) {
        await repo.update(customer);
      } else {
        await repo.create(customer);
      }
      ref.invalidate(customersProvider);
      if (mounted) {
        showSnack(context, _isEdit ? 'Customer updated' : 'Customer added');
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'Add customer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Optional avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: scheme.surfaceContainerHighest,
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : (_imageUrl != null
                                    ? NetworkImage(_imageUrl!)
                                    : null) as ImageProvider?,
                            child: (_imageBytes == null && _imageUrl == null)
                                ? const Icon(Icons.person_outline, size: 40)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: scheme.primary,
                              child: Icon(Icons.camera_alt,
                                  size: 16, color: scheme.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text('Photo (optional)',
                        style: TextStyle(fontSize: 12, color: scheme.outline)),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => Validators.required(v, field: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
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
                        : Text(_isEdit ? 'Save changes' : 'Add customer'),
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
