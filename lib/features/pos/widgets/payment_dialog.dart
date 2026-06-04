// lib/features/pos/widgets/payment_dialog.dart
// Full replacement. Adds PARTIAL credit payment: in credit mode you can enter
// any amount paid now (0 = full udhaar), and the rest goes on the customer's
// khata. Live split shows "Paying now" vs "Goes on udhaar".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';

class PaymentDialog extends StatefulWidget {
  final CartState cart;
  final Future<void> Function(CartState cart, String mode, double paid)
  onConfirm;

  const PaymentDialog({super.key, required this.cart, required this.onConfirm});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _mode = 'cash';
  final _amtCtrl = TextEditingController();
  bool _processing = false;

  bool get _canCredit => widget.cart.hasCustomer;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.cart.totalWithTax.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  double get _paid =>
      double.tryParse(_amtCtrl.text) ?? widget.cart.totalWithTax;
  double get _change => _paid - widget.cart.totalWithTax;

  Future<void> _confirm() async {
    final total = widget.cart.totalWithTax;

    if (_mode == 'credit' && !_canCredit) {
      _snack('Attach a customer to sell on credit (udhaar)');
      return;
    }
    // Cash/card/online must cover the full total.
    if (_mode != 'credit' && _paid < total) {
      _snack('Amount paid is less than total');
      return;
    }
    // Credit: amount paid now must be between 0 and total.
    if (_mode == 'credit' && _paid > total) {
      _snack('Paying more than the total — use Cash instead');
      return;
    }
    setState(() => _processing = true);
    try {
      await widget.onConfirm(widget.cart, _mode, _paid);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: SemColor.error));

  void _setMode(String m) => setState(() {
    _mode = m;
    if (m == 'credit') {
      _amtCtrl.text = '0'; // default full udhaar; user can type a part payment
    } else {
      _amtCtrl.text = widget.cart.totalWithTax.toStringAsFixed(2);
    }
  });

  List<double> _quickAmounts(double total) {
    final r = <double>{};
    r.add((total / 100).ceil() * 100.0);
    r.add((total / 500).ceil() * 500.0);
    r.add((total / 1000).ceil() * 1000.0);
    return r.where((a) => a >= total).toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = widget.cart.totalWithTax;
    final dialogW = 90.w.clamp(420.0, 460.0);

    // Live split for credit mode
    final payingNow = _paid.clamp(0, total).toDouble();
    final onUdhaar = (total - payingNow).clamp(0, total).toDouble();

    return Dialog(
      child: SizedBox(
        width: dialogW,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(3.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.payments_rounded, size: 18.sp),
                      SizedBox(width: 1.5.w),
                      Text('Process Payment', style: t.textTheme.headlineLarge),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),

                  // Customer line
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: widget.cart.hasCustomer
                          ? SemColor.success.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.cart.hasCustomer
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          size: 13.sp,
                          color: widget.cart.hasCustomer
                              ? SemColor.success
                              : Colors.grey,
                        ),
                        SizedBox(width: 1.5.w),
                        Expanded(
                          child: Text(
                            widget.cart.hasCustomer
                                ? widget.cart.customerName!
                                : 'Walk-in customer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 1.5.h),

                  // Total due
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Due',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            Fmt.pkr(total),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: t.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),

                  // Payment mode chips
                  Text('Payment Mode', style: t.textTheme.labelSmall),
                  SizedBox(height: 1.h),
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: [
                      _ModeChip(
                        'cash',
                        'Cash',
                        Icons.payments_rounded,
                        _mode,
                        _setMode,
                      ),
                      _ModeChip(
                        'card',
                        'Card',
                        Icons.credit_card_rounded,
                        _mode,
                        _setMode,
                      ),
                      _ModeChip(
                        'online',
                        'Online',
                        Icons.phone_android_rounded,
                        _mode,
                        _setMode,
                      ),
                      _ModeChip(
                        'credit',
                        'Credit',
                        Icons.account_balance_wallet_rounded,
                        _mode,
                        _canCredit ? _setMode : null,
                        color: SemColor.warning,
                        disabled: !_canCredit,
                      ),
                    ],
                  ),

                  if (!_canCredit) ...[
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 11.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 1.w),
                        Expanded(
                          child: Text(
                            'Attach a customer (F2) to sell on credit (udhaar).',
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 2.h),

                  // ── CASH MODE ──
                  if (_mode == 'cash') ...[
                    Text('Amount Received', style: t.textTheme.labelSmall),
                    SizedBox(height: 1.h),
                    TextFormField(
                      controller: _amtCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: const InputDecoration(
                        prefixText: 'PKR ',
                        prefixStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _confirm(),
                    ),
                    SizedBox(height: 1.2.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: _quickAmounts(total)
                          .map(
                            (a) => OutlinedButton(
                              onPressed: () => setState(
                                () => _amtCtrl.text = a.toStringAsFixed(0),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 2.w,
                                  vertical: 1.h,
                                ),
                              ),
                              child: Text(
                                Fmt.pkrShort(a),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.sp,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 1.2.h),
                    Container(
                      padding: EdgeInsets.all(1.5.w),
                      decoration: BoxDecoration(
                        color:
                            (_change >= 0 ? SemColor.success : SemColor.error)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: _change >= 0
                                  ? SemColor.success
                                  : SemColor.error,
                            ),
                          ),
                          Text(
                            Fmt.pkr(_change.abs()),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              color: _change >= 0
                                  ? SemColor.success
                                  : SemColor.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── CREDIT MODE — partial payment + live split ──
                  if (_mode == 'credit' && _canCredit) ...[
                    Text(
                      'Paying now (cash part)',
                      style: t.textTheme.labelSmall,
                    ),
                    SizedBox(height: 1.h),
                    TextFormField(
                      controller: _amtCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: const InputDecoration(
                        prefixText: 'PKR ',
                        helperText:
                            'Enter 0 for full udhaar, or a part payment',
                      ),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: 1.2.h),
                    Container(
                      padding: EdgeInsets.all(1.5.w),
                      decoration: BoxDecoration(
                        color: SemColor.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Paying now',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                Fmt.pkr(payingNow),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: SemColor.success,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 0.6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Goes on udhaar',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: SemColor.warning,
                                ),
                              ),
                              Text(
                                Fmt.pkr(onUdhaar),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w900,
                                  color: SemColor.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 2.5.h),

                  ElevatedButton.icon(
                    onPressed: _processing ? null : _confirm,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _mode == 'credit'
                          ? (onUdhaar >= total
                                ? 'Save as Credit (Udhaar)'
                                : 'Save (part paid + udhaar)')
                          : 'Confirm Payment',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.6.h),
                    ),
                  ),
                ],
              ),
            ),
            if (_processing)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final String current;
  final void Function(String)? onTap;
  final Color? color;
  final bool disabled;

  const _ModeChip(
    this.value,
    this.label,
    this.icon,
    this.current,
    this.onTap, {
    this.color,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final sel = current == value;
    final base = disabled
        ? Colors.grey.withOpacity(0.4)
        : (sel ? c : Colors.grey);

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onTap?.call(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: sel ? c.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: base, width: sel ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.sp, color: base),
              SizedBox(width: 1.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: base,
                ),
              ),
              if (disabled) ...[
                SizedBox(width: 0.6.w),
                Icon(Icons.lock_outline_rounded, size: 10.sp, color: base),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
