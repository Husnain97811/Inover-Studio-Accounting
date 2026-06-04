// test/pos/test_discount_ledger.dart
// Run: flutter test test/pos/test_discount_ledger.dart
// Offline tests for discount policy + cart total math.

import 'package:flutter_test/flutter_test.dart';
import 'package:is_accounting/core/constants/views.dart';
import 'package:is_accounting/core/database/app_database.dart' show UserRole;
import 'package:is_accounting/core/pos/discount_policy.dart';

void main() {
  group('DiscountPolicy', () {
    test('owner has no cap', () {
      expect(DiscountPolicy.maxPercentFor(UserRole.owner), null);
      expect(
        DiscountPolicy.resolvePercent(
          role: UserRole.owner,
          percent: 50,
          base: 1000,
        ),
        500,
      );
      expect(
        DiscountPolicy.resolveRupees(
          role: UserRole.owner,
          rupees: 900,
          base: 1000,
        ),
        900,
      );
    });

    test('cashier capped at 30%', () {
      expect(DiscountPolicy.maxPercentFor(UserRole.cashier), 30.0);
      // 50% requested → clamped to 30% = 300
      expect(
        DiscountPolicy.resolvePercent(
          role: UserRole.cashier,
          percent: 50,
          base: 1000,
        ),
        300,
      );
      // Rs.900 requested → clamped to 30% cap = 300
      expect(
        DiscountPolicy.resolveRupees(
          role: UserRole.cashier,
          rupees: 900,
          base: 1000,
        ),
        300,
      );
      // under cap allowed
      expect(
        DiscountPolicy.resolvePercent(
          role: UserRole.cashier,
          percent: 20,
          base: 1000,
        ),
        200,
      );
    });

    test('isAllowed flags over-cap requests for non-owner', () {
      expect(
        DiscountPolicy.isAllowed(
          role: UserRole.cashier,
          rupees: 400,
          base: 1000,
        ),
        false,
      ); // 400 > 30% of 1000
      expect(
        DiscountPolicy.isAllowed(
          role: UserRole.cashier,
          rupees: 300,
          base: 1000,
        ),
        true,
      );
      expect(
        DiscountPolicy.isAllowed(role: UserRole.owner, rupees: 999, base: 1000),
        true,
      );
    });
  });
}
