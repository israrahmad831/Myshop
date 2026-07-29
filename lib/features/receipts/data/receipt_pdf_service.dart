import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show networkImage;

import '../../../core/utils/formatters.dart';
import '../../shops/domain/shop.dart';
import '../domain/receipt.dart';

/// Builds a printable/shareable A5 receipt PDF from a [Receipt] + [Shop].
class ReceiptPdfService {
  const ReceiptPdfService();

  Future<Uint8List> build(Receipt receipt, Shop shop) async {
    final doc = pw.Document();
    final currency = shop.currency;

    // Fetch the header banner image (if configured). Never fail the receipt
    // over a missing/broken image.
    pw.ImageProvider? header;
    if (shop.receiptHeaderUrl != null &&
        shop.receiptHeaderUrl!.trim().isNotEmpty) {
      try {
        header = await networkImage(shop.receiptHeaderUrl!);
      } catch (_) {
        header = null;
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header banner image (top of receipt)
            if (header != null) ...[
              pw.Center(
                child: pw.Image(header, height: 70, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 8),
            ],

            // Header
            pw.Text(shop.name,
                style: const pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (shop.address != null)
              pw.Text(shop.address!, style: const pw.TextStyle(fontSize: 10)),
            if (shop.phone != null)
              pw.Text('Ph: ${shop.phone!}',
                  style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),

            // Meta
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt #${receipt.receiptNumber}',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(Formatters.dateTime(receipt.date),
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            if (receipt.customerName != null)
              pw.Text('Customer: ${receipt.customerName}'),
            if (receipt.customerPhone != null)
              pw.Text('Phone: ${receipt.customerPhone}'),
            pw.SizedBox(height: 8),

            // Items table
            pw.TableHelper.fromTextArray(
              headerStyle: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: const ['Item', 'Qty', 'Price', 'Total'],
              data: [
                for (final it in receipt.items)
                  [
                    it.productName,
                    it.qtyLabel(Formatters.qty),
                    Formatters.qty(it.price),
                    Formatters.qty(it.lineTotal),
                  ],
              ],
            ),
            pw.SizedBox(height: 8),

            // Totals
            _totalRow('Subtotal', Formatters.money(receipt.subtotal, currency)),
            if (receipt.discount > 0)
              _totalRow('Discount',
                  '- ${Formatters.money(receipt.discount, currency)}'),
            pw.Divider(),
            _totalRow('TOTAL', Formatters.money(receipt.total, currency),
                bold: true),

            pw.Spacer(),

            // Shop stamp (owner / shop details) aligned to the right.
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _stamp(shop),
            ),
            pw.SizedBox(height: 8),

            if (shop.receiptFooter != null &&
                shop.receiptFooter!.trim().isNotEmpty)
              pw.Center(
                child: pw.Text(shop.receiptFooter!,
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: bold ? 14 : 11);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label, style: style), pw.Text(value, style: style)],
    );
  }

  /// A bordered "stamp" box with the shop's identity, printed on each receipt.
  pw.Widget _stamp(Shop shop) {
    final lines = <pw.Widget>[
      pw.Text(shop.name,
          style: const pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (shop.ownerName != null && shop.ownerName!.trim().isNotEmpty)
        pw.Text('Owner: ${shop.ownerName}',
            style: const pw.TextStyle(fontSize: 9)),
      if (shop.phone != null && shop.phone!.trim().isNotEmpty)
        pw.Text('Ph: ${shop.phone}', style: const pw.TextStyle(fontSize: 9)),
      if (shop.address != null && shop.address!.trim().isNotEmpty)
        pw.Text(shop.address!, style: const pw.TextStyle(fontSize: 9)),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue800, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('SHOP STAMP',
              style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.blue800,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1)),
          pw.SizedBox(height: 2),
          ...lines,
        ],
      ),
    );
  }
}
