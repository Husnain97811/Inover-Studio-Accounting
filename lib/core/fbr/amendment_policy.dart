// lib/core/fbr/amendment_policy.dart
//
// C5 — the 72-hour amendment lock, as PURE logic (no DB, no UI).
// This is the single source of truth for "can this invoice be changed?"
//
// Rule (FBR): a fiscalized invoice may be amended/cancelled/deleted only within
// 72 hours of fiscalization. After that, Commissioner approval is needed — which
// the app cannot grant, so we block it.
//
// Option A: an invoice that is NOT yet fiscalized is freely editable (the
// window hasn't started). The lock only applies once FBR has the record.

class AmendmentWindow {
  /// Legal window length. Kept as a constant so it's easy to change if FBR does.
  static const Duration window = Duration(hours: 72);

  final bool allowed; // can the user amend/void right now?
  final bool fiscalized; // has FBR confirmed it?
  final Duration? timeLeft; // remaining time in the window (null if N/A)
  final DateTime? lockAt; // the moment it locks (null if N/A)

  const AmendmentWindow({
    required this.allowed,
    required this.fiscalized,
    this.timeLeft,
    this.lockAt,
  });

  /// `verifiedAt` = invoice.fbrVerifiedAt (null if not fiscalized).
  /// `now` is injectable for testing.
  factory AmendmentWindow.evaluate({
    required DateTime? verifiedAt,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    // Option A — not fiscalized yet → freely editable, no clock running.
    if (verifiedAt == null) {
      return const AmendmentWindow(allowed: true, fiscalized: false);
    }

    final lockAt = verifiedAt.add(window);
    final left = lockAt.difference(current);
    final stillOpen = left > Duration.zero;

    return AmendmentWindow(
      allowed: stillOpen,
      fiscalized: true,
      timeLeft: stillOpen ? left : Duration.zero,
      lockAt: lockAt,
    );
  }

  /// Human-friendly reason when blocked (for dialogs/snackbars).
  String get blockedReason => fiscalized
      ? 'This invoice was fiscalized more than 72 hours ago. '
            'It can no longer be changed in the app — amendments now require '
            'approval from the Commissioner Inland Revenue.'
      : 'This invoice cannot be changed.';

  /// Short countdown label, e.g. "Editable for 5h 12m".
  String get countdownLabel {
    if (!fiscalized) return 'Editable';
    if (!allowed) return 'Locked (past 72h)';
    final h = timeLeft!.inHours;
    final m = timeLeft!.inMinutes % 60;
    return 'Editable for ${h}h ${m}m';
  }
}
