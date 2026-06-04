// lib/features/customers/screens/customer_detail_screen.dart
// Khata view with shopkeeper-friendly signs:
//   • Owes udhaar  → shown as NEGATIVE (− Rs. X), warning color
//   • Advance/credit (paid extra) → shown as POSITIVE (+ Rs. X), info color
//   • Settled → "Account clear"
//
// NOTE: storage is unchanged — internally `balance > 0` still means "owes".
// We only flip the DISPLAY sign so it reads the way a shopkeeper expects.
// Overpayment is now allowed (the surplus becomes advance credit).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../core/constants/views.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final ledger = CustomerLedger(db);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
      child: Container(
        width: 90.w.clamp(380.0, 560.0),
        height: 80.h,
        padding: EdgeInsets.all(2.5.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 5.w,
                  height: 5.w,
                  constraints: const BoxConstraints(
                    maxWidth: 44,
                    maxHeight: 44,
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: D.brand50,
                    border: Border.all(color: D.brand100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    customer.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: D.brand600,
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Instrument Serif',
                          fontSize: 15.sp,
                          color: D.ink800,
                        ),
                      ),
                      if (customer.phone != null)
                        Text(
                          customer.phone!,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10.sp,
                            color: D.fgTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),

            // Balance card — live, with flipped display signs
            StreamBuilder<Customer?>(
              stream: (db.select(
                db.customers,
              )..where((t) => t.id.equals(customer.id))).watchSingleOrNull(),
              builder: (_, snap) {
                final bal = snap.data?.balance ?? customer.balance;
                // internal: >0 owes, <0 advance. Display flips the sign.
                final owes = bal > 0;
                final hasAdvance = bal < 0;

                final (bg, border, fg, caption, amountStr) = owes
                    ? (
                        D.warning50,
                        D.warning500,
                        D.warning500,
                        'Outstanding (udhaar)',
                        '− Rs. ${Fmt.pkrShort(bal.abs())}',
                      )
                    : hasAdvance
                    ? (
                        D.brand50,
                        D.brand500,
                        D.brand600,
                        'Advance / credit in hand',
                        '+ Rs. ${Fmt.pkrShort(bal.abs())}',
                      )
                    : (
                        D.success50,
                        D.success500,
                        D.success700,
                        'Account clear',
                        'Rs. 0',
                      );

                return Container(
                  padding: EdgeInsets.all(2.5.w),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.sp,
                                color: D.fgSecondary,
                              ),
                            ),
                            SizedBox(height: 0.4.h),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                amountStr,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 2.w),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _recordPayment(context, ref, ledger, bal),
                        icon: Icon(Icons.payments_rounded, size: 13.sp),
                        label: Text(
                          'New Receiving',
                          style: TextStyle(fontSize: 10.sp),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: D.brand500,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 1.w,
                            vertical: 0.5.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 2.h),

            Text(
              'TRANSACTION HISTORY',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
                color: D.gold600,
                letterSpacing: 0.14,
              ),
            ),
            SizedBox(height: 1.h),

            Expanded(
              child: StreamBuilder<List<CustomerTransaction>>(
                stream: ledger.watchHistory(customer.id),
                builder: (_, snap) {
                  final txns = snap.data ?? [];
                  if (txns.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 22.sp,
                            color: D.fgTertiary,
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            'No transactions yet',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.sp,
                              color: D.fgTertiary,
                            ),
                          ),
                          SizedBox(height: 0.4.h),
                          Text(
                            'Credit sales and payments will appear here.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.5.sp,
                              color: D.fgTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: txns.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: D.borderSubtle),
                    itemBuilder: (_, i) => _TxnRow(txn: txns[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    CustomerLedger ledger,
    double balance,
  ) async {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final owes = balance > 0;

    final result = await showDialog<({double amount, String? note})>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: D.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            title: Text(
              'New Receiving',
              style: TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 16.sp,
                color: D.ink800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current status (flipped sign)
                Text(
                  owes
                      ? 'Owes: Rs. ${Fmt.pkrShort(balance.abs())}'
                      : balance < 0
                      ? 'Already in credit: Rs. ${Fmt.pkrShort(balance.abs())}'
                      : 'Account is clear',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.sp,
                    color: D.fgTertiary,
                  ),
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: amtCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount received',
                    prefixText: 'Rs. ',
                    errorText: error,
                  ),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 18,
                  ),
                  onChanged: (_) => setLocal(() => error = null),
                ),
                SizedBox(height: 0.6.h),
                // Live hint: how this payment lands (pays udhaar / becomes advance)
                Builder(
                  builder: (_) {
                    final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
                    if (amt <= 0) return const SizedBox.shrink();
                    // new internal balance = balance - amt
                    final newBal = balance - amt;
                    final msg = newBal > 0
                        ? 'Still owing after this: Rs. ${Fmt.pkrShort(newBal)}'
                        : newBal < 0
                        ? 'Becomes advance credit: Rs. ${Fmt.pkrShort(newBal.abs())}'
                        : 'Clears the account';
                    return Text(
                      msg,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5.sp,
                        color: newBal < 0 ? Colors.green : D.fgTertiary,
                      ),
                    );
                  },
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: noteCtrl,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Cash, JazzCash, advance for next order',
                  ),
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12.sp),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
                  if (amt <= 0) {
                    setLocal(() => error = 'Enter an amount greater than 0');
                    return;
                  }
                  // Overpayment IS allowed now — surplus becomes advance credit.
                  Navigator.pop(ctx, (
                    amount: amt,
                    note: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                  ));
                },
                child: const Text('Record'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      successMessage: 'Received Rs. ${Fmt.pkrShort(result.amount)}',
      action: () async {
        final tenantId = ref.read(currentTenantIdProvider);
        await ledger.recordPayment(
          tenantId: tenantId,
          customerId: customer.id,
          amount: result.amount,
          note: result.note ?? 'Payment received',
        );
        ref
            .read(syncEngineProvider)
            .enqueue(
              entityType: 'customers',
              entityId: customer.id,
              operation: 'update',
              payload: {
                'id': customer.id,
                'payment': result.amount,
                'note': result.note,
              },
            );
      },
    );
  }
}

