import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../../shops/domain/shop.dart';
import '../domain/receipt.dart';

/// Builds a printable/shareable A5 receipt PDF from a [Receipt] + [Shop].
///
class ReceiptPdfService {
  const ReceiptPdfService();

  Future<pw.ImageProvider?> _loadImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final decoded = img.decodeImage(response.bodyBytes);
      if (decoded == null) return null;
      final oriented = img.bakeOrientation(decoded);
      final longest =
          oriented.width > oriented.height ? oriented.width : oriented.height;
      final normalized = longest > 1600
          ? (oriented.width >= oriented.height
              ? img.copyResize(oriented, width: 1600)
              : img.copyResize(oriented, height: 1600))
          : oriented;
      return pw.MemoryImage(
          Uint8List.fromList(img.encodeJpg(normalized, quality: 90)));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> build(Receipt receipt, Shop shop) async {
    final doc = pw.Document();
    final currency = shop.currency;

    // Header banner image (if configured).
    final header = await _loadImage(shop.receiptHeaderUrl);

    // Photo receipt: just render the uploaded photo (+ label / amount).
    if (receipt.isPhoto) {
      final photo = await _loadImage(receipt.imageUrl);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (receipt.customerName != null &&
                  receipt.customerName!.trim().isNotEmpty)
                pw.Text(receipt.customerName!,
                    style: const pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(Formatters.dateTime(receipt.date),
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 8),
              if (photo != null)
                pw.Expanded(child: pw.Image(photo, fit: pw.BoxFit.contain)),
              if (receipt.total > 0) ...[
                pw.SizedBox(height: 8),
                pw.Text('Amount: ${Formatters.money(receipt.total, currency)}',
                    style: const pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ],
            ],
          ),
        ),
      );
      return doc.save();
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Full-width header banner image; the uploaded image is the shop's
            // branding (no shop text header, no stamp).
            if (header != null) ...[
              pw.Center(
                  child: pw.Image(header, height: 100, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 6),
            ],
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
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
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

            if (receipt.note != null && receipt.note!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Note: ${receipt.note}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],

            pw.Spacer(),

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
}
