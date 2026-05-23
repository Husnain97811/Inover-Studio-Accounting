// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPass = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (res.user == null) {
        AppErrorHandler.showError(context, 'Login failed.');
        return;
      }
      final meta = res.user!.userMetadata ?? {};
      final prefs = ref.read(prefsProvider);
      await prefs.setString(
        AppConstants.keyUserRole,
        meta['role'] as String? ?? 'cashier',
      );
      await prefs.setString(
        AppConstants.keyBranchId,
        meta['branch_id'] as String? ?? '',
      );
      final tid = meta['tenant_id'] as String? ?? '';
      if (tid.isNotEmpty) await prefs.setString(AppConstants.keyTenantId, tid);
      ref.invalidate(licenseProvider);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final tenantId = prefs.getString(AppConstants.keyTenantId) ?? '';
      context.go(tenantId.isEmpty ? '/setup' : '/dashboard');
    } on AuthException catch (e) {
      if (mounted) AppErrorHandler.showError(context, e);
    } catch (e) {
      if (mounted) AppErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bgApp,
      body: Row(
        children: [
          // ── Left: Art panel ───────────────────────
          Expanded(
            flex: 11,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.5),
                  radius: 1.4,
                  colors: [Color(0x52116B43), Colors.transparent],
                ),
              ),
              child: Stack(
                children: [
                  // Dark base
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0A1A11), Color(0xFF040E08)],
                      ),
                    ),
                  ),
                  // Gold blob bottom-right
                  Positioned(
                    bottom: -80,
                    right: -60,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: D.gold400.withOpacity(0.06),
                      ),
                    ),
                  ),
                  // Dot grid
                  Positioned.fill(
                    child: CustomPaint(painter: _LoginDotPainter()),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(64),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top — logo area (placeholder, no logo per instructions)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [D.brand400, D.brand700],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.store_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        // Center — headline
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inover Studio · est. 2026',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: D.gold300,
                                letterSpacing: 0.18,
                                textBaseline: TextBaseline.alphabetic,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(width: 56, height: 1, color: D.gold400),
                            const SizedBox(height: 24),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Instrument Serif',
                                  fontSize: 72,
                                  fontWeight: FontWeight.w400,
                                  height: 1.0,
                                  letterSpacing: -0.025,
                                  color: Color(0xFFFAF4DD),
                                ),
                                children: [
                                  TextSpan(text: 'Run your shop,\nnot '),
                                  TextSpan(
                                    text: 'your software.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: D.gold300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Text(
                              'Offline-first ERP, hand-crafted for Pakistani\n'
                              'retailers and distributors.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15.5,
                                color: Color(0xB8F5EFD9),
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        // Bottom
                        Text(
                          'v${AppConstants.appVersion}  ·  Lahore',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: D.gold400,
                            letterSpacing: 0.10,
                            textBaseline: TextBaseline.alphabetic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right: Login form ────────────────────
          Expanded(
            flex: 10,
            child: Container(
              color: D.bgSurface,
              padding: const EdgeInsets.all(64),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(width: 40, height: 1, color: D.gold400),
                        const SizedBox(height: 14),
                        const Text(
                          'Welcome back.',
                          style: TextStyle(
                            fontFamily: 'Instrument Serif',
                            fontSize: 40,
                            fontWeight: FontWeight.w400,
                            color: D.ink800,
                            letterSpacing: -0.02,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sign in to continue to your ERP.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: D.fgSecondary,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Email
                        ErpField(
                          label: 'Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          required: true,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        ErpField(
                          label: 'Password',
                          controller: _passCtrl,
                          obscureText: !_showPass,
                          required: true,
                          suffix: IconButton(
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 16,
                              color: D.fgTertiary,
                            ),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Min 6 characters'
                              : null,
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 28),

                        // Sign In button
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: D.brand500,
                              foregroundColor: D.fgOnBrand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Open the day'),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: D.fgTertiary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: D.brand600,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                              ),
                              child: const Text(
                                'Need help?',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCDA06B).withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
