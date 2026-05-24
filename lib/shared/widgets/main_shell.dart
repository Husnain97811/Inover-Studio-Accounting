// lib/shared/widgets/main_shell.dart
// Design Philosophy: "Polished Obsidian — Gilded"
// Dark mineral surfaces with dominant gold veins and crystalline gold highlights.
// Typography: Instrument Serif (display), Cabinet Grotesk (body), JetBrains Mono (data)
// Spatial: Asymmetric, layered, gold structural accents.
// Anthropic Frontend-Design Skill applied:
// - Distinctive fonts (no Inter/Roboto/Arial)
// - Dominant dark palette with sharp gold accents, minimal green
// - Atmospheric depth via grain texture, dramatic shadows, layered glass
// - Staggered motion reveals for navigation
// - Grid-breaking spatial composition

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

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
        body: Stack(
          children: [
            // ── Global grain texture overlay ──────────
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: CustomPaint(painter: _GrainTexturePainter()),
              ),
            ),

            // ── Main layout ────────────────────────────
            Column(
              children: [
                _Topbar(sync: sync, license: license, locale: locale, biz: biz),

                if (license?.message != null &&
                    (license!.status == LicenseStatus.gracePeriod ||
                        (license.status == LicenseStatus.valid &&
                            (license.daysRemaining ?? 99) <= 7)))
                  _LicenseBanner(message: license.message!),

                Expanded(
                  child: Row(
                    children: [
                      _Sidebar(
                        role: role,
                        locale: locale,
                        biz: biz,
                        bizType: bizType,
                      ),
                      Expanded(child: _MainArea(child: widget.child)),
                    ],
                  ),
                ),

                _Statusbar(sync: sync, biz: biz),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  GRAIN TEXTURE PAINTER
// ─────────────────────────────────────────────────
class _GrainTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = _PseudoRandom(42);
    final paint = Paint()..color = Colors.white.withOpacity(0.5);
    for (double y = 0; y < size.height; y += 2.0) {
      for (double x = 0; x < size.width; x += 2.0) {
        if (rng.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(x + rng.nextDouble(), y + rng.nextDouble(), 1, 1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PseudoRandom {
  int _seed;
  _PseudoRandom(this._seed);
  double nextDouble() {
    _seed = (_seed * 16807) % 2147483647;
    return _seed / 2147483647;
  }

  bool nextBool() => nextDouble() > 0.5;
}

// ─────────────────────────────────────────────────
//  TOPBAR — Dark steel with gold edge
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
      height: 7.5.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1A13), Color(0xFF0A1410)],
        ),
        border: Border(
          bottom: BorderSide(color: D.gold400.withOpacity(0.35), width: 0.12.h),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: Offset(0, 0.3.h),
            blurRadius: 0.8.h,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 2.5.w),
      child: Row(
        children: [
          Text(
            crumb,
            style: TextStyle(
              fontFamily: 'Instrument Serif',
              fontSize: 15.sp,
              fontStyle: FontStyle.italic,
              color: D.gold300.withOpacity(0.85),
              letterSpacing: 0.01,
            ),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 55.w),
                height: 3.8.h,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(0.5.h),
                  border: Border.all(
                    color: D.gold400.withOpacity(0.18),
                    width: 0.1.h,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 14.sp,
                      color: D.fgTertiary.withOpacity(0.5),
                    ),
                    SizedBox(width: 1.w),
                    Expanded(
                      child: Text(
                        'Search invoices, products, customers…',
                        style: TextStyle(
                          fontFamily: 'Cabinet Grotesk',
                          fontSize: 10.5.sp,
                          color: D.brand50,
                        ),
                      ),
                    ),
                    _KbdChip('⌘K'),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 2.5.w),
          _LangToggle(locale: locale, primary: biz.primary),
          SizedBox(width: 1.2.w),
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
    padding: EdgeInsets.symmetric(horizontal: 0.7.w, vertical: 0.15.h),
    decoration: BoxDecoration(
      color: const Color(0xFF1A2A1F),
      borderRadius: BorderRadius.circular(0.4.h),
      border: Border.all(color: D.gold400.withOpacity(0.2), width: 0.08.h),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          offset: Offset(0, 0.15.h),
          blurRadius: 0,
        ),
      ],
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 9.sp,
        fontWeight: FontWeight.w500,
        color: D.gold300.withOpacity(0.7),
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
      borderRadius: BorderRadius.circular(0.5.h),
      onTap: () => ref.read(localeProvider.notifier).toggle(),
      child: Container(
        height: 3.h,
        padding: EdgeInsets.symmetric(horizontal: 1.w),
        decoration: BoxDecoration(
          border: Border.all(color: D.gold400.withOpacity(0.25), width: 0.08.h),
          borderRadius: BorderRadius.circular(0.5.h),
          color: Colors.black.withOpacity(0.3),
        ),
        alignment: Alignment.center,
        child: Text(
          locale == AppLocale.english ? 'اردو' : 'EN',
          style: TextStyle(
            fontFamily: 'Cabinet Grotesk',
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: D.gold300,
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
      width: 3.4.h,
      height: 3.4.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8860B), Color(0xFF6B4E0A)], // gold tones
        ),
        border: Border.all(color: D.gold400.withOpacity(0.6), width: 0.18.h),
        boxShadow: [
          BoxShadow(
            color: D.gold400.withOpacity(0.4),
            blurRadius: 1.h,
            spreadRadius: 0.15.h,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'A',
        style: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  MAIN AREA — Warm gold glows, minimal green
// ─────────────────────────────────────────────────
class _MainArea extends StatelessWidget {
  final Widget child;
  const _MainArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Large warm gold ambient — bottom-left
        Positioned(
          bottom: 8.h,
          left: 3.w,
          child: _CrystallineGlow(
            size: 45.w,
            color: D.gold400.withOpacity(0.09), // soft gold
            blur: 18.w,
          ),
        ),
        // Sharper gold highlight — top-right
        Positioned(
          top: 12.h,
          right: 6.w,
          child: _CrystallineGlow(
            size: 22.w,
            color: D.gold400.withOpacity(0.11),
            blur: 8.w,
          ),
        ),
        // Tiny gold spark — center-left
        Positioned(
          top: 35.h,
          left: 25.w,
          child: _CrystallineGlow(
            size: 6.w,
            color: D.gold300.withOpacity(0.12),
            blur: 3.w,
          ),
        ),
        child,
      ],
    );
  }
}

class _CrystallineGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double blur;
  const _CrystallineGlow({
    required this.size,
    required this.color,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [color, color.withOpacity(0.0)],
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: blur,
          spreadRadius: blur * 0.3,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────
//  SIDEBAR — Obsidian with dominant gold vein
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
      width: 21.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF08120C), Color(0xFF020503)],
        ),
        border: Border(
          right: BorderSide(
            color: Colors.black.withOpacity(0.6),
            width: 0.25.w,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: Offset(0.4.w, 0),
            blurRadius: 2.w,
          ),
        ],
      ),
      child: Stack(
        children: [
          _DotGridTexture(),
          // Gold vein — vertical line
          Positioned(
            top: 0,
            bottom: 0,
            right: 0.3.w,
            child: Container(
              width: 0.15.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    D.gold500.withOpacity(0.6),
                    D.gold500.withOpacity(0.9),
                    D.gold500.withOpacity(0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
          Column(
            children: [
              _SidebarBrand(bizType: bizType),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(0.8.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NavItem(
                        index: 0,
                        route: '/dashboard',
                        icon: Icons.dashboard_rounded,
                        labelEn: 'Dashboard',
                        labelUr: 'ڈیش بورڈ',
                        currentPath: path,
                        locale: locale,
                      ),
                      _NavItem(
                        index: 1,
                        route: '/pos',
                        icon: Icons.point_of_sale_rounded,
                        labelEn: bizType.saleLabel,
                        labelUr: 'سیل',
                        currentPath: path,
                        locale: locale,
                        trailing: _KbdSm('F1'),
                      ),
                      _NavItem(
                        index: 2,
                        route: '/inventory',
                        icon: Icons.inventory_2_rounded,
                        labelEn: bizType.productLabel,
                        labelUr: 'مال',
                        currentPath: path,
                        locale: locale,
                      ),
                      _NavItem(
                        index: 3,
                        route: '/customers',
                        icon: Icons.people_rounded,
                        labelEn: bizType.customerLabel,
                        labelUr: 'گاہک',
                        currentPath: path,
                        locale: locale,
                      ),
                      if (role.canManageProducts) ...[
                        _NavItem(
                          index: 4,
                          route: '/purchase',
                          icon: Icons.shopping_cart_rounded,
                          labelEn: 'Purchase',
                          labelUr: 'خریداری',
                          currentPath: path,
                          locale: locale,
                        ),
                      ],
                      _SidebarSectionLabel('Insights'),
                      if (role.canViewReports)
                        _NavItem(
                          index: 5,
                          route: '/reports',
                          icon: Icons.bar_chart_rounded,
                          labelEn: 'Reports',
                          labelUr: 'رپورٹ',
                          currentPath: path,
                          locale: locale,
                        ),
                      if (role.canViewAccounts)
                        _NavItem(
                          index: 6,
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

class _DotGridTexture extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Positioned.fill(child: CustomPaint(painter: _DotGridTexturePainter()));
}

class _DotGridTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = D.gold400.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    final spacing = 2.2.w;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 0.3.w, y + 0.3.w), 0.1.w, paint);
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
    height: 7.5.h,
    padding: EdgeInsets.symmetric(horizontal: 1.8.w),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: D.gold400.withOpacity(0.15), width: 0.1.h),
      ),
    ),
    child: Row(
      children: [
        // Gold brand mark
        Container(
          width: 3.6.h,
          height: 3.6.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(0.6.h),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4AF37), Color(0xFF8B6914)], // gold gradient
            ),
            boxShadow: [
              BoxShadow(
                color: D.gold400.withOpacity(0.5),
                blurRadius: 1.2.h,
                spreadRadius: 0.1.h,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            BusinessTypeIconX(bizType).moduleIcon ?? Icons.store_rounded,
            size: 17.sp,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 1.w),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFF0ECD6),
                letterSpacing: -0.03,
              ),
            ),
            SizedBox(height: 0.15.h),
            Text(
              bizType.label,
              style: TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 10.sp,
                fontStyle: FontStyle.italic,
                color: D.gold300.withOpacity(0.7),
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
    padding: EdgeInsets.fromLTRB(1.4.w, 2.h, 1.4.w, 0.8.h),
    child: Row(
      children: [
        Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 0.8.w,
            height: 0.8.w,
            decoration: BoxDecoration(
              color: D.gold400.withOpacity(0.7),
              boxShadow: [
                BoxShadow(color: D.gold400.withOpacity(0.4), blurRadius: 0.6.h),
              ],
            ),
          ),
        ),
        SizedBox(width: 0.8.w),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Cabinet Grotesk',
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w800,
            color: D.gold400.withOpacity(0.55),
            letterSpacing: 0.22,
          ),
        ),
        SizedBox(width: 0.8.w),
        Expanded(
          child: Container(
            height: 0.08.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [D.gold400.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatefulWidget {
  final int index;
  final String route;
  final IconData icon;
  final String labelEn;
  final String labelUr;
  final String currentPath;
  final AppLocale locale;
  final Widget? trailing;

  const _NavItem({
    required this.index,
    required this.route,
    required this.icon,
    required this.labelEn,
    required this.labelUr,
    required this.currentPath,
    required this.locale,
    this.trailing,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentPath.startsWith(widget.route);
    final label = widget.locale.isRtl ? widget.labelUr : widget.labelEn;
    final staggerDelay = (100 + widget.index * 40).ms;
    final entranceDuration = 350.ms;

    return Padding(
          padding: EdgeInsets.only(bottom: 0.15.h),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(0.6.h),
                onTap: () => context.go(widget.route),
                hoverColor: D.gold400.withOpacity(0.08),
                splashColor: D.gold400.withOpacity(0.03),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: 1.4.w,
                    vertical: 0.9.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(0.6.h),
                    border: isActive
                        ? Border(
                            left: BorderSide(color: D.gold400, width: 0.35.w),
                          )
                        : (_hovered
                              ? Border(
                                  left: BorderSide(
                                    color: D.gold400.withOpacity(0.3),
                                    width: 0.2.w,
                                  ),
                                )
                              : null),
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              D.gold400.withOpacity(
                                0.2,
                              ), // gold wash instead of green
                              Colors.transparent,
                            ],
                          )
                        : (_hovered
                              ? LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    D.gold400.withOpacity(0.06),
                                    Colors.transparent,
                                  ],
                                )
                              : null),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 15.sp,
                        color: isActive ? D.gold300 : const Color(0x99F0ECD6),
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Cabinet Grotesk',
                            fontSize: 11.sp,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? const Color(0xFFF0ECD6)
                                : const Color(0x99F0ECD6),
                            letterSpacing: isActive ? 0.01 : 0,
                          ),
                        ),
                      ),
                      if (widget.trailing != null) widget.trailing!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: entranceDuration, delay: staggerDelay)
        .slideX(
          begin: -0.08,
          end: 0,
          duration: entranceDuration,
          delay: staggerDelay,
          curve: Curves.easeOutCubic,
        );
  }
}

