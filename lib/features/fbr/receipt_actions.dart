// lib/features/fbr/receipt_actions.dart
//
// C4 (part 5) — the print / PDF-fallback logic you asked for.
//
// Flow:
//   • User taps Print.
//   • We check for an available printer (printing pkg).
//   • If a printer exists → print directly.
//   • If NONE → show "Printer not available" dialog with a "Save PDF" button.
//     Save PDF uses the system share/save sheet (printing pkg's sharePdf).
//
// Works on Windows/macOS desktop and mobile.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import 'receipt_data.dart';
import 'receipt_pdf.dart';

class ReceiptActions {
  /// Entry point for the receipt's "Print" button.
  static Future<void> printOrFallback(
    BuildContext context,
    ReceiptData data,
  ) async {
    final pdfBytes = await ReceiptPdf.build(data);

    // Discover printers. Empty list (or thrown) => no printer available.
    List<Printer> printers = const [];
    try {
      printers = await Printing.listPrinters();
    } catch (_) {
      printers = const [];
    }

    final hasPrinter = printers.isNotEmpty;

    if (hasPrinter) {
      // Direct print path.
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Invoice_${data.invoiceNumber}',
      );
      return;
    }

    // No printer → show the dialog with Save-PDF fallback.
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PrinterUnavailableDialog(
        onSavePdf: () async {
          Navigator.of(ctx).pop();
          await Printing.sharePdf(
            bytes: pdfBytes,
            filename: 'Invoice_${data.invoiceNumber}.pdf',
          );
        },
      ),
    );
  }

  /// Direct "Save as PDF" (e.g. a separate button) — no printer check.
  static Future<void> savePdf(ReceiptData data) async {
    final pdfBytes = await ReceiptPdf.build(data);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${data.invoiceNumber}.pdf',
    );
  }
}

class _PrinterUnavailableDialog extends StatelessWidget {
  final Future<void> Function() onSavePdf;
  const _PrinterUnavailableDialog({required this.onSavePdf});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: D.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        children: const [
          Icon(Icons.print_disabled_rounded, color: D.warning500, size: 20),
          SizedBox(width: 8),
          Text(
            'Printer not available',
            style: TextStyle(
              fontFamily: 'Instrument Serif',
              fontSize: 18,
              color: D.ink800,
            ),
          ),
        ],
      ),
      content: const Text(
        'No printer was found. You can save the receipt as a PDF instead — '
        'then print, share, or send it to the customer on WhatsApp.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: D.fgSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: onSavePdf,
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
          label: const Text('Save PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: D.brand500,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
