// lib/shared/widgets/common_widgets.dart
// Design: Inover Studio ERP
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants/app_constants.dart';
import '../providers/app_providers.dart';

// ─────────────────────────────────────────────────
//  CARD PANEL  (replaces old ErpCard)
// ─────────────────────────────────────────────────
class ErpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool goldRule; // top border accent
  final bool goldCorner; // corner L-shape accent
  final bool cream; // cream background variant

  const ErpCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.goldRule = false,
    this.goldCorner = false,
    this.cream = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: cream ? D.bgCream : D.bgSurface,
          border: Border.all(color: D.borderDefault), // uniform border
          boxShadow: const [
            BoxShadow(
              color: Color(0x060A1A11),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Color(0x040A1A11),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gold rule – drawn as a thin overlay, clipped to the rounded corners
            if (goldRule)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(height: 2, color: D.gold400),
              ),
            if (goldCorner) ...[
              Positioned(
                top: 0,
                left: 0,
                child: Container(width: 28, height: 1, color: D.gold400),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(width: 1, height: 28, color: D.gold400),
              ),
            ],
            if (onTap != null)
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onTap,
                  hoverColor: const Color(0x06C49A4A),
                  child: content,
                ),
              )
            else
              content,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  KPI STAT CARD
// ─────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String? delta;
  final bool deltaUp;
  final Widget? spark;
  final Widget? extra;
  final bool goldVariant;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.delta,
    this.deltaUp = true,
    this.spark,
    this.extra,
    this.goldVariant = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErpCard(
      goldRule: !goldVariant,
      goldCorner: goldVariant,
      cream: goldVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label — eyebrow style
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: D.gold500,
              letterSpacing: 0.18,
            ),
          ),
          const SizedBox(height: 6),
          // Value — serif display
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 42,
                fontWeight: FontWeight.w400,
                color: D.ink800,
                height: 1.0,
              ),
              children: [
                if (value.startsWith('Rs.') || value.contains('PKR'))
                  TextSpan(
                    text: 'Rs. ',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: D.gold600,
                      letterSpacing: 0,
                      height: 1.0,
                    ),
                  ),
                TextSpan(
                  text: value.replaceAll('Rs. ', '').replaceAll('PKR ', ''),
                ),
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  deltaUp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: deltaUp ? D.brand600 : D.danger700,
                ),
                const SizedBox(width: 3),
                Text(
                  delta!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: deltaUp ? D.brand600 : D.danger700,
                  ),
                ),
              ],
            ),
          ],
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: D.fgTertiary,
              ),
            ),
          ],
          if (spark != null) spark!,
          if (extra != null) ...[const SizedBox(height: 6), extra!],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  STATUS BADGE