class _KbdSm extends StatelessWidget {
  final String label;
  const _KbdSm(this.label);

  @override
  Widget build(BuildContext context) => Container(
    height: 2.h,
    padding: EdgeInsets.symmetric(horizontal: 0.5.w),
    decoration: BoxDecoration(
      border: Border.all(color: D.gold400.withOpacity(0.2), width: 0.06.h),
      borderRadius: BorderRadius.circular(0.3.h),
      color: const Color(0xFF0D1A13),
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 8.5.sp,
        fontWeight: FontWeight.w600,
        color: D.gold300.withOpacity(0.6),
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
    padding: EdgeInsets.symmetric(horizontal: 1.8.w, vertical: 1.h),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: D.gold400.withOpacity(0.1), width: 0.08.h),
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.0)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 3.2.h,
          height: 3.2.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4AF37), Color(0xFF8B6914)], // gold
            ),
            border: Border.all(
              color: D.gold400.withOpacity(0.4),
              width: 0.12.h,
            ),
            boxShadow: [
              BoxShadow(
                color: D.gold400.withOpacity(0.3),
                blurRadius: 0.8.h,
                spreadRadius: 0.1.h,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'A',
            style: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 1.w),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin',
                style: TextStyle(
                  fontFamily: 'Cabinet Grotesk',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF0ECD6),
                ),
              ),
              SizedBox(height: 0.15.h),
              Text(
                'Owner',
                style: TextStyle(
                  fontFamily: 'Instrument Serif',
                  fontSize: 9.5.sp,
                  fontStyle: FontStyle.italic,
                  color: D.gold300.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(0.5.h),
          onTap: onSettings,
          child: Padding(
            padding: EdgeInsets.all(0.4.w),
            child: Icon(
              Icons.settings_rounded,
              size: 15.sp,
              color: D.bgSurface,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────
//  STATUSBAR — Gold accents, reduced green
// ─────────────────────────────────────────────────
class _Statusbar extends ConsumerWidget {
  final SyncState? sync;
  final BizTheme biz;
  const _Statusbar({required this.sync, required this.biz});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = sync?.status ?? SyncStatus.idle;
    final online = status != SyncStatus.offline;
    // Synced status: gold dot instead of green
    final (dotColor, syncLabel) = switch (status) {
      SyncStatus.syncing => (D.gold400, 'Syncing…'),
      SyncStatus.offline => (D.warning500, 'Offline — sync paused'),
      SyncStatus.error => (D.danger500, 'Sync error'),
      _ => (D.gold400, 'All synced'),
    };
    final branch =
        ref.watch(prefsProvider).getString(AppConstants.keyBranchId) ?? '';
    final now = TimeOfDay.now();
    final timeStr = now.format(context);

    return Container(
      height: 3.2.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF060D08), Color(0xFF020402)],
        ),
        border: Border(
          top: BorderSide(color: D.gold400.withOpacity(0.12), width: 0.08.h),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Row(
        children: [
          _StatusGroup(
            children: [
              _StatusDot(dotColor),
              Text(
                syncLabel,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9.sp,
                  color: const Color(0xBFE8E4D0),
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
                size: 10.sp,
                color: const Color(0x66E8E4D0),
              ),
              Text(
                online ? 'Online' : 'Offline',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9.sp,
                  color: const Color(0xBFE8E4D0),
                ),
              ),
            ],
          ),
          if (branch.isNotEmpty) ...[
            _StatusSep(),
            _StatusGroup(
              children: [
                Icon(
                  Icons.apartment_rounded,
                  size: 10.sp,
                  color: const Color(0x66E8E4D0),
                ),
                Text(
                  branch.length > 20 ? branch.substring(0, 20) : branch,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9.sp,
                    color: const Color(0xBFE8E4D0),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          _StatusGroup(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 10.sp,
                color: D.gold400.withOpacity(0.7),
              ),
              Text(
                'FBR connected',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9.sp,
                  color: D.gold300.withOpacity(0.6),
                  letterSpacing: 0.02,
                ),
              ),
            ],
          ),
          _StatusSep(),
          Text(
            AppConstants.appVersion,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9.sp,
              color: const Color(0x4DE8E4D0),
            ),
          ),
          _StatusSep(),
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9.sp,
              color: const Color(0x73E8E4D0),
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
              children: [
                w,
                SizedBox(width: 0.6.w),
              ],
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
    width: 0.7.h,
    height: 0.7.h,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.6),
          blurRadius: 0.5.h,
          spreadRadius: 0.15.h,
        ),
      ],
    ),
  );
}

class _StatusSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 0.08.w,
    height: 1.2.h,
    margin: EdgeInsets.symmetric(horizontal: 1.w),
    color: D.gold400.withOpacity(0.12),
  );
}

// ─────────────────────────────────────────────────
//  LICENSE BANNER — Warm warning tone
// ─────────────────────────────────────────────────
class _LicenseBanner extends StatelessWidget {
  final String message;
  const _LicenseBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.7.h),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3D2E0A), Color(0xFF2A1F06)],
      ),
      border: Border(
        bottom: BorderSide(color: D.warning500.withOpacity(0.3), width: 0.1.h),
      ),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: D.warning500, size: 13.sp),
        SizedBox(width: 0.8.w),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFE8D5A3),
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/license?reason=renew'),
          style: TextButton.styleFrom(
            foregroundColor: D.warning500,
            padding: EdgeInsets.symmetric(horizontal: 1.2.w),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Text('Renew'),
        ),
      ],
    ),
  );
}

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
