// lib/features/fbr/receipt_view.dart
//
// C4 (part 4) — on-screen receipt widget, RESPONSIVE.
// Adapts width to its container (clamped 260–360) and scales fonts via sizer,
// with .clamp() floors/ceilings so it stays readable on tiny phones and tidy
// on wide desktop sheets. QR size scales with the receipt width.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sizer/sizer.dart';

import '../../core/fbr/fbr_qr_builder.dart';
import '../../core/theme/app_theme.dart';
import 'receipt_data.dart';

class ReceiptView extends StatelessWidget {
  final ReceiptData data;

  /// Optional hard width. If null, the widget sizes to its parent (clamped).
  final double? width;

  const ReceiptView({super.key, required this.data, this.width});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Resolve a sensible width: explicit > parent-driven > clamped default.
        final available = c.maxWidth.isFinite ? c.maxWidth : 320.0;
        final w = (width ?? available).clamp(260.0, 360.0);

        // Font sizes scale with sizer but clamp so they never get silly.
        final titleSz = 18.sp.clamp(17.0, 22.0);
        final bodySz = 11.sp.clamp(11.0, 13.0);
        final smallSz = 9.sp.clamp(8.5, 11.0);
        final totalSz = 15.sp.clamp(14.0, 18.0);
        final qrSize = (w * 0.42).clamp(110.0, 150.0); // QR scales w/ width

        return Container(
          width: w,
          padding: EdgeInsets.all((w * 0.06).clamp(14.0, 22.0)),
          decoration: BoxDecoration(
            color: D.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: D.borderDefault),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.businessName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Instrument Serif',
                    fontSize: titleSz,
                    color: D.ink800,
                  ),
                ),
                if (data.businessAddress != null)
                  Text(
                    data.businessAddress!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: smallSz,
                      color: D.fgTertiary,
                    ),
                  ),
                if (data.ntn != null)
                  Text(
                    'NTN: ${data.ntn}',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: smallSz,
                      color: D.fgTertiary,
                    ),
                  ),
                const Divider(height: 20),

                _row('Invoice', data.invoiceNumber, bodySz),
                _row('Date', _fmt(data.date), bodySz),
                _row('Payment', data.paymentMode, bodySz),
                const Divider(height: 16),

                ...data.lines.map(
                  (l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: bodySz,
                                  color: D.fgPrimary,
                                ),
                              ),
                              Text(
                                '${_q(l.qty)} × ${l.unitPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: smallSz,
                                  color: D.fgTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Rs. ${l.lineTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: bodySz,
                            fontWeight: FontWeight.w600,
                            color: D.fgPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16),

                _row(
                  'Subtotal',
                  'Rs. ${data.subtotal.toStringAsFixed(0)}',
                  bodySz,
                ),
                if (data.discount > 0)
                  _row(
                    'Discount',
                    '- Rs. ${data.discount.toStringAsFixed(0)}',
                    bodySz,
                  ),
                _row('GST', 'Rs. ${data.tax.toStringAsFixed(0)}', bodySz),
                const SizedBox(height: 6),
                _row(
                  'TOTAL',
                  'Rs. ${data.total.toStringAsFixed(0)}',
                  totalSz,
                  big: true,
                ),
                const SizedBox(height: 16),

                // ── FBR QR block ──
                if (data.isFiscalized) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: D.borderGold),
                    ),
                    child: QrImageView(
                      data: FbrQrData.fromIrn(data.irn!),
                      version: QrVersions.auto,
                      size: qrSize.toDouble(),
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'FBR Invoice Number',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: smallSz,
                      color: D.fgTertiary,
                    ),
                  ),
                  SelectableText(
                    data.irn!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: bodySz,
                      fontWeight: FontWeight.w600,
                      color: D.ink800,
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: D.warning50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FBR: ${data.fbrStatus} — not yet fiscalized',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: smallSz,
                        color: D.warning500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String l, String v, double sz, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: sz,
            fontWeight: big ? FontWeight.w700 : FontWeight.w400,
            color: big ? D.ink800 : D.fgSecondary,
          ),
        ),
        SizedBox(width: 2.w),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: sz,
              fontWeight: big ? FontWeight.w700 : FontWeight.w400,
              color: big ? D.ink800 : D.fgPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  static String _q(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
