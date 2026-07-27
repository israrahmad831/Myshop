import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              final bytes = await _pdf(ref, receipt);
              if (bytes == null) return;
              await Share.shareXFiles([
                XFile.fromData(bytes,
                    name: 'receipt_${receipt.receiptNumber}.pdf',
                    mimeType: 'application/pdf'),
              ]);
            },
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
                await ref
                    .read(receiptsRepositoryProvider)
                    .delete(receiptId);
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
