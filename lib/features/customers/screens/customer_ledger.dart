// lib/features/customers/customer_ledger.dart
//
// The khata ledger. Records credit sales and repayments as CustomerTransactions,
// keeps the cached Customers.balance in sync, and exposes balance + history.
//
// Balance convention: sale => balance increases (customer owes more);
//                      payment => balance decreases.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/views.dart';

class CustomerLedger {
  final AppDatabase _db;
  const CustomerLedger(this._db);

  /// Current balance for a customer (from the cached column).
  Future<double> balanceOf(String customerId) async {
    final c = await (_db.select(
      _db.customers,
    )..where((t) => t.id.equals(customerId))).getSingleOrNull();
    return c?.balance ?? 0.0;
  }

  /// Record a CREDIT SALE: adds `amount` to the customer's balance.
  /// Call this when an invoice is paid via 'credit'.
  Future<void> recordCreditSale({
    required String tenantId,
    required String customerId,
    required double amount,
    required String invoiceId,
    String? note,
  }) async {
    if (amount <= 0) return;
    await _append(
      tenantId: tenantId,
      customerId: customerId,
      type: 'sale',
      delta: amount, // +
      invoiceId: invoiceId,
      note: note,
    );
  }

  /// Record a REPAYMENT: subtracts `amount` from the balance.
  Future<void> recordPayment({
    required String tenantId,
    required String customerId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) return;
    await _append(
      tenantId: tenantId,
      customerId: customerId,
      type: 'payment',
      delta: -amount, // −
      note: note,
    );
  }

  /// Manual adjustment (+/-) e.g. opening balance or correction.
  Future<void> recordAdjustment({
    required String tenantId,
    required String customerId,
    required double delta,
    String? note,
  }) => _append(
    tenantId: tenantId,
    customerId: customerId,
    type: 'adjustment',
    delta: delta,
    note: note,
  );

  Future<void> _append({
    required String tenantId,
    required String customerId,
    required String type,
    required double delta,
    String? invoiceId,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final c = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();
      final current = c?.balance ?? 0.0;
      final after = current + delta;

      await _db
          .into(_db.customerTransactions)
          .insert(
            CustomerTransactionsCompanion.insert(
              id: const Uuid().v4(),
              tenantId: tenantId,
              customerId: customerId,
              type: type,
              amount: delta.abs(),
              balanceAfter: after,
              invoiceId: Value(invoiceId),
              note: Value(note),
              createdAt: now,
            ),
          );

      await (_db.update(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(balance: Value(after), updatedAt: Value(now)),
      );
    });
  }

  /// Full transaction history (newest first) for a customer.
  Stream<List<CustomerTransaction>> watchHistory(String customerId) {
    return (_db.select(_db.customerTransactions)
          ..where(
            (t) => t.customerId.equals(customerId) & t.isDeleted.equals(false),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Recompute the cached balance from the ledger (repair / audit).
  Future<double> recompute(String customerId) async {
    final txns =
        await (_db.select(_db.customerTransactions)..where(
              (t) =>
                  t.customerId.equals(customerId) & t.isDeleted.equals(false),
            ))
            .get();
    double bal = 0.0;
    for (final t in txns) {
      bal += t.type == 'payment' ? -t.amount : t.amount;
    }
    await (_db.update(_db.customers)..where((t) => t.id.equals(customerId)))
        .write(CustomersCompanion(balance: Value(bal)));
    return bal;
  }
}
