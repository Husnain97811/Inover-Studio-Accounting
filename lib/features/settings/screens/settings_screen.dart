// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

// ─── Lightweight data bundle loaded once ─────────────────
class _SettingsData {
  final Tenant? tenant;
  final Branche? branch;
  final String fbrToken;
  final String planType;

  const _SettingsData({
    required this.tenant,
    required this.branch,
    required this.fbrToken,
    required this.planType,
  });

  bool get isPremium => planType == 'advanced-premium';
}

// ─── Single FutureProvider — result is cached by Riverpod ─
final _settingsDataProvider = FutureProvider.autoDispose<_SettingsData>((
  ref,
) async {
  final db = ref.read(databaseProvider); // read, not watch — no subscription
  final prefs = ref.read(prefsProvider);
  final tenantId = ref.read(currentTenantIdProvider);
  final branchId = ref.read(currentBranchIdProvider);

  // Three queries run in parallel
  final results = await Future.wait([
    (db.select(
      db.tenants,
    )..where((t) => t.id.equals(tenantId))).getSingleOrNull(),
    (db.select(
      db.branches,
    )..where((t) => t.id.equals(branchId))).getSingleOrNull(),
    (db.select(
      db.deviceLicenses,
    )..where((t) => t.tenantId.equals(tenantId))).getSingleOrNull(),
  ]);

  final tenant = results[0] as Tenant?;
  final branch = results[1] as Branche?;
  final license = results[2] as DeviceLicense?;

  return _SettingsData(
    tenant: tenant,
    branch: branch,
    fbrToken: prefs.getString(AppConstants.keyFbrToken) ?? '',
    planType: license?.planType ?? 'trial',
  );
});

