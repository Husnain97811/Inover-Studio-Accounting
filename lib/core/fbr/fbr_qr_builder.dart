// lib/core/fbr/fbr_qr_builder.dart
//
// C4 (part 1) — builds the string that goes INTO the QR code.
//
// FBR QR spec v2.0: the QR encodes the FBR Invoice Number (IRN / USIN) that
// came back from fiscalization. Some integrators also pack a small pipe-
// delimited summary so the QR is human-verifiable when scanned. Both are
// supported here; default is the bare IRN which is what FBR validates against.
//
// Pure logic, no Flutter widgets — so it's unit-testable offline.

class FbrQrData {
  /// The bare FBR invoice number (IRN). This is the canonical QR content.
  static String fromIrn(String irn) => irn.trim();

  /// Optional richer payload: IRN + key totals, pipe-delimited.
  /// Use only if you want the QR to carry a scannable summary. Keep it short —
  /// QR density rises fast with length.
  static String summary({
    required String irn,
    required String invoiceNumber,
    required DateTime date,
    required double total,
    required double tax,
  }) {
    final d =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return [
      irn.trim(),
      invoiceNumber.trim(),
      d,
      total.toStringAsFixed(2),
      tax.toStringAsFixed(2),
    ].join('|');
  }

  /// True when we actually have something fiscalized to encode.
  static bool canRender(String? irn) => irn != null && irn.trim().isNotEmpty;
}
