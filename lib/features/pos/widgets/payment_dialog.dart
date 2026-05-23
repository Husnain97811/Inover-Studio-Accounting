// lib/features/pos/widgets/payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class PaymentDialog extends StatefulWidget {
  final CartState cart;
  final Future<void> Function(CartState cart, String mode, double paid) onConfirm;

  const PaymentDialog({super.key, required this.cart, required this.onConfirm});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _mode      = 'cash';
  final _amtCtrl    = TextEditingController();
  bool  _processing = false;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.cart.totalWithTax.toStringAsFixed(2);
  }

  @override
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  double get _paid   => double.tryParse(_amtCtrl.text) ?? widget.cart.totalWithTax;
  double get _change => _paid - widget.cart.totalWithTax;

  Future<void> _confirm() async {
    if (_mode != 'credit' && _paid < widget.cart.totalWithTax) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Amount paid is less than total'),
        backgroundColor: SemColor.error));
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

  @override
  Widget build(BuildContext context) {
    final t     = Theme.of(context);
    final total = widget.cart.totalWithTax;

    return Dialog(
      child: SizedBox(
        width: 440,
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Header
              Row(children: [
                const Icon(Icons.payments_rounded, size: 22),
                const SizedBox(width: 10),
                Text('Process Payment', style: t.textTheme.headlineLarge),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 20),

              // Total due
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        t.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Due',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(Fmt.pkr(total), style: TextStyle(
                      fontFamily: 'monospace', fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: t.colorScheme.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment mode chips
              Text('Payment Mode', style: t.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _ModeChip('cash',   'Cash',   Icons.payments_rounded,           _mode, _setMode),
                _ModeChip('card',   'Card',   Icons.credit_card_rounded,        _mode, _setMode),
                _ModeChip('online', 'Online', Icons.phone_android_rounded,      _mode, _setMode),
                _ModeChip('credit', 'Credit', Icons.account_balance_wallet_rounded, _mode, _setMode,
                    color: SemColor.warning),
              ]),
              const SizedBox(height: 16),

              // Cash input
              if (_mode == 'cash') ...[
                Text('Amount Received', style: t.textTheme.labelSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller:       _amtCtrl,
                  autofocus:        true,
                  keyboardType:     const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:  [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: const InputDecoration(
                    prefixText: 'PKR ',
                    prefixStyle: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 18, fontWeight: FontWeight.w700),
                  onChanged:        (_) => setState(() {}),
                  onFieldSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 10),

                // Quick amounts
                Wrap(spacing: 8, children: _quickAmounts(total).map((a) =>
                  OutlinedButton(
                    onPressed: () => setState(() => _amtCtrl.text = a.toStringAsFixed(0)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    child: Text(Fmt.pkrShort(a),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  )
                ).toList()),
                const SizedBox(height: 10),

                // Change
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_change >= 0 ? SemColor.success : SemColor.error).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Change', style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _change >= 0 ? SemColor.success : SemColor.error)),
                      Text(Fmt.pkr(_change.abs()), style: TextStyle(
                          fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w900,
                          color: _change >= 0 ? SemColor.success : SemColor.error)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _processing ? null : _confirm,
                icon:  const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(_mode == 'credit' ? 'Save as Credit (Udhaar)' : 'Confirm Payment',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ]),
          ),
          if (_processing)
            Positioned.fill(child: Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            )),
        ]),
      ),
    );
  }

  void _setMode(String m) => setState(() {
    _mode = m;
    if (m != 'cash') _amtCtrl.text = widget.cart.totalWithTax.toStringAsFixed(2);
  });

  List<double> _quickAmounts(double total) {
    final r = <double>{};
    r.add((total / 100).ceil() * 100.0);
    r.add((total / 500).ceil() * 500.0);
    r.add((total / 1000).ceil() * 1000.0);
    return r.where((a) => a >= total).toList()..sort();
  }
}

class _ModeChip extends StatelessWidget {
  final String   value, label;
  final IconData icon;
  final String   current;
  final void Function(String) onTap;
  final Color?   color;

  const _ModeChip(this.value, this.label, this.icon, this.current, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) {
    final c   = color ?? Theme.of(context).colorScheme.primary;
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        sel ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: sel ? c : Colors.grey, width: sel ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: sel ? c : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? c : Colors.grey)),
        ]),
      ),
    );
  }
}