// ─── Screen ───────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Controllers created once, never recreated
  final _bizNameCtrl = TextEditingController();
  final _ntnCtrl = TextEditingController();
  final _strnCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _fbrTokenCtrl = TextEditingController();
  final _fbrPosIdCtrl = TextEditingController();

  bool _fbrTokenVisible = false;
  bool _controllersSeeded = false; // seed controllers exactly once

  void _seedControllers(_SettingsData data) {
    if (_controllersSeeded) return;
    _controllersSeeded = true;
    if (data.tenant != null) {
      _bizNameCtrl.text = data.tenant!.name;
      _ntnCtrl.text = data.tenant!.ntn;
      _strnCtrl.text = data.tenant!.strn ?? '';
      _addressCtrl.text = data.tenant!.address ?? '';
      _cityCtrl.text = data.tenant!.city ?? '';
    }
    if (data.branch != null) {
      _fbrPosIdCtrl.text = data.branch!.fbrPosId ?? '';
    }
    _fbrTokenCtrl.text = data.fbrToken;
  }

  @override
  void dispose() {
    _bizNameCtrl.dispose();
    _ntnCtrl.dispose();
    _strnCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _fbrTokenCtrl.dispose();
    _fbrPosIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBusinessProfile() async {
    final tenantId = ref.read(currentTenantIdProvider);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      successMessage: 'Business profile saved',
      action: () async {
        final db = ref.read(databaseProvider);
        await (db.update(
          db.tenants,
        )..where((t) => t.id.equals(tenantId))).write(
          TenantsCompanion(
            name: Value(_bizNameCtrl.text.trim()),
            ntn: Value(_ntnCtrl.text.trim()),
            strn: Value(
              _strnCtrl.text.trim().isEmpty ? null : _strnCtrl.text.trim(),
            ),
            address: Value(
              _addressCtrl.text.trim().isEmpty
                  ? null
                  : _addressCtrl.text.trim(),
            ),
            city: Value(
              _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
            ),
            updatedAt: Value(ts),
          ),
        );
        ref
            .read(syncEngineProvider)
            .enqueue(
              entityType: 'tenants',
              entityId: tenantId,
              operation: 'update',
              payload: {
                'id': tenantId,
                'name': _bizNameCtrl.text.trim(),
                'updated_at': ts,
              },
            );
      },
    );
  }

  Future<void> _saveFbrSettings() async {
    final branchId = ref.read(currentBranchIdProvider);
    final ts = DateTime.now().millisecondsSinceEpoch;
    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      successMessage: 'FBR settings saved',
      action: () async {
        final db = ref.read(databaseProvider);
        final prefs = ref.read(prefsProvider);
        final token = _fbrTokenCtrl.text.trim();
        await prefs.setString(AppConstants.keyFbrToken, token);
        ref.read(fbrServiceProvider).setToken(token);
        await (db.update(
          db.branches,
        )..where((t) => t.id.equals(branchId))).write(
          BranchesCompanion(
            fbrPosId: Value(
              _fbrPosIdCtrl.text.trim().isEmpty
                  ? null
                  : _fbrPosIdCtrl.text.trim(),
            ),
            updatedAt: Value(ts),
          ),
        );
        ref
            .read(syncEngineProvider)
            .enqueue(
              entityType: 'branches',
              entityId: branchId,
              operation: 'update',
              payload: {
                'id': branchId,
                'fbr_pos_id': _fbrPosIdCtrl.text.trim(),
                'updated_at': ts,
              },
            );
      },
    );
  }

  Future<void> _signOut() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Sign Out',
      message:
          'You will be returned to the login screen. Any unsynced data will be preserved locally.',
      confirmLabel: 'Sign Out',
      confirmColor: D.danger500,
    );
    if (!confirmed) return;
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Watch only what changes the UI — locale and bizType are cheap StateProviders
    final locale = ref.watch(localeProvider);
    final bizType = ref.watch(businessTypeProvider);
    final snapshot = ref.watch(_settingsDataProvider);

    return Scaffold(
      backgroundColor: D.bgApp,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'Configuration',
            title: 'Settings',
            subtitle: 'Business profile, FBR fiscalization, and preferences',
          ),
          Expanded(
            child: snapshot.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: D.gold400),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error loading settings: $e',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: D.danger500,
                  ),
                ),
              ),
              data: (data) {
                // Seed controllers on first data arrival — no setState needed
                _seedControllers(data);
                return _SettingsBody(
                  data: data,
                  locale: locale,
                  bizType: bizType,
                  bizNameCtrl: _bizNameCtrl,
                  ntnCtrl: _ntnCtrl,
                  strnCtrl: _strnCtrl,
                  addressCtrl: _addressCtrl,
                  cityCtrl: _cityCtrl,
                  fbrTokenCtrl: _fbrTokenCtrl,
                  fbrPosIdCtrl: _fbrPosIdCtrl,
                  fbrTokenVisible: _fbrTokenVisible,
                  onToggleVisibility: () =>
                      setState(() => _fbrTokenVisible = !_fbrTokenVisible),
                  onSaveProfile: _saveBusinessProfile,
                  onSaveFbr: _saveFbrSettings,
                  onSignOut: _signOut,
                  onLocaleToggle: () =>
                      ref.read(localeProvider.notifier).toggle(),
                  onBizTypeChange: (t) =>
                      ref.read(businessTypeProvider.notifier).set(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pure StatelessWidget body — zero state, zero rebuilds ──
class _SettingsBody extends StatelessWidget {
  final _SettingsData data;
  final AppLocale locale;
  final BusinessType bizType;
  final TextEditingController bizNameCtrl,
      ntnCtrl,
      strnCtrl,
      addressCtrl,
      cityCtrl;
  final TextEditingController fbrTokenCtrl, fbrPosIdCtrl;
  final bool fbrTokenVisible;
  final VoidCallback onToggleVisibility,
      onSaveProfile,
      onSaveFbr,
      onSignOut,
      onLocaleToggle;
  final void Function(BusinessType) onBizTypeChange;

  const _SettingsBody({
    required this.data,
    required this.locale,
    required this.bizType,
    required this.bizNameCtrl,
    required this.ntnCtrl,
    required this.strnCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.fbrTokenCtrl,
    required this.fbrPosIdCtrl,
    required this.fbrTokenVisible,
    required this.onToggleVisibility,
    required this.onSaveProfile,
    required this.onSaveFbr,
    required this.onSignOut,
    required this.onLocaleToggle,
    required this.onBizTypeChange,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _BusinessProfileCard(
                  nameCtrl: bizNameCtrl,
                  ntnCtrl: ntnCtrl,
                  strnCtrl: strnCtrl,
                  addressCtrl: addressCtrl,
                  cityCtrl: cityCtrl,
                  onSave: onSaveProfile,
                ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04),
                SizedBox(height: 2.h),
                _FbrCard(
                      tokenCtrl: fbrTokenCtrl,
                      posIdCtrl: fbrPosIdCtrl,
                      tokenVisible: fbrTokenVisible,
                      isPremium: data.isPremium,
                      onToggleVisibility: onToggleVisibility,
                      onSave: data.isPremium ? onSaveFbr : null,
                    )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 80.ms)
                    .slideX(begin: -0.04),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _PreferencesCard(
                      locale: locale,
                      bizType: bizType,
                      isPremium: data.isPremium,
                      onLocaleToggle: onLocaleToggle,
                      onBizTypeChange: onBizTypeChange,
                    )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 120.ms)
                    .slideX(begin: 0.04),
                SizedBox(height: 2.h),
                _SessionCard(onSignOut: onSignOut)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 160.ms)
                    .slideX(begin: 0.04),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Business Profile Card ────────────────────────────────
class _BusinessProfileCard extends StatelessWidget {
  final TextEditingController nameCtrl,
      ntnCtrl,
      strnCtrl,
      addressCtrl,
      cityCtrl;
  final VoidCallback onSave;
  const _BusinessProfileCard({
    required this.nameCtrl,
    required this.ntnCtrl,
    required this.strnCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ErpCard(
      goldRule: true,
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(
            icon: Icons.store_rounded,
            label: 'Business Profile',
          ),
          SizedBox(height: 1.5.h),
          ErpField(
            label: 'Business Name',
            controller: nameCtrl,
            required: true,
          ),
          SizedBox(height: 1.2.h),
          Row(
            children: [
              Expanded(
                child: ErpField(
                  label: 'NTN',
                  hint: '0000000-0',
                  controller: ntnCtrl,
                ),
              ),
              SizedBox(width: 1.5.w),
              Expanded(
                child: ErpField(
                  label: 'STRN',
                  hint: 'Optional',
                  controller: strnCtrl,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          ErpField(label: 'Address', controller: addressCtrl, maxLines: 2),
          SizedBox(height: 1.2.h),
          ErpField(label: 'City', controller: cityCtrl),
          SizedBox(height: 1.8.h),
          Align(
            alignment: Alignment.centerRight,
            child: GoldButton(
              label: 'Save Profile',
              icon: Icons.check_rounded,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FBR Card ─────────────────────────────────────────────
class _FbrCard extends StatelessWidget {
  final TextEditingController tokenCtrl, posIdCtrl;
  final bool tokenVisible, isPremium;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onSave;

  const _FbrCard({
    required this.tokenCtrl,
    required this.posIdCtrl,
    required this.tokenVisible,
    required this.isPremium,
    required this.onToggleVisibility,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ErpCard(
      goldCorner: true,
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionLabel(
                icon: Icons.receipt_long_rounded,
                label: 'FBR Fiscalization',
              ),
              const Spacer(),
              _PlanBadge(planType: isPremium ? 'advanced-premium' : 'locked'),
            ],
          ),
          SizedBox(height: 0.8.h),
          InfoBanner(
            message: isPremium
                ? 'FBR POS integration requires a valid PRAL token and POS ID for this branch.'
                : 'FBR integration is available on the Advanced Premium plan. Upgrade to enable.',
            icon: isPremium
                ? Icons.info_outline_rounded
                : Icons.lock_outline_rounded,
            color: isPremium ? D.info500 : D.warning500,
            bgColor: isPremium ? D.info50 : D.warning50,
          ),
          SizedBox(height: 1.5.h),
          ErpField(
            label: 'FBR API Token',
            hint: isPremium ? 'Paste your PRAL token here' : '—',
            controller: tokenCtrl,
            readOnly: !isPremium,
            obscureText: isPremium && !tokenVisible,
            suffix: isPremium
                ? IconButton(
                    icon: Icon(
                      tokenVisible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 16,
                      color: D.fgTertiary,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : const Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: D.fgTertiary,
                  ),
          ),
          SizedBox(height: 1.2.h),
          ErpField(
            label: 'FBR POS ID (this branch)',
            hint: isPremium ? 'e.g. POS-12345' : '—',
            controller: posIdCtrl,
            readOnly: !isPremium,
          ),
          if (isPremium) ...[
            SizedBox(height: 1.8.h),
            Align(
              alignment: Alignment.centerRight,
              child: GoldButton(
                label: 'Save FBR Settings',
                icon: Icons.check_rounded,
                onPressed: onSave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Preferences Card ─────────────────────────────────────
class _PreferencesCard extends StatelessWidget {
  final AppLocale locale;
  final BusinessType bizType;
  final bool isPremium;
  final VoidCallback onLocaleToggle;
  final void Function(BusinessType) onBizTypeChange;

  const _PreferencesCard({
    required this.locale,
    required this.bizType,
    required this.isPremium,
    required this.onLocaleToggle,
    required this.onBizTypeChange,
  });

  @override
  Widget build(BuildContext context) {
    return ErpCard(
      goldRule: true,
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(icon: Icons.tune_rounded, label: 'Preferences'),
          SizedBox(height: 1.5.h),

          // Language — always editable
          _SettingRow(
            label: 'Interface Language',
            sub: 'زبان',
            child: GestureDetector(
              onTap: onLocaleToggle,
              child: AnimatedContainer(
                duration: 200.ms,
                width: 100,
                height: 32,
                decoration: BoxDecoration(
                  color: locale == AppLocale.urdu ? D.gold50 : D.bgCream,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: D.borderGold),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locale == AppLocale.urdu ? 'اردو' : 'English',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: D.gold600,
                      ),
                    ),
                    SizedBox(width: 0.4.w),
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 14,
                      color: D.gold500,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 24, color: D.borderSubtle),

          // Business type — premium only
          Row(
            children: [
              Text(
                'Business Type',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: D.fgSecondary,
                ),
              ),
              SizedBox(width: 0.6.w),
              _PlanBadge(planType: isPremium ? 'advanced-premium' : 'locked'),
            ],
          ),
          SizedBox(height: 0.8.h),

          if (!isPremium) ...[
            // Read-only chip showing current type
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: D.bgCream,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: D.borderDefault),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: D.fgTertiary,
                  ),
                  SizedBox(width: 0.4.w),
                  Text(
                    bizType.name[0].toUpperCase() + bizType.name.substring(1),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: D.fgTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              'Upgrade to Advanced Premium to change your business type.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.sp,
                color: D.fgTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else
            Wrap(
              spacing: 0.6.w,
              runSpacing: 0.6.h,
              children: BusinessType.values.map((t) {
                final selected = bizType == t;
                return GestureDetector(
                  onTap: () => onBizTypeChange(t),
                  child: AnimatedContainer(
                    duration: 180.ms,
                    padding: EdgeInsets.symmetric(
                      horizontal: 1.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? D.gold50 : D.bgSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: selected ? D.gold400 : D.borderDefault,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      t.name[0].toUpperCase() + t.name.substring(1),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.sp,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected ? D.gold600 : D.fgSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Session Card ──────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final VoidCallback onSignOut;
  const _SessionCard({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ErpCard(
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(icon: Icons.security_rounded, label: 'Session'),
          SizedBox(height: 1.5.h),
          const InfoBanner(
            message:
                'Signing out will not delete local data. Re-login to resume cloud sync.',
            icon: Icons.lock_outline_rounded,
            color: D.warning500,
            bgColor: D.warning50,
          ),
          SizedBox(height: 1.5.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 15),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: D.danger50,
                foregroundColor: D.danger700,
                elevation: 0,
                side: const BorderSide(color: D.danger500),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan Badge — shows actual plan name ──────────────────
class _PlanBadge extends StatelessWidget {
  final String
  planType; // raw value from DB e.g. 'trial', 'advanced-premium', 'locked'
  const _PlanBadge({required this.planType});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, bg, border) = switch (planType) {
      'advanced-premium' => (
        'Advanced Premium',
        Icons.workspace_premium_rounded,
        D.gold600,
        D.gold50,
        D.gold200,
      ),
      'professional' => (
        'Professional',
        Icons.star_rounded,
        D.brand600,
        D.brand50,
        D.brand100,
      ),
      'locked' => (
        'Premium Only',
        Icons.lock_outline_rounded,
        D.fgTertiary,
        D.neutral100,
        D.borderDefault,
      ),
      _ => (
        // trial / starter / anything else
        planType[0].toUpperCase() + planType.substring(1),
        Icons.info_outline_rounded,
        D.neutral600, D.neutral100, D.borderDefault,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers (all const-constructible) ─────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: D.gold50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: D.borderGold),
          ),
          child: Icon(icon, size: 14, color: D.gold600),
        ),
        SizedBox(width: 0.8.w),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: D.fgPrimary,
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String? sub;
  final Widget child;
  const _SettingRow({required this.label, this.sub, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: D.fgPrimary,
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.sp,
                    color: D.fgTertiary,
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
