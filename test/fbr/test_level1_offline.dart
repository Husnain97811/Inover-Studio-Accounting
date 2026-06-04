// test/fbr/test_level1_offline.dart
// Run with:  flutter test test/fbr/test_level1_offline.dart
//
// LEVEL 1 — pure offline. No token, no internet. Proves the payload is
// spec-correct and that production strips scenarioId. Run this TODAY.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:is_accounting/core/fbr/fbr_dummy_data.dart';
import 'package:is_accounting/core/fbr/fbr_payload_builder.dart';

void main() {
  const builder = FbrPayloadBuilder();

  test('SN001 sandbox payload has all required header fields', () {
    final payload = builder.build(FbrDummyData.sn001(), isSandbox: true);

    const requiredHeader = [
      'invoiceType',
      'invoiceDate',
      'sellerNTNCNIC',
      'sellerBusinessName',
      'sellerProvince',
      'sellerAddress',
      'buyerNTNCNIC',
      'buyerBusinessName',
      'buyerProvince',
      'buyerAddress',
      'buyerRegistrationType',
      'invoiceRefNo',
      'items',
    ];
    for (final k in requiredHeader) {
      expect(payload.containsKey(k), true, reason: 'missing header field: $k');
    }
  });

  test('SN001 item has all required item fields', () {
    final payload = builder.build(FbrDummyData.sn001(), isSandbox: true);
    final item = (payload['items'] as List).first as Map;

    const requiredItem = [
      'hsCode',
      'productDescription',
      'rate',
      'uoM',
      'quantity',
      'valueSalesExcludingST',
      'salesTaxApplicable',
    ];
    for (final k in requiredItem) {
      expect(item.containsKey(k), true, reason: 'missing item field: $k');
    }
  });

  test('scenarioId present in SANDBOX', () {
    final payload = builder.build(FbrDummyData.sn001(), isSandbox: true);
    expect(payload['scenarioId'], 'SN001');
  });

  test('scenarioId ABSENT in PRODUCTION (critical go-live guard)', () {
    final payload = builder.build(FbrDummyData.sn001(), isSandbox: false);
    expect(
      payload.containsKey('scenarioId'),
      false,
      reason: 'scenarioId must never be sent in production',
    );
  });

  test('print the payload for eyeballing', () {
    final payload = builder.build(FbrDummyData.sn001(), isSandbox: true);
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(payload));
  });
}
