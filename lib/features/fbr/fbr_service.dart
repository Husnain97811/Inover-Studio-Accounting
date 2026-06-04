// lib/features/fbr/fbr_service.dart
//
// Drift-aware FbrService (your existing service, upgraded).
// Keeps your persistence + retry-timer skeleton; routes submission through the
// C1/C2 layer so the payload matches the real PRAL DI API and sandbox/production
// is a flag, not a code change.
//
// Depends on lib/core/fbr/: fbr_config.dart, fbr_models.dart,
// fbr_payload_builder.dart, fbr_service_client.dart

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show Value, BooleanExpressionOperators, ComparableExpr;
import 'package:is_accounting/core/fbr/fbr_config.dart';
import 'package:is_accounting/core/fbr/fbr_models.dart';
import 'package:is_accounting/core/fbr/fbr_payload_builder.dart';
import 'package:is_accounting/core/fbr/fbr_service_client.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';

class FbrService {
  final AppDatabase _db;
  final SharedPreferences _prefs;
  final FbrPayloadBuilder _builder;
  Timer? _retryTimer;

  FbrService(this._db, this._prefs, {FbrPayloadBuilder? builder})
    : _builder = builder ?? const FbrPayloadBuilder();

  // ── Config sourced live from prefs (in sync with Settings) ──
  String get _token => _prefs.getString(AppConstants.keyFbrToken) ?? '';
  FbrEnvironment get _env =>
      (_prefs.getString(AppConstants.keyFbrEnv) ?? 'sandbox') == 'production'
      ? FbrEnvironment.production
      : FbrEnvironment.sandbox;
  FbrConfig get _config => FbrConfig(environment: _env, securityToken: _token);
  bool get isConfigured => _token.trim().isNotEmpty;

  /// Backward-compat: Settings card calls setToken(); now persists to prefs.
  Future<void> setToken(String token) =>
      _prefs.setString(AppConstants.keyFbrToken, token);

  Future<void> setEnvironment(FbrEnvironment env) => _prefs.setString(
    AppConstants.keyFbrEnv,
    env == FbrEnvironment.production ? 'production' : 'sandbox',
  );

  // ── Retry job ───────────────────────────────────────────
  void startRetryJob() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => retryPending(),
    );
  }

  void stop() => _retryTimer?.cancel();

  // ── Fiscalize one invoice ───────────────────────────────
  Future<void> fiscalize(String invoiceId, {String? scenarioId}) async {
    if (!isConfigured) return;

    final invoice = await (_db.select(
      _db.invoices,
    )..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    if (invoice == null) return;
    if (invoice.fbrStatus == 'verified') return; // idempotency guard

    final items = await (_db.select(
      _db.invoiceItems,
    )..where((t) => t.invoiceId.equals(invoiceId))).get();
    if (items.isEmpty) return;

    // 'submitting' is swept by retryPending() so a mid-call crash can't strand it.
    await _setStatus(invoiceId, 'submitting');

    final req = _buildRequest(invoice, items, scenarioId: scenarioId);
    final client = FbrServiceClient(config: _config, builder: _builder);
    final result = await client.postInvoice(req);
    client.dispose();

    if (result.ok && result.response?.invoiceNumber != null) {
      final r = result.response!;
      await (_db.update(
        _db.invoices,
      )..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          fbrStatus: const Value('verified'),
          usin: Value(r.invoiceNumber), // IRN
          qrCodeString: Value(r.invoiceNumber), // QR encodes IRN (C4 renders)
          fbrRawResponse: Value(jsonEncode(r.raw)), // 6-year audit
          fbrVerifiedAt: Value(DateTime.now()),
          fbrErrorMessage: const Value(null),
        ),
      );
    } else {
      final permanent = !result.isRetryable && result.response != null;
      await _fail(
        invoiceId,
        invoice.fbrRetryCount,
        result.response?.displayError ??
            result.transportError ??
            'Unknown FBR error',
        permanent: permanent,
      );
    }
  }

  // ── Build DI API request from Drift rows ────────────────
  FbrInvoiceRequest _buildRequest(
    Invoice invoice,
    List<InvoiceItem> items, {
    String? scenarioId,
  }) {
    final sellerNtn = _prefs.getString(AppConstants.keyTenantNtn) ?? '';
    final sellerName = _prefs.getString(AppConstants.keyTenantName) ?? '';
    final sellerProvince =
        _prefs.getString(AppConstants.keyTenantProvince) ?? 'Punjab';
    final sellerAddress = _prefs.getString(AppConstants.keyTenantAddress) ?? '';

    const buyerNtn = '1000000000000';
    const buyerName = 'Walk-in Customer';
    const buyerRegType = 'Unregistered';

    return FbrInvoiceRequest(
      invoiceType: 'Sale Invoice',
      invoiceDate: _fmtDate(invoice.invoiceDate),
      sellerNTNCNIC: sellerNtn,
      sellerBusinessName: sellerName,
      sellerProvince: sellerProvince,
      sellerAddress: sellerAddress,
      buyerNTNCNIC: buyerNtn,
      buyerBusinessName: buyerName,
      buyerProvince: sellerProvince,
      buyerAddress: '',
      buyerRegistrationType: buyerRegType,
      invoiceRefNo: '',
      scenarioId: scenarioId, // builder strips in production
      items: items.map((i) {
        final taxable = (i.unitPrice * i.quantity) - i.discountAmount;
        return FbrInvoiceItem(
          hsCode: i.pctCode,
          productDescription: i.description,
          rate: '${(i.taxRate ?? 18).toStringAsFixed(0)}%',
          uoM: 'Numbers, pieces, units',
          quantity: i.quantity,
          valueSalesExcludingST: taxable,
          salesTaxApplicable: i.taxAmount,
          totalValues: i.lineTotal,
          productCode: i.pctCode,
        );
      }).toList(),
    );
  }

  // ── Retry queue ─────────────────────────────────────────
  Future<void> retryPending() async {
    final pending =
        await (_db.select(_db.invoices)..where(
              (t) =>
                  t.fbrStatus.isIn(['pending', 'failed', 'submitting']) &
                  t.fbrRetryCount.isSmallerThanValue(
                    AppConstants.fbrMaxRetries,
                  ),
            ))
            .get();
    for (final inv in pending) {
      await Future.delayed(const Duration(seconds: 2));
      await fiscalize(inv.id);
    }
  }

  // ── Helpers ─────────────────────────────────────────────
  Future<void> _setStatus(String id, String status) async =>
      (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
        InvoicesCompanion(
          fbrStatus: Value(status),
          fbrSubmittedAt: Value(DateTime.now()),
        ),
      );

  Future<void> _fail(
    String id,
    int retries,
    String err, {
    bool permanent = false,
  }) async {
    await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
      InvoicesCompanion(
        fbrStatus: Value(permanent ? 'rejected' : 'failed'),
        fbrRetryCount: Value(retries + 1),
        fbrErrorMessage: Value(err),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
