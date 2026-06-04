// lib/core/fbr/fbr_config.dart
//
// C1 — Configurable environment + endpoint config.
//
// Everything that changes between sandbox and production lives HERE and only
// here. Going live = flip `environment` to production and drop in the
// production token. No other code changes anywhere in the app.
//
// The 26-field spec (SRO 288) is still draft, so field presence is also driven
// by config (see FbrFieldFlags) — a spec change becomes a config edit, never a
// rewrite.

enum FbrEnvironment { sandbox, production }

class FbrConfig {
  final FbrEnvironment environment;

  /// Bearer token. Sandbox token while testing; production token at go-live.
  /// Stored in SharedPrefs / secure storage and injected at runtime.
  final String securityToken;

  const FbrConfig({required this.environment, required this.securityToken});

  bool get isSandbox => environment == FbrEnvironment.sandbox;

  // ── Base host ───────────────────────────────────────────
  // Per PRAL DI API spec, sandbox vs production routing is driven by the
  // token, and the validate method has an explicit `_sb` sandbox suffix.
  static const String _host = 'https://gw.fbr.gov.pk/di_data/v1/di';

  /// Real-time submission endpoint (returns the FBR invoice number / IRN).
  String get postInvoiceUrl => '$_host/postinvoicedata';

  /// Pre-submission validation endpoint. Sandbox uses the `_sb` variant so you
  /// can validate without creating a real fiscal record.
  String get validateInvoiceUrl => isSandbox
      ? '$_host/validateinvoicedata_sb'
      : '$_host/validateinvoicedata';

  Map<String, String> get headers => {
    'Authorization': 'Bearer $securityToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  FbrConfig copyWith({FbrEnvironment? environment, String? securityToken}) =>
      FbrConfig(
        environment: environment ?? this.environment,
        securityToken: securityToken ?? this.securityToken,
      );
}

/// Toggles for fields whose requirement is still settling under SRO 288.
/// Flip these as the final spec lands — no payload-builder code changes.
class FbrFieldFlags {
  final bool includeBusinessDestinationAddress;
  final bool includeProductCode;
  final bool includeSroFields; // sroScheduleNo / sroItemSerialNo
  final bool includeFurtherTax;
  final bool includeFedPayable;
  final bool sendRateAsPercentString; // "18%" vs numeric 18

  const FbrFieldFlags({
    this.includeBusinessDestinationAddress = true,
    this.includeProductCode = true,
    this.includeSroFields = true,
    this.includeFurtherTax = true,
    this.includeFedPayable = true,
    this.sendRateAsPercentString = true,
  });

  static const standard = FbrFieldFlags();
}
