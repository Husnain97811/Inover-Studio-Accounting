// lib/features/fbr/fbr_providers.dart
//
// Replaces your old fbrServiceProvider. The upgraded FbrService needs both the
// Drift database and SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart'; // databaseProvider, prefsProvider
import 'fbr_service.dart';

final fbrServiceProvider = Provider<FbrService>((ref) {
  final db = ref.read(databaseProvider);
  final prefs = ref.read(prefsProvider);
  final service = FbrService(db, prefs);
  service.startRetryJob(); // begin the 5-min retry sweep
  ref.onDispose(service.stop);
  return service;
});
