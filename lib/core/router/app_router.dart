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

// ── Supabase auth stream provider ────────────────────────
// GoRouter refreshes whenever this stream emits an event.
// This fires on signIn, signOut, tokenRefresh, etc.
final _authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // These providers trigger router refresh on change
  final licenseAsync = ref.watch(licenseProvider);
  final authAsync = ref.watch(_authStateProvider);

  return GoRouter(
    initialLocation: '/login',

    // ── Refresh listenable: rebuild router when auth or license changes ──
    refreshListenable: _RouterNotifier(ref),

    redirect: (context, state) {
      final path = state.matchedLocation;

      // ── 1. License check ──────────────────────────────
      // Always allow license + setup screens
      if (path.startsWith('/license') || path.startsWith('/setup')) {
        return null;
      }

      // While license is loading don't redirect
      if (licenseAsync.isLoading) return null;

      final license = licenseAsync.value;

      // Not activated / revoked → show license screen
      if (license == null ||
          license.status == LicenseStatus.notActivated ||
          license.status == LicenseStatus.revoked) {
        return '/license';
      }

      // Expired past grace period
      if (license.status == LicenseStatus.expired) {
        return '/license?reason=expired';
      }

      // ── 2. Auth check ──────────────────────────────────
      // Get LIVE session from Supabase (not a stale provider value)
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null && !_isTokenExpired(session);

      if (!isLoggedIn) {
        // Not on login page → send to login
        if (!path.startsWith('/login')) return '/login';
        return null; // already on login, stay
      }

      // ── 3. Logged in — skip login/license if already authed ──
      if (path.startsWith('/login') || path.startsWith('/license')) {
        // Decide where to send them
        final tenantId = ref.read(currentTenantIdProvider);
        if (tenantId.isEmpty) return '/setup';
        return '/dashboard';
      }

      // ── 4. First-time setup ───────────────────────────
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenantId.isEmpty && !path.startsWith('/setup')) {
        return '/setup';
      }

      return null; // all good — let navigation proceed
    },

    routes: [
      GoRoute(
        path: '/license',
        builder: (_, s) =>
            LicenseScreen(reason: s.uri.queryParameters['reason']),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),

      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (_, __) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/purchase',
            builder: (_, __) => const PurchaseScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (_, __) => const AccountsScreen(),
          ),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// ── Check if JWT access token is expired ─────────────────
bool _isTokenExpired(Session session) {
  final expiresAt = session.expiresAt;
  if (expiresAt == null) return false;
  // expiresAt is in seconds since epoch
  return DateTime.now().millisecondsSinceEpoch / 1000 > expiresAt;
}

// ── Listenable that triggers GoRouter refresh ─────────────
// GoRouter calls redirect() again whenever this notifies.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late final _sub;

  _RouterNotifier(this._ref) {
    // Listen to Supabase auth state changes
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners(); // triggers GoRouter to re-run redirect()
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