class _TxnRow extends StatelessWidget {
  final CustomerTransaction txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    // Money IN (payment) → good for customer → '+' and credit color.
    // Sale (udhaar taken) → increases what they owe → '−' and warning color.
    final isPayment = txn.type == 'payment';
    final color = isPayment ? D.success700 : D.warning500;
    final sign = isPayment ? '+' : '−';
    final label = switch (txn.type) {
      'payment' => 'Payment received',
      'sale' => 'Credit sale (udhaar)',
      _ => 'Adjustment',
    };
    final date = DateTime.fromMillisecondsSinceEpoch(txn.createdAt);
    final hasNote = txn.note != null && txn.note!.trim().isNotEmpty;

    // Display balance flips sign: internal >0 owes shows as negative.
    final dispBal = -txn.balanceAfter;
    final balStr = dispBal == 0
        ? 'Rs. 0'
        : dispBal > 0
        ? '+ Rs. ${Fmt.pkrShort(dispBal.abs())}'
        : '− Rs. ${Fmt.pkrShort(dispBal.abs())}';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.2.h, horizontal: 1.w),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 4.w,
            constraints: const BoxConstraints(
              maxWidth: 34,
              maxHeight: 34,
              minWidth: 26,
              minHeight: 26,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPayment
                  ? const Color.fromARGB(154, 11, 107, 67)
                  : D.warning50,
            ),
            alignment: Alignment.center,
            child: Icon(
              isPayment ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 11.sp,
              color: color,
            ),
          ),
          SizedBox(width: 1.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: D.fgPrimary,
                  ),
                ),
                Text(
                  hasNote
                      ? '${date.day}/${date.month}/${date.year} · ${txn.note}'
                      : '${date.day}/${date.month}/${date.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9.sp,
                    color: D.fgTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 1.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign Rs. ${Fmt.pkrShort(txn.amount)}',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                'Bal $balStr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9.5.sp,
                  color: D.fgTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