// ─────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool dot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.dot = false,
  });

  factory StatusBadge.success(String label) => StatusBadge(
    label: label,
    dot: true,
    color: D.success700,
    bgColor: D.success50,
    borderColor: const Color(0x33116B43),
  );

  factory StatusBadge.warning(String label) => StatusBadge(
    label: label,
    dot: true,
    color: D.warning700,
    bgColor: D.warning50,
    borderColor: const Color(0x3DB07013),
  );

  factory StatusBadge.danger(String label) => StatusBadge(
    label: label,
    dot: true,
    color: D.danger700,
    bgColor: D.danger50,
    borderColor: const Color(0x3D9C2922),
  );

  factory StatusBadge.info(String label) => StatusBadge(
    label: label,
    dot: true,
    color: D.info500,
    bgColor: D.info50,
    borderColor: const Color(0x3D1F4F73),
  );

  factory StatusBadge.neutral(String label) => StatusBadge(
    label: label,
    dot: false,
    color: D.neutral700,
    bgColor: D.neutral100,
    borderColor: D.borderDefault,
  );

  factory StatusBadge.brand(String label) => StatusBadge(
    label: label,
    dot: true,
    color: D.brand700,
    bgColor: D.brand50,
    borderColor: const Color(0x330B6B43),
  );

  factory StatusBadge.gold(String label) => StatusBadge(
    label: label,
    dot: true,
    color: D.gold600,
    bgColor: D.gold50,
    borderColor: D.gold200,
  );

  factory StatusBadge.fbr(String status) {
    return switch (status) {
      'verified' => StatusBadge.success('Fiscalized'),
      'submitted' => StatusBadge.info('Submitted'),
      'failed' => StatusBadge.danger('Failed'),
      'exempt' => StatusBadge.neutral('Exempt'),
      _ => StatusBadge.warning('Queued'),
    };
  }

  factory StatusBadge.payment(String mode) {
    return switch (mode) {
      'card' => StatusBadge.info('Card'),
      'online' => StatusBadge.info('Online'),
      'credit' => StatusBadge.warning('Credit'),
      'cheque' => StatusBadge.neutral('Cheque'),
      _ => StatusBadge.success('Cash'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.06,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  ERP TEXT FIELD  (design system input)
// ─────────────────────────────────────────────────
class ErpField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool obscureText;
  final bool readOnly;
  final Widget? prefix;
  final Widget? suffix;
  final int maxLines;
  final bool required;

  const ErpField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.readOnly = false,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field label
        Text(
          required ? '${label} *' : label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: D.fgSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: D.fgPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
//  PAGE / SCREEN HEADER  (serif display + gold rule)
// ─────────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;
  final String? eyebrow; // small uppercase label above title
  final String? subtitle;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: D.borderGold)),
      ),
      child: Stack(
        children: [
          // Gold rule accent (bottom-left 64px)
          Positioned(
            bottom: -1,
            left: 0,
            child: Container(width: 64, height: 2, color: D.gold400),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eyebrow != null) ...[
                      Row(
                        children: [
                          Container(width: 24, height: 1, color: D.gold400),
                          const SizedBox(width: 10),
                          Text(
                            eyebrow!.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: D.gold500,
                              letterSpacing: 0.18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Instrument Serif',
                          fontSize: 44,
                          fontWeight: FontWeight.w400,
                          color: D.ink800,
                          letterSpacing: -0.018,
                          height: 1.05,
                        ),
                        children: [TextSpan(text: title)],
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: D.fgSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 16),
                Row(
                  children: actions.map((a) {
                    final i = actions.indexOf(a);
                    return i < actions.length - 1
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [a, const SizedBox(width: 8)],
                          )
                        : a;
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  DATA TABLE  (dt style from kit.css)
// ─────────────────────────────────────────────────
class ErpTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<bool>? numericCols; // right-align + mono
  final void Function(int)? onRowTap;

  const ErpTable({
    super.key,
    required this.headers,
    required this.rows,
    this.numericCols,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: {
        for (int i = 0; i < headers.length; i++) i: const FlexColumnWidth(),
      },
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(color: D.bgCream),
          children: headers.asMap().entries.map((e) {
            return TableCell(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: D.borderGold)),
                ),
                child: Text(
                  e.value.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: D.gold600,
                    letterSpacing: 0.14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...rows.asMap().entries.map((rowEntry) {
          final i = rowEntry.key;
          return TableRow(
            children: rowEntry.value.asMap().entries.map((cellEntry) {
              final j = cellEntry.key;
              final isNum = numericCols != null && j < numericCols!.length
                  ? numericCols![j]
                  : false;
              return TableCell(
                child: GestureDetector(
                  onTap: onRowTap != null ? () => onRowTap!(i) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: D.borderSubtle)),
                      color: Colors.transparent,
                    ),
                    alignment: isNum
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: cellEntry.value,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: D.neutral100,
              shape: BoxShape.circle,
              border: Border.all(color: D.borderDefault),
            ),
            child: Icon(icon, size: 32, color: D.fgTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Instrument Serif',
              fontSize: 22,
              color: D.ink800,
              letterSpacing: -0.01,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: D.fgSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  SHORTCUT BAR  (POS keyboard hints)
// ─────────────────────────────────────────────────
class ShortcutBar extends StatelessWidget {
  final List<(String, String)> shortcuts;
  const ShortcutBar({super.key, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: D.bgCream,
        border: Border(top: BorderSide(color: D.borderDefault)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: shortcuts
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KbdWidget(s.$1),
                    const SizedBox(width: 5),
                    Text(
                      s.$2,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: D.fgTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KbdWidget extends StatelessWidget {
  final String label;
  const _KbdWidget(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: D.bgSurface,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: D.borderDefault, width: 1), // uniform border
      boxShadow: const [
        BoxShadow(
          color: D.neutral300, // replaces the darker bottom border
          offset: Offset(0, 1),
          blurRadius: 0,
        ),
      ],
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: D.fgSecondary,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────
//  CONFIRM DIALOG
// ─────────────────────────────────────────────────
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Instrument Serif',
                fontSize: 22,
                color: D.ink800,
                letterSpacing: -0.01,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: D.fgSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor ?? D.brand500,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────
//  INFO BANNER
// ─────────────────────────────────────────────────
class InfoBanner extends StatelessWidget {
  final String message;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const InfoBanner({
    super.key,
    required this.message,
    this.color = D.info500,
    this.bgColor = D.info50,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: color,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  AMOUNT TEXT  (monospace, tabular)
// ─────────────────────────────────────────────────
class AmountText extends StatelessWidget {
  final double amount;
  final double fontSize;
  final Color? color;
  final bool bold;
  final bool showCurrency;

  const AmountText(
    this.amount, {
    super.key,
    this.fontSize = 13,
    this.color,
    this.bold = false,
    this.showCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      showCurrency ? Fmt.pkr(amount) : Fmt.pkrShort(amount),
      style: TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? D.fgPrimary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  GOLD BUTTON  (primary CTA variant)
// ─────────────────────────────────────────────────
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool block;

  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.block = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: block ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 15) : const SizedBox.shrink(),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: D.gold400,
          foregroundColor: D.ink800,
          elevation: 0,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shadowColor: D.gold400.withOpacity(0.3),
        ),
      ),
    );
  }
}
