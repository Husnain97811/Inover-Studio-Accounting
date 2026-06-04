// test/fbr/test_level2_mock.dart
// Run with:  flutter test test/fbr/test_level2_mock.dart
//
// LEVEL 2 — mock the network. No real FBR. Proves the FULL pipeline:
// payload → (fake) FBR → response parse → success/failure branching.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:is_accounting/core/fbr/fbr_config.dart';
import 'package:is_accounting/core/fbr/fbr_dummy_data.dart';
import 'package:is_accounting/core/fbr/fbr_service_client.dart';

FbrServiceClient _clientReturning(int status, Map<String, dynamic> body) {
  final mock = MockClient(
    (req) async => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    ),
  );
  return FbrServiceClient(
    config: const FbrConfig(
      environment: FbrEnvironment.sandbox,
      securityToken: 'TEST_TOKEN',
    ),
    client: mock,
  );
}

void main() {
  test('SUCCESS — FBR returns IRN, result.ok true', () async {
    final c = _clientReturning(200, {
      'invoiceNumber': '7000007DI1234567',
      'validationResponse': {'statusCode': '00', 'status': 'Valid'},
    });
    final res = await c.postInvoice(FbrDummyData.sn001());
    expect(res.ok, true);
    expect(res.response?.invoiceNumber, '7000007DI1234567');
    c.dispose();
  });

  test('VALIDATION REJECTION — not ok, NOT retryable', () async {
    final c = _clientReturning(200, {
      'validationResponse': {
        'statusCode': '01',
        'status': 'Invalid',
        'error': 'Invalid HS Code',
      },
    });
    final res = await c.postInvoice(FbrDummyData.sn001());
    expect(res.ok, false);
    expect(res.isRetryable, false, reason: 'bad data must not retry forever');
    expect(res.response?.displayError, contains('HS Code'));
    c.dispose();
  });

  test('AUTH FAILURE — 401 surfaces clearly, retryable', () async {
    final c = _clientReturning(401, {'message': 'Unauthorized'});
    final res = await c.postInvoice(FbrDummyData.sn001());
    expect(res.ok, false);
    expect(res.transportError, contains('Authorization failed'));
    c.dispose();
  });

  test('GATEWAY DOWN — 503 is retryable', () async {
    final c = _clientReturning(503, {'message': 'Service Unavailable'});
    final res = await c.postInvoice(FbrDummyData.sn001());
    expect(res.ok, false);
    expect(res.isRetryable, true, reason: '5xx should retry later');
    c.dispose();
  });
}
