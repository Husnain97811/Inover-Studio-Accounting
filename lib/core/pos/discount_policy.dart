// lib/core/pos/discount_policy.dart
//
// Pure discount rules (no UI, no DB) — testable offline.
// Rule you specified:
//   • Owner  → unlimited discount (any Rs. or %)
//   • Others → max 30% (whether entered as % or as a rupee amount)

import '../../core/database/app_database.dart' show UserRole;
import '../constants/views.dart';

class DiscountPolicy {
  /// Max percent a role may discount. Owner = no cap (returns null).
  static double? maxPercentFor(UserRole role) {
    // Adjust the enum names to match yours if different.
    if (role == UserRole.owner) return null; // unlimited
    return 30.0; // cashier / manager / others
  }

  /// Resolve a discount entered as % into rupees, clamped to the role cap.
  /// `base` is the amount the discount applies to (itemsTotal).
  static double resolvePercent({
    required UserRole role,
    required double percent,
    required double base,
  }) {
    final cap = maxPercentFor(role);
    final p = cap == null ? percent : (percent > cap ? cap : percent);
    final clamped = p < 0 ? 0.0 : p;
    return base * clamped / 100.0;
  }

  /// Resolve a discount entered directly in rupees, clamped to the role cap.
  static double resolveRupees({
    required UserRole role,
    required double rupees,
    required double base,
  }) {
    final r = rupees < 0 ? 0.0 : (rupees > base ? base : rupees);
    final cap = maxPercentFor(role);
    if (cap == null) return r; // owner: no cap
    final maxRupees = base * cap / 100.0;
    return r > maxRupees ? maxRupees : r;
  }

  /// True if the requested discount is allowed for the role (for validation msgs).
  static bool isAllowed({
    required UserRole role,
    required double rupees,
    required double base,
  }) {
    final cap = maxPercentFor(role);
    if (cap == null) return rupees <= base;
    return rupees <= base * cap / 100.0 + 0.001; // tiny epsilon
  }

  static String capLabel(UserRole role) {
    final cap = maxPercentFor(role);
    return cap == null ? 'No limit (owner)' : 'Max ${cap.toStringAsFixed(0)}%';
  }
}
