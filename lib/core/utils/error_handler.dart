// lib/core/utils/error_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/providers/loading_provider.dart';

// ─────────────────────────────────────────────────
//  LOGGER (singleton)
// ─────────────────────────────────────────────────
final _log = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);

// ─────────────────────────────────────────────────
//  ERROR HANDLER  (static utility)
// ─────────────────────────────────────────────────
class AppErrorHandler {
  AppErrorHandler._();

  // ── Extract human-readable message from any error ──
  static String extractMessage(dynamic error) {
    if (error is SocketException || error is HandshakeException) {
      return 'No internet connection. Please check your network.';
    }
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (error is PostgrestException) {
      return _cleanText(_bestOf([error.hint, error.details?.toString(), error.message]));
    }
    if (error is AuthException) {
      return _cleanText(_parseJsonMessage(error.message));
    }
    if (error is FunctionException) {
      return _cleanText(error.reasonPhrase ?? error.details?.toString() ?? 'Server error.');
    }
    if (error is Exception) {
      return _cleanText(_parseExceptionString(error.toString()));
    }
    return 'An unexpected error occurred. Please try again.';
  }

  // ── Show error snackbar ────────────────────────
  static void showError(BuildContext context, dynamic error, {String? prefix}) {
    final msg = prefix != null
        ? '$prefix: ${extractMessage(error)}'
        : extractMessage(error);
    _log.e('AppError', error: error);
    _showSnackbar(context, msg, isError: true);
  }

  // ── Show success snackbar ──────────────────────
  static void showSuccess(BuildContext context, String message) {
    _log.i('Success: $message');
    _showSnackbar(context, message, isError: false);
  }

  // ── Show info snackbar ─────────────────────────
  static void showInfo(BuildContext context, String message) {
    _log.i('Info: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// ── GUARD: Wraps any async operation with loading + error handling ──────
  /// Usage:
  ///   await AppErrorHandler.guard(
  ///     ref: ref,
  ///     context: context,
  ///     message: 'Saving invoice...',
  ///     action: () async { ... },
  ///   );
  static Future<T?> guard<T>({
    required WidgetRef ref,
    required BuildContext context,
    required Future<T> Function() action,
    String? message,
    String? successMessage,
    VoidCallback? onSuccess,
    int timeoutSeconds = 15,
  }) async {
    final loader = ref.read(loadingProvider.notifier);
    loader.start(message: message, timeoutSeconds: timeoutSeconds);
    try {
      final result = await action();
      loader.stop();
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      onSuccess?.call();
      return result;
    } catch (e) {
      loader.stop();
      _log.e('Guard caught error', error: e);
      if (context.mounted) showError(context, e);
      return null;
    }
  }

  // ── Private helpers ────────────────────────────
  static void _showSnackbar(BuildContext context, String msg,
      {required bool isError}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ]),
          backgroundColor:
              isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
  }

  static String _bestOf(List<String?> candidates) {
    for (final s in candidates) {
      if (s != null && s.trim().isNotEmpty && s.trim() != 'null') return s.trim();
    }
    return 'An unexpected error occurred.';
  }

  static String _parseJsonMessage(String raw) {
    try {
      final start = raw.indexOf('{');
      if (start != -1) {
        final decoded = jsonDecode(raw.substring(start)) as Map;
        return (decoded['message'] ??
                decoded['error_description'] ??
                decoded['error'] ??
                raw)
            .toString();
      }
    } catch (_) {}
    return raw;
  }

  static String _parseExceptionString(String raw) {
    try {
      final s = raw.indexOf('{');
      final e = raw.lastIndexOf('}');
      if (s != -1 && e > s) {
        final decoded = jsonDecode(raw.substring(s, e + 1)) as Map;
        return (decoded['message'] ?? decoded['error'] ?? raw).toString();
      }
    } catch (_) {}
    return raw
        .replaceAll(RegExp(r'\w+Exception\(message:\s*'), '')
        .replaceAll(RegExp(r',\s*statusCode:\s*\d+\)'), '')
        .replaceAll(RegExp(r'^(Exception|Error):\s*', caseSensitive: false), '')
        .trim();
  }

  static String _cleanText(String t) {
    t = t.trim();
    for (final prefix in [
      'PostgrestException:',
      'AuthException:',
      'FunctionException:',
      'Exception:',
      'Error:',
    ]) {
      if (t.toLowerCase().startsWith(prefix.toLowerCase())) {
        t = t.substring(prefix.length).trim();
      }
    }
    return t.isEmpty ? 'An unexpected error occurred.' : t;
  }
}
