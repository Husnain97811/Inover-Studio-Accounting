// lib/features/pos/widgets/discount_dialog.dart
//
// Whole-cart discount entry. Owner = unlimited; others capped at 30%
// (enforced by DiscountPolicy). Accepts the value as % OR rupees.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' show UserRole;
import '../../../core/pos/discount_policy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/app_providers.dart';

class DiscountDialog extends ConsumerStatefulWidget {
  final double base; // itemsTotal the discount applies to
  const DiscountDialog({super.key, required this.base});
  @override
  ConsumerState<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<DiscountDialog> {
  bool _isPercent = true;
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final role = ref.read(currentRoleProvider);
    final raw = double.tryParse(_ctrl.text.trim()) ?? 0;
    if (raw <= 0) {
      Navigator.pop(context);
      return;
    }

    final rupees = _isPercent
        ? DiscountPolicy.resolvePercent(
            role: role,
            percent: raw,
            base: widget.base,
          )
        : DiscountPolicy.resolveRupees(
            role: role,
            rupees: raw,
            base: widget.base,
          );

    // Warn if it was clamped (non-owner exceeding 30%)
    final requested = _isPercent ? widget.base * raw / 100 : raw;
    if (!DiscountPolicy.isAllowed(
      role: role,
      rupees: requested,
      base: widget.base,
    )) {
      setState(
        () => _error =
            'Capped to ${DiscountPolicy.capLabel(role)}. Applied the maximum allowed.',
      );
    }

    ref.read(cartProvider.notifier).setCartDiscount(rupees);
    if (_error == null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    return Dialog(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Cart Discount',
                  style: TextStyle(
                    fontFamily: 'Instrument Serif',
                    fontSize: 20,
                    color: D.ink800,
                  ),
                ),
                const Spacer(),
                Text(
                  DiscountPolicy.capLabel(role),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: D.fgTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // % / Rs. toggle
            Row(
              children: [
                _ModeChip(
                  label: 'Percent %',
                  selected: _isPercent,
                  onTap: () => setState(() => _isPercent = true),
                ),
                const SizedBox(width: 8),
                _ModeChip(
                  label: 'Rupees Rs.',
                  selected: !_isPercent,
                  onTap: () => setState(() => _isPercent = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 16,
              ),
              decoration: InputDecoration(
                prefixText: _isPercent ? '' : 'Rs. ',
                suffixText: _isPercent ? '%' : '',
                hintText: _isPercent ? 'e.g. 10' : 'e.g. 100',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).setCartDiscount(0);
                    Navigator.pop(context);
                  },
                  child: const Text('Remove'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _apply, child: const Text('Apply')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? D.gold50 : D.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? D.gold400 : D.borderDefault,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? D.gold600 : D.fgSecondary,
          ),
        ),
      ),
    ),
  );
}
