import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────
//  STATE
// ─────────────────────────────────────────────────
class LoadingState {
  final bool isLoading;
  final String? message;
  const LoadingState({this.isLoading = false, this.message});

  LoadingState copyWith({bool? isLoading, String? message}) => LoadingState(
    isLoading: isLoading ?? this.isLoading,
    message: message ?? this.message,
  );
}

// ─────────────────────────────────────────────────
//  NOTIFIER
//  Riverpod's Notifier does NOT have dispose().
//  Use ref.onDispose() instead for cleanup.
// ─────────────────────────────────────────────────
class LoadingNotifier extends Notifier<LoadingState> {
  Timer? _timer;

  @override
  LoadingState build() {
    // Register cleanup via ref — this is correct for Riverpod Notifier
    ref.onDispose(_cancelTimer);
    return const LoadingState();
  }

  /// Start loading. Auto-stops after [timeoutSeconds] (default 15).
  void start({String? message, int timeoutSeconds = 15}) {
    _cancelTimer();
    state = LoadingState(isLoading: true, message: message);
    _timer = Timer(Duration(seconds: timeoutSeconds), () {
      if (state.isLoading) stop();
    });
  }

  void stop() {
    _cancelTimer();
    state = const LoadingState();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final loadingProvider = NotifierProvider<LoadingNotifier, LoadingState>(
  LoadingNotifier.new,
);

// ─────────────────────────────────────────────────
//  GRADIENT SPINNER
// ─────────────────────────────────────────────────
class _GradientSpinner extends StatelessWidget {
  final double size;
  const _GradientSpinner({this.size = 52});

  static const _gradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                _gradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3.5,
              strokeCap: StrokeCap.round,
            ),
          ),
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: const BoxDecoration(
              gradient: _gradient,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  OVERLAY WIDGET  — wrap your Scaffold body with this
// ─────────────────────────────────────────────────
class AppLoadingOverlay extends ConsumerWidget {
  final Widget child;
  const AppLoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(loadingProvider);
    return Stack(
      children: [
        child,
        if (loading.isLoading) ...[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: ColoredBox(color: Colors.black.withOpacity(0.38)),
            ),
          ),
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GradientSpinner(),
                    if (loading.message != null) ...[
                      const SizedBox(height: 16),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        ).createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
                        child: Text(
                          loading.message!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
