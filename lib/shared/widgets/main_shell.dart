// lib/shared/widgets/main_shell.dart
// Design: Inover Studio ERP — forest emerald sidebar + gold accents
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/licensing/license_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/loading_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    final biz = AppTheme.forBusiness(ref.watch(businessTypeProvider));
    final locale = ref.watch(localeProvider);
    final role = ref.watch(currentRoleProvider);
    final license = ref.watch(licenseProvider).value;
    final sync = ref.watch(syncStateProvider).value;
    final bizType = ref.watch(businessTypeProvider);

    return AppLoadingOverlay(
      child: Scaffold(
        backgroundColor: D.bgApp,
        body: Column(
          children: [
            // ── Topbar ───────────────────────────────
            _Topbar(sync: sync, license: license, locale: locale, biz: biz),

            // ── License warning ───────────────────────
            if (license?.message != null &&
                (license!.status == LicenseStatus.gracePeriod ||
                    (license.status == LicenseStatus.valid &&
                        (license.daysRemaining ?? 99) <= 7)))
              _LicenseBanner(message: license.message!),

            // ── Body: sidebar + main ──────────────────
            Expanded(
              child: Row(
                children: [
                  _Sidebar(
                    role: role,
                    locale: locale,
                    biz: biz,
                    bizType: bizType,
                  ),
                  // Main area with ambient blobs
                  Expanded(child: _MainArea(child: widget.child)),
                ],
              ),
            ),

            // ── Statusbar ─────────────────────────────
            _Statusbar(sync: sync, biz: biz),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  TOPBAR  — frosted glass pill, breadcrumb, search
// ─────────────────────────────────────────────────
class _Topbar extends ConsumerWidget {
  final SyncState? sync;
  final LicenseResult? license;
  final AppLocale locale;
  final BizTheme biz;
  const _Topbar({
    required this.sync,
    required this.license,
    required this.locale,
    required this.biz,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).matchedLocation;
    final crumb = _pathToCrumb(path);

    return Container(
      height: D.topbarHeight,
      decoration: BoxDecoration(
        color: D.bgSurface.withOpacity(0.85),
        border: const Border(
          bottom: BorderSide(color: Color(0x38C49A4A)),
        ), // gold 22% alpha
        boxShadow: const [
          BoxShadow(color: Color(0x08C49A4A), offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          // Breadcrumb
          Text(
            crumb,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: D.fgPrimary,
            ),
          ),
          // Search pill
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                height: 32,
                decoration: BoxDecoration(
                  color: D.bgSurface.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x4DC49A4A)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0A1A11),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: D.fgTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search invoices, products, customers…',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: D.fgTertiary,
                        ),
                      ),
                    ),
                    _KbdChip('⌘K'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right actions
          _LangToggle(locale: locale, primary: biz.primary),
          const SizedBox(width: 8),
          _TopbarAvatar(),
        ],
      ),
    );
  }

  String _pathToCrumb(String path) {
    final map = {
      '/dashboard': 'Dashboard',
      '/pos': 'Point of Sale',
      '/inventory': 'Inventory',
      '/customers': 'Customers',
      '/purchase': 'Purchase',
      '/accounts': 'Accounts',
      '/reports': 'Reports',
      '/settings': 'Settings',
    };
    for (final e in map.entries) {
      if (path.startsWith(e.key)) return e.value;
    }
    return AppConstants.appName;
  }
}

class _KbdChip extends StatelessWidget {
  final String label;
  const _KbdChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: D.bgSurface,
      borderRadius: BorderRadius.circular(3),
      border: Border(
        top: const BorderSide(color: D.borderDefault),
        left: const BorderSide(color: D.borderDefault),
        right: const BorderSide(color: D.borderDefault),
        bottom: const BorderSide(color: D.neutral300, width: 2),
      ),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 10,
        color: D.fgSecondary,
      ),
    ),
  );
}

class _LangToggle extends ConsumerWidget {
  final AppLocale locale;
  final Color primary;
  const _LangToggle({required this.locale, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => ref.read(localeProvider.notifier).toggle(),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: D.borderDefault),
          borderRadius: BorderRadius.circular(4),
          color: D.bgSurface,
        ),
        alignment: Alignment.center,
        child: Text(
          locale == AppLocale.english ? 'اردو' : 'EN',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: D.fgSecondary,
          ),
        ),
      ),
    );
  }
}

class _TopbarAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [D.brand400, D.brand700],
        ),
        border: Border.all(color: D.gold400, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x26C49A4A), blurRadius: 0, spreadRadius: 3),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'A',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  MAIN AREA  — ambient glow blobs behind glass cards
