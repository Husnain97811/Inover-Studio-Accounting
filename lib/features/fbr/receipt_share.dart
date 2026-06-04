// lib/features/fbr/receipt_share.dart
//
// WhatsApp / generic receipt sharing — Option 1 (file-first).
//
// Tap → build the receipt PDF → open the OS share sheet with the PDF attached →
// user taps WhatsApp → picks the customer → sends. The PDF goes reliably; the
// only manual step is choosing the contact (a WhatsApp limitation, not ours).
//
// Uses share_plus. Works on Windows/macOS desktop and mobile.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'receipt_data.dart';
import 'receipt_pdf.dart';

class ReceiptShare {
  /// Generic share — opens the OS share sheet (WhatsApp, email, etc.) with the
  /// receipt PDF attached. This is the Option-1 flow.
  static Future<void> sharePdf(ReceiptData data) async {
    final file = await _writeTempPdf(data);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Invoice ${data.invoiceNumber}',
      text:
          'Your invoice from ${data.businessName}'
          '${data.isFiscalized ? ' (FBR #${data.irn})' : ''}',
    );
  }

  /// Convenience alias intended for a WhatsApp-labelled button. On the share
  /// sheet the user simply taps WhatsApp, then the contact. (Pre-selecting both
  /// a file AND a specific contact in one tap isn't supported by WhatsApp.)
  static Future<void> shareToWhatsApp(ReceiptData data) => sharePdf(data);

  static Future<File> _writeTempPdf(ReceiptData data) async {
    final bytes = await ReceiptPdf.build(data);
    final dir = await getTemporaryDirectory();
    final safeNo = data.invoiceNumber.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${dir.path}/Invoice_$safeNo.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
