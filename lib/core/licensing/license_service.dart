// lib/core/licensing/license_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';

class LicenseResult {
  final LicenseStatus status;
  final String? message;
  final DateTime? expiresAt;
  final int? daysRemaining;
  final PlanType? plan;

  const LicenseResult({
    required this.status,
    this.message,
    this.expiresAt,
    this.daysRemaining,
    this.plan,
  });

  bool get isAllowed =>
      status == LicenseStatus.valid || status == LicenseStatus.gracePeriod;
}

class LicenseService {
  final AppDatabase _db;
  final SharedPreferences _prefs;

  LicenseService(this._db, this._prefs);

  // ── Device fingerprint ─────────────────────────
  static Future<String> getFingerprint() async {
    final info = DeviceInfoPlugin();
    String raw = '';
    try {
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        raw =
            '${w.computerName}_${w.numberOfCores}_${w.systemMemoryInMegabytes}';
      } else if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        raw = '${m.computerName}_${m.model}';
      } else {
        raw = Platform.localHostname;
      }
    } catch (_) {
      raw = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
  }

  static Future<String> getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isWindows) return (await info.windowsInfo).computerName;
      if (Platform.isMacOS) return (await info.macOsInfo).computerName;
    } catch (_) {}
    return Platform.localHostname;
  }

  // ── Check license on startup ───────────────────
  Future<LicenseResult> checkLicense(String tenantId) async {
    if (tenantId.isEmpty) {
      return const LicenseResult(status: LicenseStatus.notActivated);
    }
    final fp = await getFingerprint();
    final now = DateTime.now();

    final rec =
        await (_db.select(_db.deviceLicenses)..where(
              (t) =>
                  t.deviceFingerprint.equals(fp) & t.tenantId.equals(tenantId),
            ))
            .getSingleOrNull();

    if (rec == null) {
      return const LicenseResult(
        status: LicenseStatus.notActivated,
        message: 'This device is not activated.',
      );
    }
    if (rec.isRevoked) {
      return const LicenseResult(
        status: LicenseStatus.revoked,
        message: 'License revoked. Contact support.',
      );
    }

    // Always enforce expiry from locally stored date (even offline)
    if (now.isAfter(rec.expiresAt)) {
      // Try online refresh first
      final online = await _tryOnlineCheck(tenantId, fp);
      if (online != null) return online;

      // Check grace period
      final graceCutoff = rec.expiresAt.add(
        const Duration(days: AppConstants.licenseGracePeriodDays),
      );
      if (now.isBefore(graceCutoff)) {
        final hoursLeft = graceCutoff.difference(now).inHours;
        return LicenseResult(
          status: LicenseStatus.gracePeriod,
          message: '⚠️ License expired. Grace period: $hoursLeft hours left.',
          expiresAt: graceCutoff,
        );
      }
      return LicenseResult(
        status: LicenseStatus.expired,
        expiresAt: rec.expiresAt,
        message: 'License expired on ${_fmt(rec.expiresAt)}. Please renew.',
      );
    }

    // Periodic online check every 24h
    final lastCheck = rec.lastOnlineCheck;
    if (lastCheck == null ||
        now.difference(lastCheck).inHours >=
            AppConstants.licenseCheckIntervalHours) {
      _tryOnlineCheck(tenantId, fp).ignore(); // non-blocking
    }

    final daysLeft = rec.expiresAt.difference(now).inDays;
    final plan = PlanType.values.firstWhere(
      (p) => p.name == rec.planType,
      orElse: () => PlanType.trial,
    );

    return LicenseResult(
      status: LicenseStatus.valid,
      expiresAt: rec.expiresAt,
      daysRemaining: daysLeft,
      plan: plan,
      message: daysLeft <= 7
          ? '⚠️ License expires in $daysLeft days. Renew soon!'
          : null,
    );
  }

  // ── Activate ────────────────────────────────────
  Future<LicenseResult> activate({
    required String tenantId,
    required String licenseKey,
  }) async {
    // ── TEMPORARY DEV BYPASS ──────────────────────
    // Remove this when Edge Functions are deployed
    if (licenseKey == 'TEST-1111-2222-3333' && tenantId == 'test-business') {
      final expiresAt = DateTime.now().add(const Duration(days: 365));
      final fp = await getFingerprint();
      final name = await getDeviceName();

      await _db
          .into(_db.deviceLicenses)
          .insertOnConflictUpdate(
            DeviceLicensesCompanion.insert(
              id: '${tenantId}_$fp',
              deviceFingerprint: fp,
              deviceName: name,
              tenantId: tenantId,
              planType: const Value('growth'),
              activatedAt: DateTime.now(),
              expiresAt: expiresAt,
              lastOnlineCheck: Value(DateTime.now()),
              isRevoked: const Value(false),
              licenseToken: 'dev-token',
            ),
          );

      return LicenseResult(
        status: LicenseStatus.valid,
        expiresAt: expiresAt,
        daysRemaining: 365,
        plan: PlanType.growth,
      );
    }
    // ── END BYPASS ────────────────────────────────
    final fp = await getFingerprint();
    final deviceName = await getDeviceName();

    try {
      final res = await http
          .post(
            Uri.parse(
              '${AppConstants.supabaseUrl}/functions/v1/activate-license',
            ),
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConstants.supabaseAnonKey,
            },
            body: jsonEncode({
              'tenant_id': tenantId,
              'license_key': licenseKey,
              'device_fingerprint': fp,
              'device_name': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 409) {
        return const LicenseResult(
          status: LicenseStatus.maxDevices,
          message: 'Maximum devices already activated for this license.',
        );
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final expiresAt = DateTime.parse(data['expires_at'] as String);
          final plan = data['plan'] as String? ?? 'trial';
          final token = data['token'] as String? ?? '';

          await _db
              .into(_db.deviceLicenses)
              .insertOnConflictUpdate(
                DeviceLicensesCompanion.insert(
                  id: '${tenantId}_$fp',
                  deviceFingerprint: fp,
                  deviceName: deviceName,
                  tenantId: tenantId,
                  planType: Value(plan),
                  activatedAt: DateTime.now(),
                  expiresAt: expiresAt,
                  lastOnlineCheck: Value(DateTime.now()),
                  isRevoked: const Value(false),
                  licenseToken: token,
                ),
              );

          final daysLeft = expiresAt.difference(DateTime.now()).inDays;
          return LicenseResult(
            status: LicenseStatus.valid,
            expiresAt: expiresAt,
            daysRemaining: daysLeft,
            plan: PlanType.values.firstWhere(
              (p) => p.name == plan,
              orElse: () => PlanType.trial,
            ),
          );
        }
        final err =
            (jsonDecode(res.body) as Map)['error'] as String? ??
            'Activation failed';
        return LicenseResult(status: LicenseStatus.notActivated, message: err);
      }
    } on SocketException {
      return const LicenseResult(
        status: LicenseStatus.notActivated,
        message: 'No internet. Please connect to activate.',
      );
    } on TimeoutException {
      return const LicenseResult(
        status: LicenseStatus.notActivated,
        message: 'Server timeout. Please try again.',
      );
    }
    return const LicenseResult(
      status: LicenseStatus.notActivated,
      message: 'Activation failed. Check your license key.',
    );
  }

  // ── Online sync ────────────────────────────────
  Future<LicenseResult?> _tryOnlineCheck(String tenantId, String fp) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.supabaseUrl}/functions/v1/check-license'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConstants.supabaseAnonKey,
            },
            body: jsonEncode({'tenant_id': tenantId, 'device_fingerprint': fp}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final expiresAt = DateTime.parse(data['expires_at'] as String);
        final isRevoked = data['is_revoked'] as bool? ?? false;
        final plan = data['plan'] as String? ?? 'trial';

        await (_db.update(_db.deviceLicenses)..where(
              (t) =>
                  t.deviceFingerprint.equals(fp) & t.tenantId.equals(tenantId),
            ))
            .write(
              DeviceLicensesCompanion(
                expiresAt: Value(expiresAt),
                isRevoked: Value(isRevoked),
                planType: Value(plan),
                lastOnlineCheck: Value(DateTime.now()),
              ),
            );

        if (isRevoked) {
          return const LicenseResult(
            status: LicenseStatus.revoked,
            message: 'License revoked by administrator.',
          );
        }
        if (DateTime.now().isAfter(expiresAt)) {
          return LicenseResult(
            status: LicenseStatus.expired,
            expiresAt: expiresAt,
            message: 'License expired. Please renew.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