// ─────────────────────────────────────────────────
class _MainArea extends StatelessWidget {
  final Widget child;
  const _MainArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ambient blob 1 — emerald
        Positioned(
          top: 220,
          left: MediaQuery.of(context).size.width * 0.25,
          child: _Blob(380, 380, D.brand500.withOpacity(0.10)),
        ),
        // Ambient blob 2 — gold
        Positioned(
          bottom: 80,
          right: 120,
          child: _Blob(280, 280, D.gold400.withOpacity(0.08)),
        ),
        // Content
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double w, h;
  final Color color;
  const _Blob(this.w, this.h, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    // Blur effect (approximated — Flutter doesn't have CSS filter:blur on containers)
    // We use a very large border radius + reduced opacity for the blob feel
  );
}

// ─────────────────────────────────────────────────
//  SIDEBAR  — deep forest-black + gold accents
// ─────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final UserRole role;
  final AppLocale locale;
  final BizTheme biz;
  final BusinessType bizType;

  const _Sidebar({
    required this.role,
    required this.locale,
    required this.biz,
    required this.bizType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(currentUserProvider);

    return Container(
      width: D.sidebarWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1A11), Color(0xFF040E08)],
        ),
        border: Border(right: BorderSide(color: Color(0xFF040E08))),
      ),
      child: Stack(
        children: [
          // Dot grid texture
          _DotGrid(),
          // Gold right border line
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    D.gold500,
                    D.gold500,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Brand header
              _SidebarBrand(bizType: bizType),
              // Nav
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NavItem(
                        route: '/dashboard',
                        icon: Icons.dashboard_rounded,
                        labelEn: 'Dashboard',
                        labelUr: 'ڈیش بورڈ',
                        currentPath: path,
                        locale: locale,
                      ),
                      _NavItem(
                        route: '/pos',
                        icon: Icons.point_of_sale_rounded,
                        labelEn: bizType.saleLabel,
                        labelUr: 'سیل',
                        currentPath: path,
                        locale: locale,
                        trailing: _KbdSm('F1'),
                      ),
                      _NavItem(
                        route: '/inventory',
                        icon: Icons.inventory_2_rounded,
                        labelEn: bizType.productLabel,
                        labelUr: 'مال',
                        currentPath: path,
                        locale: locale,
                      ),
                      _NavItem(
                        route: '/customers',
                        icon: Icons.people_rounded,
                        labelEn: bizType.customerLabel,
                        labelUr: 'گاہک',
                        currentPath: path,
                        locale: locale,
                      ),
                      if (role.canManageProducts) ...[
                        _NavItem(
                          route: '/purchase',
                          icon: Icons.shopping_cart_rounded,
                          labelEn: 'Purchase',
                          labelUr: 'خریداری',
                          currentPath: path,
                          locale: locale,
                        ),
                      ],

                      // Insights section
                      _SidebarSectionLabel('Insights'),

                      if (role.canViewReports)
                        _NavItem(
                          route: '/reports',
                          icon: Icons.bar_chart_rounded,
                          labelEn: 'Reports',
                          labelUr: 'رپورٹ',
                          currentPath: path,
                          locale: locale,
                        ),
                      if (role.canViewAccounts)
                        _NavItem(
                          route: '/accounts',
                          icon: Icons.account_balance_rounded,
                          labelEn: 'Accounts',
                          labelUr: 'حسابات',
                          currentPath: path,
                          locale: locale,
                        ),
                    ],
                  ),
                ),
              ),
              // Footer: settings + avatar
              _SidebarFooter(
                user: user,
                onSettings: () => context.go('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: CustomPaint(painter: _DotGridPainter()));
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = D.gold400.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const spacing = 16.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SidebarBrand extends StatelessWidget {
  final BusinessType bizType;
  const _SidebarBrand({required this.bizType});

  @override
  Widget build(BuildContext context) => Container(
    height: D.topbarHeight,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x2EC49A4A))),
    ),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(colors: [D.brand400, D.brand700]),
          ),
          alignment: Alignment.center,
          child: Icon(
            BusinessTypeIconX(bizType).moduleIcon ?? Icons.store_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: D.fgOnInk,
                letterSpacing: -0.01,
              ),
            ),
            Text(
              bizType.label,
              style: const TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: D.gold300,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SidebarSectionLabel extends StatelessWidget {
  final String label;
  const _SidebarSectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
    child: Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: D.gold400,
            letterSpacing: 0.18,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x4DC49A4A), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  final String route;
  final IconData icon;
  final String labelEn;
  final String labelUr;
  final String currentPath;
  final AppLocale locale;
  final Widget? trailing;

  const _NavItem({
    required this.route,
    required this.icon,
    required this.labelEn,
    required this.labelUr,
    required this.currentPath,
    required this.locale,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentPath.startsWith(route);
    final label = locale.isRtl ? labelUr : labelEn;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => context.go(route),
          hoverColor: const Color(0x1AC49A4A),
          splashColor: const Color(0x0DC49A4A),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: isActive
                  ? const LinearGradient(
                      colors: [Color(0x2EC49A4A), Color(0x38116B43)],
                    )
                  : null,
              boxShadow: isActive
                  ? [const BoxShadow(color: Color(0x00000000))]
                  : null,
            ),
            foregroundDecoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: const Border(
                      left: BorderSide(color: D.gold400, width: 3),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? D.gold300 : const Color(0xC7F5EFD9),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? const Color(0xFFF5EFD9)
                          : const Color(0xC7F5EFD9),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KbdSm extends StatelessWidget {
  final String label;
  const _KbdSm(this.label);

  @override
  Widget build(BuildContext context) => Container(
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0x4DF5EFD9)),
      borderRadius: BorderRadius.circular(3),
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 10,
        color: Color(0x73F5EFD9),
      ),
    ),
  );
}

