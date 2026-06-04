// lib/features/invoices/screens/invoices_screen.dart
//
// Full invoice history screen — wired to dashboard "View all".
// - Live Drift stream of invoices for the tenant
// - Search (invoice number) + FBR-status filter chips
// - Date-range aware (today / 7d / 30d / all)
// - Row tap → receipt sheet (view / WhatsApp / save PDF) + amendment guard
// Matches the app: PageHeader, ErpCard, gold-header table, sizer, responsive.

import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:is_accounting/core/theme/app_theme.dart';
import 'package:is_accounting/features/fbr/receipt_actions.dart';
import 'package:is_accounting/features/fbr/receipt_mapper.dart';
import 'package:is_accounting/features/fbr/receipt_share.dart';
import 'package:sizer/sizer.dart';

import '../../../core/constants/views.dart';
import '../../fbr/receipt_view.dart';

enum _Range { today, week, month, all }

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});
  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _q = '';
  String _statusFilter = 'all'; // all | verified | pending | failed | rejected
  _Range _range = _Range.today;

  bool _inRange(DateTime d) {
    final now = DateTime.now();
    return switch (_range) {
      _Range.today =>
        d.year == now.year && d.month == now.month && d.day == now.day,
      _Range.week => d.isAfter(now.subtract(const Duration(days: 7))),
      _Range.month => d.isAfter(now.subtract(const Duration(days: 30))),
      _Range.all => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            eyebrow: 'Sales History',
            title: 'Invoices',
            subtitle: 'Search, review, and re-share fiscalized invoices',
          ),

          // Filters row
          Padding(
            padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 1.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12.sp),
                        decoration: const InputDecoration(
                          hintText: 'Search invoice number…',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: D.fgTertiary,
                          ),
                        ),
                        onChanged: (v) => setState(() => _q = v.toLowerCase()),
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    _RangeDropdown(
                      range: _range,
                      onChanged: (r) => setState(() => _range = r),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 0.6.w,
                    children: [
                      for (final s in const [
                        'all',
                        'verified',
                        'pending',
                        'failed',
                        'rejected',
                      ])
                        _FilterChip(
                          label: s,
                          selected: _statusFilter == s,
                          onTap: () => setState(() => _statusFilter = s),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: StreamBuilder<List<Invoice>>(
              stream:
                  (db.select(db.invoices)
                        ..where((t) => t.tenantId.equals(tenantId))
                        ..orderBy([
                          (t) => OrderingTerm(
                            expression: t.invoiceDate,
                            mode: OrderingMode.desc,
                          ),
                        ]))
                      .watch(),
              builder: (_, snap) {
                final all = snap.data ?? [];
                final filtered = all.where((inv) {
                  if (!_inRange(inv.invoiceDate)) return false;
                  if (_statusFilter != 'all' && inv.fbrStatus != _statusFilter)
                    return false;
                  if (_q.isNotEmpty &&
                      !inv.invoiceNumber.toLowerCase().contains(_q)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices',
                    message: _q.isNotEmpty
                        ? 'No invoices match "$_q".'
                        : 'No invoices in this period.',
                  );
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 4.h),
                  child: ErpCard(
                    padding: EdgeInsets.zero,
                    child: _InvoiceTable(
                      invoices: filtered,
                      onOpen: _openReceipt,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReceipt(Invoice inv) async {
    final db = ref.read(databaseProvider);
    final prefs = ref.read(prefsProvider);
    final items = await (db.select(
      db.invoiceItems,
    )..where((t) => t.invoiceId.equals(inv.id))).get();
    final data = ReceiptMapper.fromInvoice(
      invoice: inv,
      items: items,
      prefs: prefs,
    );

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReceiptSheet(invoice: inv, data: data),
    );
  }
}

// ── Receipt bottom sheet with actions ─────────────────────
class _ReceiptSheet extends StatelessWidget {
  final Invoice invoice;
  final dynamic data; // ReceiptData
  const _ReceiptSheet({required this.invoice, required this.data});

  @override
  Widget build(BuildContext context) {
    final amend = AmendmentGuard.forInvoice(invoice);
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: const BoxDecoration(
        color: D.bgApp,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                color: D.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ReceiptView(data: data),
            SizedBox(height: 2.h),
            // Action buttons
            Wrap(
              spacing: 1.w,
              runSpacing: 1.h,
              alignment: WrapAlignment.center,
              children: [
                _ActionBtn(
                  icon: Icons.print_rounded,
                  label: 'Print',
                  onTap: () => ReceiptActions.printOrFallback(context, data),
                ),
                _ActionBtn(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  onTap: () => ReceiptShare.shareToWhatsApp(data),
                ),
                _ActionBtn(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'Save PDF',
                  onTap: () => ReceiptActions.savePdf(data),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [AmendmentGuard.statusChip(invoice)],
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: D.bgSurface,
      foregroundColor: D.fgPrimary,
      elevation: 0,
      side: const BorderSide(color: D.borderDefault),
    ),
  );
}

// ── The table ─────────────────────────────────────────────
class _InvoiceTable extends StatelessWidget {
  final List<Invoice> invoices;
  final void Function(Invoice) onOpen;
  const _InvoiceTable({required this.invoices, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final showCustomer = c.maxWidth > 640;
        final showTime = c.maxWidth > 460;

        final headers = <String>[
          'Invoice',
          if (showCustomer) 'Customer',
          'FBR',
          'Total',
          if (showTime) 'Date',
          '',
        ];

        final widths = <int, TableColumnWidth>{};
        var idx = 0;
        widths[idx++] = const FlexColumnWidth(2.4); // invoice
        if (showCustomer) widths[idx++] = const FlexColumnWidth(2);
        widths[idx++] = const FlexColumnWidth(1.4); // fbr
        widths[idx++] = const FlexColumnWidth(1.6); // total
        if (showTime) widths[idx++] = const FlexColumnWidth(1.8); // date
        widths[idx] = const FixedColumnWidth(44); // chevron

        return Table(
          columnWidths: widths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: D.bgCream),
              children: [
                for (final h in headers)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 1.4.w,
                      vertical: 1.2.h,
                    ),
                    child: Text(
                      h.toUpperCase(),
                      textAlign: (h == 'Total')
                          ? TextAlign.right
                          : TextAlign.left,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        color: D.gold600,
                        letterSpacing: 0.12,
                      ),
                    ),
                  ),
              ],
            ),
            ...invoices.map((inv) {
              final cells = <Widget>[];
              cells.add(
                _cell(
                  Text(
                    inv.invoiceNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11.sp,
                      color: D.fgSecondary,
                    ),
                  ),
                ),
              );
              if (showCustomer) {
                cells.add(
                  _cell(
                    Text(
                      'Walk-in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: D.fgPrimary,
                      ),
                    ),
                  ),
                );
              }
              cells.add(_cell(StatusBadge.fbr(inv.fbrStatus)));
              cells.add(
                _cell(
                  Text(
                    'Rs. ${Fmt.pkrShort(inv.totalWithTax)}',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: D.fgPrimary,
                    ),
                  ),
                  align: Alignment.centerRight,
                ),
              );
              if (showTime) {
                cells.add(
                  _cell(
                    Text(
                      _fmtDate(inv.invoiceDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11.sp,
                        color: D.fgSecondary,
                      ),
                    ),
                  ),
                );
              }
              cells.add(
                _cell(
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: D.fgTertiary,
                  ),
                  align: Alignment.center,
                ),
              );

              // Whole row tappable
              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: D.borderSubtle, width: 1),
                  ),
                ),
                children: cells
                    .map(
                      (w) =>
                          TableRowInkWell(onTap: () => onOpen(inv), child: w),
                    )
                    .toList(),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _cell(Widget child, {Alignment align = Alignment.centerLeft}) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 1.4.w, vertical: 1.3.h),
        child: Align(alignment: align, child: child),
      );

  static String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final t =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today $t';
    return '${d.day}/${d.month} $t';
  }
}

// ── Small filter widgets ──────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(horizontal: 1.2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: selected ? D.gold50 : D.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? D.gold400 : D.borderDefault,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5.sp,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? D.gold600 : D.fgSecondary,
        ),
      ),
    ),
  );
}

class _RangeDropdown extends StatelessWidget {
  final _Range range;
  final void Function(_Range) onChanged;
  const _RangeDropdown({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Range.today: 'Today',
      _Range.week: 'Last 7 days',
      _Range.month: 'Last 30 days',
      _Range.all: 'All time',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.2.w),
      decoration: BoxDecoration(
        color: D.bgSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: D.borderDefault),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Range>(
          value: range,
          isDense: true,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.sp,
            color: D.fgPrimary,
          ),
          items: [
            for (final e in labels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}
