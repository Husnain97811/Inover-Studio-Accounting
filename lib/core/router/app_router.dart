// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/licensing/license_service.dart';
import '../../features/auth/screens/license_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/setup_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../features/purchase/screens/purchase_screen.dart';
import '../../features/accounts/screens/accounts_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/main_shell.dart';

// ── Auth stream provider ──────────────────────────────────
final _authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ── Router provider — created ONCE, never recreated ───────
// The old version used Provider<GoRouter> which recreated the entire GoRouter
// every time licenseProvider or _authStateProvider emitted. That forced
// GoRouter to rebuild the full navigation stack on every auth tick,
// producing the "previous screen flashes before the new one" jerk.
//
// Fix: use a long-lived ChangeNotifierProvider so the GoRouter instance
// stays stable. Only the redirect() logic reruns on auth/license changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    // No animation between shell routes — instant, zero jerk
    // Individual screens can add their own entry animations if desired
    redirect: (context, state) => notifier._redirect(state),
    routes: [
      GoRoute(
        path: '/license',
        pageBuilder: (_, s) => _noAnimPage(
          LicenseScreen(reason: s.uri.queryParameters['reason']),
          s.pageKey,
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => _noAnimPage(const LoginScreen(), s.pageKey),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (_, s) => _noAnimPage(const SetupScreen(), s.pageKey),
      ),

      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            // NoTransitionPage: eliminates the cross-fade between sidebar
            // screens — the sidebar stays perfectly still, only the content
            // area swaps instantly. This is what professional desktop ERPs do.
            pageBuilder: (_, s) =>
                _noAnimPage(const DashboardScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/pos',
            pageBuilder: (_, s) => _noAnimPage(const PosScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (_, s) =>
                _noAnimPage(const InventoryScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (_, s) =>
                _noAnimPage(const CustomersScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/purchase',
            pageBuilder: (_, s) =>
                _noAnimPage(const PurchaseScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/accounts',
            pageBuilder: (_, s) =>
                _noAnimPage(const AccountsScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, s) =>
                _noAnimPage(const ReportsScreen(), s.pageKey),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, s) =>
                _noAnimPage(const SettingsScreen(), s.pageKey),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(notifier.dispose);
  return router;
});

// Zero-duration page swap — no crossfade, no slide, no scale
// The shell (sidebar + topbar) stays on screen the whole time.
// Only the content area changes, and it changes instantly.
NoTransitionPage<void> _noAnimPage(Widget child, ValueKey<String> key) =>
    NoTransitionPage<void>(key: key, child: child);

// ── Token expiry check ────────────────────────────────────
bool _isTokenExpired(Session session) {
  final expiresAt = session.expiresAt;
  if (expiresAt == null) return false;
  return DateTime.now().millisecondsSinceEpoch / 1000 > expiresAt;
}

// ── Router notifier — stable ChangeNotifier ───────────────
// Lives for the lifetime of the provider. GoRouter holds a reference to it
// and calls redirect() again whenever notifyListeners() fires.
// Because this is NOT recreated on auth ticks, GoRouter stays stable.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late final _authSub;

  // Cache the last known license so redirect() doesn't need to async-wait
  LicenseResult? _license;
  bool _licenseLoading = true;

  _RouterNotifier(this._ref) {
    // Watch license changes and notify router
    _ref.listen<AsyncValue<LicenseResult>>(licenseProvider, (_, next) {
      _licenseLoading = next.isLoading;
      _license = next.value;
      notifyListeners();
    });

    // Watch Supabase auth changes and notify router
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  String? _redirect(GoRouterState state) {
    final path = state.matchedLocation;

    if (path.startsWith('/license') || path.startsWith('/setup')) return null;
    if (_licenseLoading) return null;

    final license = _license;
    if (license == null ||
        license.status == LicenseStatus.notActivated ||
        license.status == LicenseStatus.revoked) {
      return '/license';
    }
    if (license.status == LicenseStatus.expired) {
      return '/license?reason=expired';
    }

    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null && !_isTokenExpired(session);

    if (!isLoggedIn) {
      return path.startsWith('/login') ? null : '/login';
    }

    if (path.startsWith('/login') || path.startsWith('/license')) {
      final tenantId = _ref.read(currentTenantIdProvider);
      return tenantId.isEmpty ? '/setup' : '/dashboard';
    }

    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId.isEmpty && !path.startsWith('/setup')) return '/setup';

    return null;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
