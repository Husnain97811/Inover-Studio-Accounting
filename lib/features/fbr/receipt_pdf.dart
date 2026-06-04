// lib/features/fbr/receipt_pdf.dart
//
// C4 (part 3) — generates a PDF receipt (80mm thermal width or A5) using the
// `printing` + `pdf` packages you already have. This is the PRINTER-FREE
// fallback: when no printer is available, the user saves/shares this PDF.
//
// The QR is rendered into the PDF via barcode support built into the pdf pkg,
// so no widget capture is needed.

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/fbr/fbr_qr_builder.dart';
import 'receipt_data.dart';

class ReceiptPdf {
  /// 80mm thermal-style receipt (narrow). Good for save/share/print.
  static Future<Uint8List> build(ReceiptData r) async {
    final doc = pw.Document();

    // 80mm wide, height grows with content.
    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 6 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // ── Header ──
            pw.Text(
              r.businessName,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            if (r.businessAddress != null)
              pw.Text(
                r.businessAddress!,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            if (r.ntn != null)
              pw.Text('NTN: ${r.ntn}', style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.5),

            // ── Invoice meta ──
            _row('Invoice', r.invoiceNumber),
            _row('Date', _fmt(r.date)),
            _row('Payment', r.paymentMode),
            pw.Divider(thickness: 0.5),

            // ── Items ──
            ...r.lines.map(
              (l) => pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          l.name,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Text(
                        l.lineTotal.toStringAsFixed(0),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      '  ${l.qty.toStringAsFixed(l.qty == l.qty.roundToDouble() ? 0 : 2)} x ${l.unitPrice.toStringAsFixed(0)}',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Divider(thickness: 0.5),

            // ── Totals ──
            _row('Subtotal', r.subtotal.toStringAsFixed(0)),
            if (r.discount > 0)
              _row('Discount', '-${r.discount.toStringAsFixed(0)}'),
            _row('GST', r.tax.toStringAsFixed(0)),
            pw.SizedBox(height: 2),
            _row(
              'TOTAL',
              'Rs. ${r.total.toStringAsFixed(0)}',
              bold: true,
              big: true,
            ),
            pw.SizedBox(height: 8),

            // ── FBR / QR ──
            if (r.isFiscalized) ...[
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: FbrQrData.fromIrn(r.irn!),
                width: 90,
                height: 90,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'FBR Invoice #',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                r.irn!,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ] else
              pw.Text(
                'FBR status: ${r.fbrStatus} (not yet fiscalized)',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),

            pw.SizedBox(height: 8),
            pw.Text('Thank you!', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _row(
    String l,
    String v, {
    bool bold = false,
    bool big = false,
  }) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        l,
        style: pw.TextStyle(
          fontSize: big ? 11 : 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        v,
        style: pw.TextStyle(
          fontSize: big ? 11 : 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
