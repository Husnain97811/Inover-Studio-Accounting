// test/fbr/test_level1_qr.dart
// Run: flutter test test/fbr/test_level1_qr.dart
// LEVEL 1 (offline) for C4 — proves QR content + render-gating logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:is_accounting/core/fbr/fbr_qr_builder.dart';

void main() {
  test('fromIrn trims and returns the IRN', () {
    expect(FbrQrData.fromIrn('  7000007DI123  '), '7000007DI123');
  });

  test('canRender false for null/empty, true for real IRN', () {
    expect(FbrQrData.canRender(null), false);
    expect(FbrQrData.canRender(''), false);
    expect(FbrQrData.canRender('   '), false);
    expect(FbrQrData.canRender('7000007DI123'), true);
  });

  test('summary packs pipe-delimited fields in order', () {
    final s = FbrQrData.summary(
      irn: '7000007DI123',
      invoiceNumber: 'INV-0001',
      date: DateTime(2026, 6, 2),
      total: 1180,
      tax: 180,
    );
    expect(s, '7000007DI123|INV-0001|2026-06-02|1180.00|180.00');
  });
}
