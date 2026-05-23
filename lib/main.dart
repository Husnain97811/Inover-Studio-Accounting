// lib/main.dart
// ─────────────────────────────────────────────────────────────
//  ENTRY POINT
//  How to configure Supabase:
//    1. Open lib/core/constants/app_constants.dart
//    2. Replace supabaseUrl    = 'https://YOUR_PROJECT.supabase.co'
//    3. Replace supabaseAnonKey = 'YOUR_ANON_KEY'
//  Both values are on: Supabase Dashboard → Settings → API
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Desktop window ──────────────────────────────
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(1024, 680));
  await windowManager.setTitle(AppConstants.appName);
  await windowManager.setSize(const Size(1440, 900));
  await windowManager.center();
  await windowManager.show();

  // ── Supabase ─────────────────────────────────────
  // URL and key come from lib/core/constants/app_constants.dart
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const IsAccountingApp(),
    ),
  );
}

class IsAccountingApp extends ConsumerWidget {
  const IsAccountingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizType = ref.watch(businessTypeProvider);
    final theme = AppTheme.forBusiness(bizType);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(theme),
      locale: Locale(locale.code),
      supportedLocales: const [Locale('en'), Locale('ur')],
      routerConfig: router,
    );
  }
}
