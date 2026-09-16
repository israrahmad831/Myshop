import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/image_uploader.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/receipts_repository.dart';
import '../domain/receipt.dart';
import 'receipt_providers.dart';

/// Save a photo of a physical / handwritten receipt: pick an image, give it a
/// name and (optional) amount. Stored as a receipt with an image and no items.
class PhotoReceiptScreen extends ConsumerStatefulWidget {
  const PhotoReceiptScreen({super.key});
  @override
  ConsumerState<PhotoReceiptScreen> createState() =>
      _PhotoReceiptScreenState();
}

class _PhotoReceiptScreenState extends ConsumerState<PhotoReceiptScreen> {
  static const _uuid = Uuid();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  Uint8List? _bytes;
  String _ext = 'jpg';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final xfile = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _ext = xfile.name.contains('.')
            ? xfile.name.split('.').last.toLowerCase()
            : 'jpg';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bytes == null) {
      showSnack(context, 'Please add a photo of the receipt', error: true);
      return;
    }
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    setState(() => _saving = true);
    try {
      final id = _uuid.v4();
      final url = await ref.read(imageUploaderProvider).uploadReceiptImage(
            shopId: shopId,
            receiptId: id,
            bytes: _bytes!,
            fileExt: _ext,
          );
      final draft = Receipt(
        id: id,
        shopId: shopId,
        receiptNumber: 0,
        date: DateTime.now(),
        customerName: _name.text.trim(),
        imageUrl: url,
        amount: num.tryParse(_amount.text.trim()),
      );
      final saved = await ref.read(receiptsRepositoryProvider).create(draft);
      ref.invalidate(receiptsProvider);
      if (mounted) {
        showSnack(context, 'Photo receipt saved');
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo receipt')),
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
                  // Image preview / picker
                  GestureDetector(
                    onTap: () => _pick(ImageSource.gallery),
                    child: Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                        image: _bytes != null
                            ? DecorationImage(
                                image: MemoryImage(_bytes!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: _bytes == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 40),
                                  SizedBox(height: 8),
                                  Text('Tap to add a photo'),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name / label *',
                      hintText: 'e.g. Ali hardware — 12 Aug',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (v) => Validators.required(v, field: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (optional)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (v) =>
                        Validators.positiveNumber(v, field: 'Amount'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save photo receipt'),
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