class _SidebarFooter extends StatelessWidget {
  final dynamic user;
  final VoidCallback onSettings;
  const _SidebarFooter({required this.user, required this.onSettings});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0x2EC49A4A))),
    ),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [D.brand400, D.brand700]),
            border: Border.all(color: D.gold400, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26C49A4A),
                blurRadius: 0,
                spreadRadius: 3,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'A',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF5EFD9),
                ),
              ),
              const Text(
                'Owner',
                style: TextStyle(
                  fontFamily: 'Instrument Serif',
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: D.gold300,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onSettings,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.settings_rounded,
              size: 15,
              color: Color(0x73F5EFD9),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────
//  STATUSBAR  — dark emerald strip at bottom
// ─────────────────────────────────────────────────
class _Statusbar extends ConsumerWidget {
  final SyncState? sync;
  final BizTheme biz;
  const _Statusbar({required this.sync, required this.biz});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = sync?.status ?? SyncStatus.idle;
    final online = status != SyncStatus.offline;
    final (dotColor, syncLabel) = switch (status) {
      SyncStatus.syncing => (D.brand400, 'Syncing…'),
      SyncStatus.offline => (D.warning500, 'Offline — sync paused'),
      SyncStatus.error => (D.danger500, 'Sync error'),
      _ => (D.brand400, 'All synced'),
    };
    final branch =
        ref.watch(prefsProvider).getString(AppConstants.keyBranchId) ?? '';
    final now = TimeOfDay.now();
    final timeStr = now.format(context);

    return Container(
      height: D.statusbarHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1A11), Color(0xFF040E08)],
        ),
        border: Border(top: BorderSide(color: Color(0x38C49A4A))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          _StatusGroup(
            children: [
              _StatusDot(dotColor),
              Text(
                syncLabel,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: Color(0xD9F5EFD9),
                  letterSpacing: 0.02,
                ),
              ),
            ],
          ),
          _StatusSep(),
          _StatusGroup(
            children: [
              Icon(
                online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 11,
                color: const Color(0x80F5EFD9),
              ),
              Text(
                online ? 'Online' : 'Offline',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: Color(0xD9F5EFD9),
                ),
              ),
            ],
          ),
          if (branch.isNotEmpty) ...[
            _StatusSep(),
            _StatusGroup(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 11,
                  color: Color(0x80F5EFD9),
                ),
                Text(
                  branch.length > 20 ? branch.substring(0, 20) : branch,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: Color(0xD9F5EFD9),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          _StatusGroup(
            children: [
              const Icon(Icons.verified_rounded, size: 11, color: D.gold400),
              const Text(
                'FBR connected',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: D.gold300,
                  letterSpacing: 0.02,
                ),
              ),
            ],
          ),
          _StatusSep(),
          Text(
            AppConstants.appVersion,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: Color(0x59F5EFD9),
            ),
          ),
          _StatusSep(),
          Text(
            timeStr,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: Color(0x8CF5EFD9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGroup extends StatelessWidget {
  final List<Widget> children;
  const _StatusGroup({required this.children});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: children.map((w) {
      final i = children.indexOf(w);
      return i < children.length - 1
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [w, const SizedBox(width: 5)],
            )
          : w;
    }).toList(),
  );
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot(this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.5),
          blurRadius: 4,
          spreadRadius: 1,
        ),
      ],
    ),
  );
}

class _StatusSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 11,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: const Color(0x3CC49A4A),
  );
}

// ─────────────────────────────────────────────────
//  LICENSE BANNER
// ─────────────────────────────────────────────────
class _LicenseBanner extends StatelessWidget {
  final String message;
  const _LicenseBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    color: D.warning50,
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: D.warning500, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: D.warning700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/license?reason=renew'),
          style: TextButton.styleFrom(
            foregroundColor: D.warning700,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 28),
          ),
          child: const Text(
            'Renew',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

// Extension to get moduleIcon on BusinessType
extension BusinessTypeIconX on BusinessType {
  IconData? get moduleIcon => switch (this) {
    BusinessType.medical => Icons.local_hospital_rounded,
    BusinessType.restaurant => Icons.restaurant_rounded,
    BusinessType.electronics => Icons.devices_rounded,
    BusinessType.bookshop => Icons.menu_book_rounded,
    BusinessType.clothing => Icons.checkroom_rounded,
    BusinessType.distribution => Icons.local_shipping_rounded,
    _ => Icons.store_rounded,
  };
}
