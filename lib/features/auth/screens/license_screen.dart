// lib/features/auth/screens/license_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/licensing/license_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class LicenseScreen extends ConsumerStatefulWidget {
  final String? reason;
  const LicenseScreen({super.key, this.reason});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  final _tenantCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final result = await AppErrorHandler.guard<LicenseResult>(
      ref: ref,
      context: context,
      message: 'Activating license…',
      action: () => ref
          .read(licenseServiceProvider)
          .activate(
            tenantId: _tenantCtrl.text.trim(),
            licenseKey: _keyCtrl.text.trim(),
          ),
    );

    if (result == null) return;

    if (result.isAllowed) {
      await ref
          .read(prefsProvider)
          .setString(AppConstants.keyTenantId, _tenantCtrl.text.trim());
      ref.invalidate(licenseProvider);
      if (mounted) context.go('/setup');
    } else {
      setState(() => _error = result.message ?? 'Activation failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isExpired = widget.reason != null;

    return Scaffold(
      body: Row(
        children: [
          // ── Branding panel ──────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
                ),
              ),
              padding: const EdgeInsets.all(52),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🇵🇰', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pakistan\'s Offline-First ERP.\nFBR Ready · Urdu Support · Works Without Internet.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _Feature(
                    Icons.wifi_off_rounded,
                    '100% Offline — works during load shedding',
                  ),
                  const SizedBox(height: 12),
                  _Feature(
                    Icons.receipt_long_rounded,
                    'FBR POS — USIN & QR auto-generated',
                  ),
                  const SizedBox(height: 12),
                  _Feature(
                    Icons.translate_rounded,
                    'Urdu / English — toggle anytime',
                  ),
                  const SizedBox(height: 12),
                  _Feature(
                    Icons.security_rounded,
                    'Device-locked license — your data stays yours',
                  ),
                ],
              ),
            ),
          ),

          // ── Form panel ──────────────────────────────
          Expanded(
            flex: 4,
            child: Center(
              child: SizedBox(
                width: 380,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isExpired)
                        InfoBanner(
                          message:
                              'Your license has expired. Enter a valid key to continue.',
                          color: SemColor.error,
                          icon: Icons.warning_rounded,
                        ),
                      if (isExpired) const SizedBox(height: 20),

                      Text(
                        isExpired ? 'Renew License' : 'Activate IS Accounting',
                        style: t.textTheme.displayMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your Business ID and License Key.',
                        style: t.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),

                      ErpField(
                        label: 'Business ID',
                        hint: 'e.g. ahmed-traders',
                        controller: _tenantCtrl,
                        required: true,
                        prefix: const Icon(Icons.store_rounded, size: 18),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      ErpField(
                        label: 'License Key',
                        hint: 'XXXX-XXXX-XXXX-XXXX',
                        controller: _keyCtrl,
                        required: true,
                        prefix: const Icon(Icons.vpn_key_rounded, size: 18),
                        validator: (v) => (v == null || v.trim().length < 8)
                            ? 'Enter a valid license key'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      if (_error != null) ...[
                        InfoBanner(
                          message: _error!,
                          color: SemColor.error,
                          icon: Icons.error_outline_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],

                      ElevatedButton.icon(
                        onPressed: _activate,
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: Text(isExpired ? 'Renew License' : 'Activate'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Need a license? WhatsApp: +92-300-PAKBIZ',
                          style: t.textTheme.bodyMedium!.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: SemColor.success, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    ],
  );
}
