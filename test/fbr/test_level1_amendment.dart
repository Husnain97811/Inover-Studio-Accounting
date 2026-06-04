// test/fbr/test_level1_amendment.dart
// Run: flutter test test/fbr/test_level1_amendment.dart
// LEVEL 1 (offline) for C5 — boundary tests for the 72-hour lock.

import 'package:flutter_test/flutter_test.dart';
import 'package:is_accounting/core/fbr/amendment_policy.dart';

void main() {
  final now = DateTime(2026, 6, 2, 12, 0, 0);

  test('Not fiscalized → freely editable (Option A)', () {
    final w = AmendmentWindow.evaluate(verifiedAt: null, now: now);
    expect(w.allowed, true);
    expect(w.fiscalized, false);
  });

  test('Fiscalized 71h ago → still editable', () {
    final w = AmendmentWindow.evaluate(
      verifiedAt: now.subtract(const Duration(hours: 71)),
      now: now,
    );
    expect(w.allowed, true);
    expect(w.fiscalized, true);
    expect(w.timeLeft! > Duration.zero, true);
  });

  test('Fiscalized 73h ago → locked', () {
    final w = AmendmentWindow.evaluate(
      verifiedAt: now.subtract(const Duration(hours: 73)),
      now: now,
    );
    expect(w.allowed, false);
    expect(w.timeLeft, Duration.zero);
    expect(w.blockedReason, contains('72 hours'));
  });

  test('Exactly 72h (boundary) → locked (window is strictly open)', () {
    final w = AmendmentWindow.evaluate(
      verifiedAt: now.subtract(const Duration(hours: 72)),
      now: now,
    );
    expect(w.allowed, false);
  });

  test('Just inside 72h (71h59m) → editable', () {
    final w = AmendmentWindow.evaluate(
      verifiedAt: now.subtract(const Duration(hours: 71, minutes: 59)),
      now: now,
    );
    expect(w.allowed, true);
  });

  test('countdownLabel formats remaining time', () {
    final w = AmendmentWindow.evaluate(
      verifiedAt: now.subtract(const Duration(hours: 66, minutes: 48)),
      now: now,
    );
    // 72h - 66h48m = 5h12m left
    expect(w.countdownLabel, 'Editable for 5h 12m');
  });
}
