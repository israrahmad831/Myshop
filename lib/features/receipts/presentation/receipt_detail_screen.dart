import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shops/presentation/shop_providers.dart';
import '../data/receipt_pdf_service.dart';
import '../data/receipts_repository.dart';
import '../domain/receipt.dart';
import 'receipt_providers.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});
  final String receiptId;

  Future<Uint8List?> _pdf(WidgetRef ref, Receipt receipt) async {
    final shop = ref.read(currentShopProvider);
    if (shop == null) return null;
    return const ReceiptPdfService().build(receipt, shop);
  }

  Future<Uint8List?> _photoBytes(Receipt receipt) async {
    if (!receipt.isPhoto) return null;
    final response = await http.get(Uri.parse(receipt.imageUrl!));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptByIdProvider(receiptId));
    final shop = ref.watch(currentShopProvider);
    final currency = shop?.currency ?? 'PKR';
    final canManage = shop?.canManage ?? false;

    if (receipt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Receipt not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt #${receipt.receiptNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () async {
              final bytes = await _pdf(ref, receipt);
              if (bytes != null) {
                await Printing.layoutPdf(onLayout: (_) async => bytes);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () async {
              if (receipt.isPhoto) {
                final bytes = await _photoBytes(receipt);
                if (bytes == null || !context.mounted) return;
                await Share.shareXFiles([
                  XFile.fromData(bytes,
                      name: 'receipt_${receipt.receiptNumber}.jpg',
                      mimeType: 'image/jpeg'),
                ]);
                return;
              }
              final bytes = await _pdf(ref, receipt);
              if (bytes == null) return;
              await Share.shareXFiles([
                XFile.fromData(bytes,
                    name: 'receipt_${receipt.receiptNumber}.pdf',
                    mimeType: 'application/pdf'),
              ]);
            },
          ),
          if (receipt.isPhoto)
            IconButton(
              icon: const Icon(Icons.save_alt_outlined),
              tooltip: 'Save to gallery',
              onPressed: () async {
                try {
                  final bytes = await _photoBytes(receipt);
                  if (bytes == null) {
                    throw Exception('Could not download photo');
                  }
                  await Gal.putImageBytes(bytes,
                      album: 'Shop Manager',
                      name: 'receipt_${receipt.receiptNumber}');
                  if (context.mounted) {
                    showSnack(context, 'Saved to gallery');
                  }
                } catch (e) {
                  if (context.mounted) showSnack(context, '$e', error: true);
                }
              },
            ),
          if (canManage && !receipt.isPhoto)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => context.push('/receipts/$receiptId/edit'),
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Delete receipt?',
                    message: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true);
                if (!ok) return;
                await ref.read(receiptsRepositoryProvider).delete(receiptId);
                ref.invalidate(receiptsProvider);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(Formatters.dateTime(receipt.date),
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          if (receipt.customerName != null) ...[
            const SizedBox(height: 8),
            Text('Customer: ${receipt.customerName}'),
            if (receipt.customerPhone != null)
              Text('Phone: ${receipt.customerPhone}'),
          ],
          const SizedBox(height: 16),
          if (receipt.isPhoto) ...[
            // Uploaded photo of a physical/handwritten receipt.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: CachedNetworkImage(imageUrl: receipt.imageUrl!),
                    ),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: receipt.imageUrl!,
                  fit: BoxFit.fitWidth,
                  placeholder: (_, __) => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator())),
                ),
              ),
            ),
            if (receipt.total > 0) ...[
              const SizedBox(height: 12),
              _row(context, 'Amount', Formatters.money(receipt.total, currency),
                  bold: true),
            ],
          ] else ...[
            Card(
              child: Column(
                children: [
                  for (final it in receipt.items)
                    ListTile(
                      title: Text(it.productName),
                      subtitle: Text(
                          '${it.qtyLabel(Formatters.qty)} × ${Formatters.money(it.price, currency)}'
                          '${it.discount > 0 ? '  (- ${Formatters.qty(it.discount)})' : ''}'),
                      trailing: Text(Formatters.money(it.lineTotal, currency),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row(context, 'Subtotal',
                Formatters.money(receipt.subtotal, currency)),
            if (receipt.discount > 0)
              _row(context, 'Discount',
                  '- ${Formatters.money(receipt.discount, currency)}'),
            const Divider(),
            _row(context, 'Total', Formatters.money(receipt.total, currency),
                bold: true),
          ],
          if (receipt.note != null) ...[
            const SizedBox(height: 16),
            Text('Note: ${receipt.note}'),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
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
