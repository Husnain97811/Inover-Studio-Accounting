// lib/core/fbr/fbr_service_client.dart
//
// Pure network client for the PRAL DI API. No database, no state.
// (This is the renamed C1/C3 "FbrService" — renamed to FbrServiceClient so it
//  doesn't clash with the Drift-aware FbrService in lib/features/fbr/.)
//
// The feature-level FbrService owns DB + retry; this just does HTTP + parsing.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'fbr_config.dart';
import 'fbr_models.dart';
import 'fbr_payload_builder.dart';

class FbrResult {
  final bool ok;
  final FbrInvoiceResponse? response;
  final String? transportError;
  final int? httpStatus;

  const FbrResult({
    required this.ok,
    this.response,
    this.transportError,
    this.httpStatus,
  });

  /// Transport/availability failure (retry) vs validation rejection (fix data).
  bool get isRetryable =>
      transportError != null || (httpStatus != null && httpStatus! >= 500);
}

class FbrServiceClient {
  final FbrConfig _config;
  final FbrPayloadBuilder _builder;
  final http.Client _client;
  final Duration _timeout;

  FbrServiceClient({
    required FbrConfig config,
    FbrPayloadBuilder? builder,
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
  }) : _config = config,
       _builder = builder ?? const FbrPayloadBuilder(),
       _client = client ?? http.Client(),
       _timeout = timeout;

  bool get isConfigured => _config.securityToken.trim().isNotEmpty;

  Future<FbrResult> validateInvoice(FbrInvoiceRequest req) =>
      _send(req, _config.validateInvoiceUrl);

  Future<FbrResult> postInvoice(FbrInvoiceRequest req) =>
      _send(req, _config.postInvoiceUrl);

  Future<FbrResult> _send(FbrInvoiceRequest req, String url) async {
    if (!isConfigured) {
      return const FbrResult(
        ok: false,
        transportError: 'FBR token not configured',
      );
    }

    final payload = _builder.build(req, isSandbox: _config.isSandbox);

    try {
      final res = await _client
          .post(
            Uri.parse(url),
            headers: _config.headers,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (res.statusCode == 401 || res.statusCode == 403) {
        return FbrResult(
          ok: false,
          httpStatus: res.statusCode,
          transportError:
              'Authorization failed (${res.statusCode}). Check the FBR token in Settings.',
        );
      }
      if (res.statusCode >= 500) {
        return FbrResult(
          ok: false,
          httpStatus: res.statusCode,
          transportError: 'FBR gateway error ${res.statusCode}',
        );
      }

      final decoded = jsonDecode(res.body);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'raw': decoded};
      final parsed = FbrInvoiceResponse.fromJson(map);

      return FbrResult(
        ok: parsed.valid,
        response: parsed,
        httpStatus: res.statusCode,
      );
    } on FormatException catch (e) {
      return FbrResult(ok: false, transportError: 'Bad JSON from FBR: $e');
    } catch (e) {
      return FbrResult(ok: false, transportError: e.toString());
    }
  }

  void dispose() => _client.close();
}
