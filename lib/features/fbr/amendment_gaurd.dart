// lib/features/fbr/amendment_guard.dart
//
// C5 — UI guard helpers. Call these wherever a void/edit/cancel action exists
// (POS, invoice list, accounts). They wrap the pure AmendmentWindow policy.

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/fbr/amendment_policy.dart';
import '../../core/theme/app_theme.dart';

class AmendmentGuard {
  /// Evaluate straight from a Drift invoice row.
  static AmendmentWindow forInvoice(Invoice inv, {DateTime? now}) =>
      AmendmentWindow.evaluate(verifiedAt: inv.fbrVerifiedAt, now: now);

  /// Returns true if the action may proceed. If blocked, shows a dialog and
  /// returns false. Use it to gate a void/edit handler:
  ///
  ///   if (!await AmendmentGuard.ensureAmendable(context, invoice)) return;
  ///   // ...proceed with void/edit
  static Future<bool> ensureAmendable(
    BuildContext context,
    Invoice inv, {
    DateTime? now,
  }) async {
    final w = forInvoice(inv, now: now);
    if (w.allowed) return true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: D.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: const [
            Icon(Icons.lock_clock_rounded, color: D.warning500, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Amendment window closed',
                style: TextStyle(
                  fontFamily: 'Instrument Serif',
                  fontSize: 18,
                  color: D.ink800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          w.blockedReason,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: D.fgSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  /// A small status chip you can drop next to an invoice row to show the
  /// remaining editable time (or the locked state).
  static Widget statusChip(Invoice inv, {DateTime? now}) {
    final w = forInvoice(inv, now: now);
    final (bg, fg, icon) = w.allowed
        ? (D.success50, D.success700, Icons.edit_rounded)
        : (D.neutral100, D.fgTertiary, Icons.lock_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            w.countdownLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
