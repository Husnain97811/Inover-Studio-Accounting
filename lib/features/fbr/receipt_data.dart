// lib/features/fbr/receipt_data.dart
//
// C4 (part 2) — a plain data bundle describing everything a receipt shows.
// Built from the Drift invoice + items. No Flutter, no DB calls — so both the
// on-screen widget and the PDF generator consume the SAME source of truth and
// can't drift apart.

class ReceiptLine {
  final String name;
  final double qty;
  final double unitPrice;
  final double lineTotal;
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });
}

class ReceiptData {
  // Business
  final String businessName;
  final String? businessAddress;
  final String? ntn;

  // Invoice
  final String invoiceNumber;
  final DateTime date;
  final List<ReceiptLine> lines;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMode;

  // FBR
  final String? irn; // null until fiscalized
  final String fbrStatus; // pending / submitting / verified / failed / rejected

  const ReceiptData({
    required this.businessName,
    required this.invoiceNumber,
    required this.date,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMode,
    this.businessAddress,
    this.ntn,
    this.irn,
    required this.fbrStatus,
  });

  bool get isFiscalized => irn != null && irn!.trim().isNotEmpty;

  int get itemCount => lines.length;
  double get totalQty => lines.fold(0.0, (s, l) => s + l.qty);
}
