// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart' hide SemColor;
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../core/licensing/license_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biz = AppTheme.forBusiness(ref.watch(businessTypeProvider));
    final bizType = ref.watch(businessTypeProvider);
    final locale = ref.watch(localeProvider);
    final role = ref.watch(currentRoleProvider);
    final license = ref.watch(licenseProvider).value;
    final user = Supabase.instance.client.auth.currentUser;
    final tenantId = ref.watch(currentTenantIdProvider);
    final branchId = ref.watch(currentBranchIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: locale.isRtl ? 'ترتیبات' : 'Settings',
            subtitle: 'App configuration & account',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── ACCOUNT SECTION ──────────────────────────
                  _SectionTitle('Account'),
                  _SettingsCard(
                    children: [
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user?.email ?? '—',
                      ),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: role.label,
                        valueColor: _roleColor(role),
                      ),
                      _InfoRow(
                        icon: Icons.store_outlined,
                        label: 'Business ID',
                        value: tenantId.isEmpty ? 'Not set' : tenantId,
                        mono: true,
                      ),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Branch ID',
                        value: branchId.isEmpty ? 'Not set' : branchId,
                        mono: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── LICENSE SECTION ───────────────────────────
                  _SectionTitle('License'),
                  _SettingsCard(
                    children: [
                      _InfoRow(
                        icon: Icons.verified_outlined,
                        label: 'Status',
                        value: license == null
                            ? 'Checking…'
                            : _licenseStatusLabel(license.status),
                        valueColor: license == null
                            ? null
                            : _licenseStatusColor(license.status),
                      ),
                      if (license?.plan != null)
                        _InfoRow(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Plan',
                          value: license!.plan!.name.toUpperCase(),
                        ),
                      if (license?.expiresAt != null)
                        _InfoRow(
                          icon: Icons.event_outlined,
                          label: 'Expires',
                          value: Fmt.date(license!.expiresAt!),
                          valueColor: (license.daysRemaining ?? 99) <= 7
                              ? SemColor.warning
                              : null,
                        ),
                      if (license?.daysRemaining != null &&
                          license!.daysRemaining! <= 30)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InfoBanner(
                            message:
                                'Your license expires in '
                                '${license.daysRemaining} days. '
                                'Contact support to renew.',
                            color: (license.daysRemaining ?? 99) <= 7
                                ? SemColor.error
                                : SemColor.warning,
                            icon: Icons.warning_rounded,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── APPEARANCE SECTION ────────────────────────
                  _SectionTitle('Appearance'),
                  _SettingsCard(
                    children: [
                      // Language toggle
                      _ActionRow(
                        icon: Icons.translate_rounded,
                        label: 'Language',
                        value: locale == AppLocale.english ? 'English' : 'اردو',
                        onTap: () => ref.read(localeProvider.notifier).toggle(),
                        trailing: _ToggleChip(
                          options: const ['EN', 'اردو'],
                          selected: locale == AppLocale.english ? 0 : 1,
                          onChanged: (_) =>
                              ref.read(localeProvider.notifier).toggle(),
                        ),
                      ),

                      // Business type
                      _ActionRow(
                        icon: Icons.store_rounded,
                        label: 'Business Type',
                        value: '${bizType.emoji} ${bizType.label}',
                        onTap: () => _showBusinessTypeDialog(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── APP INFO SECTION ──────────────────────────
                  _SectionTitle('App Info'),
                  _SettingsCard(
                    children: [
                      _InfoRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Version',
                        value: AppConstants.appVersion,
                      ),
                      _InfoRow(
                        icon: Icons.apps_rounded,
                        label: 'App Name',
                        value: AppConstants.appName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── LOGOUT BUTTON ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: SemColor.error,
                        size: 18,
                      ),
                      label: Text(
                        locale.isRtl ? 'لاگ آؤٹ' : 'Sign Out',
                        style: const TextStyle(
                          color: SemColor.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: SemColor.error,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Centered version tag
                  Center(
                    child: Text(
                      '${AppConstants.appName} v${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout confirmation ───────────────────────────────
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Sign Out?',
      message:
          'You will be signed out of IS Accounting. '
          'All local data stays on this device.',
      confirmLabel: 'Sign Out',
      confirmColor: SemColor.error,
    );
    if (!ok || !context.mounted) return;

    try {
      // Clear SharedPreferences session data
      final prefs = ref.read(prefsProvider);
      await prefs.remove(AppConstants.keyUserRole);
      await prefs.remove(AppConstants.keyBranchId);
      // Keep tenant_id and business_type so setup isn't repeated
      // But clear if you want full reset: await prefs.clear();

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Router's _RouterNotifier listens to onAuthStateChange
      // and will automatically redirect to /login
    } catch (e) {
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  // ── Business type dialog ──────────────────────────────
  void _showBusinessTypeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _BusinessTypeDialog(
        current: ref.read(businessTypeProvider),
        onSelect: (t) {
          ref.read(businessTypeProvider.notifier).set(t);
          Navigator.pop(context);
          AppErrorHandler.showSuccess(context, 'Theme updated to ${t.label}');
        },
      ),
    );
  }

  Color _roleColor(UserRole role) => switch (role) {
    UserRole.owner => SemColor.warning,
    UserRole.manager => SemColor.info,
    UserRole.accountant => Colors.purple,
    UserRole.cashier => SemColor.success,
    UserRole.viewer => Colors.grey,
  };

  String _licenseStatusLabel(LicenseStatus s) => switch (s) {
    LicenseStatus.valid => 'Active ✓',
    LicenseStatus.gracePeriod => 'Grace Period',
    LicenseStatus.expired => 'Expired',
    LicenseStatus.revoked => 'Revoked',
    LicenseStatus.maxDevices => 'Max Devices',
    LicenseStatus.notActivated => 'Not Activated',
    _ => 'Unknown',
  };

  Color _licenseStatusColor(LicenseStatus s) => switch (s) {
    LicenseStatus.valid => SemColor.success,
    LicenseStatus.gracePeriod => SemColor.warning,
    LicenseStatus.expired => SemColor.error,
    LicenseStatus.revoked => SemColor.error,
    _ => Colors.grey,
  };
}

// ─────────────────────────────────────────────────
//  SECTION TITLE
// ─────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.12,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  SETTINGS CARD  (groups rows together)
// ─────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  INFO ROW  (read-only display)
// ─────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: t.colorScheme.onSurface.withOpacity(0.45),
          ),
          const SizedBox(width: 14),
          Text(label, style: t.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              color: valueColor ?? t.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  ACTION ROW  (tappable)
// ─────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: t.colorScheme.onSurface.withOpacity(0.45),
            ),
            const SizedBox(width: 14),
            Text(label, style: t.textTheme.bodyMedium),
            const Spacer(),
            if (trailing != null)
              trailing!
            else if (value != null) ...[
              Text(
                value!,
                style: TextStyle(fontSize: 13, color: t.colorScheme.onSurface),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: t.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  TOGGLE CHIP
// ─────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final List<String> options;
  final int selected;
  final void Function(int) onChanged;

  const _ToggleChip({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? t.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.white
                      : t.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  BUSINESS TYPE DIALOG
// ─────────────────────────────────────────────────
class _BusinessTypeDialog extends StatelessWidget {
  final BusinessType current;
  final void Function(BusinessType) onSelect;

  const _BusinessTypeDialog({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dialog(
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Business Type', style: t.textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                'This changes the app theme and terminology.',
                style: t.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: BusinessType.values.map((bt) {
                  final sel = bt == current;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(bt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? t.colorScheme.primary
                              : t.colorScheme.outline,
                          width: sel ? 2 : 1,
                        ),
                        color: sel
                            ? t.colorScheme.primary.withOpacity(0.08)
                            : t.colorScheme.surface,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(bt.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            bt.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? t.colorScheme.primary
                                  : t.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
