import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:drift/drift.dart' show OrderingTerm, ComparableExpr, BooleanExpressionOperators;
 
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
 
enum _ReportType { sales, gst, stock, payments }
 
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
 
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}
 
class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportType _report = _ReportType.sales;
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end:   DateTime.now(),
  );
 
  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context:             context,
      firstDate:           DateTime(2020),
      lastDate:            DateTime.now(),
      initialDateRange:    _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: D.gold400, onPrimary: D.ink800),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _range = picked);
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bgApp,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow:  'Analytics',
            title:    'Reports',
            subtitle: 'Sales performance, tax, and inventory analysis',
            actions: [
              GestureDetector(
                onTap: _pickRange,
                child: Container(
                  height: 32,
                  padding: EdgeInsets.symmetric(horizontal: 1.w),
                  decoration: BoxDecoration(
                    color:        D.bgSurface,
                    borderRadius: BorderRadius.circular(4),
                    border:       Border.all(color: D.borderGold),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: D.gold500),
                      SizedBox(width: 0.5.w),
                      Text(
                        '${_range.start.day}/${_range.start.month}/${_range.start.year}'
                        '  –  '
                        '${_range.end.day}/${_range.end.month}/${_range.end.year}',
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12,
                            color: D.gold600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
 
          Container(
            color: D.bgSurface,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                _ReportTab(label: 'Sales Summary', icon: Icons.bar_chart_rounded,
                    active: _report == _ReportType.sales,
                    onTap: () => setState(() => _report = _ReportType.sales)),
                _ReportTab(label: 'FBR / GST', icon: Icons.receipt_long_rounded,
                    active: _report == _ReportType.gst,
                    onTap: () => setState(() => _report = _ReportType.gst)),
                _ReportTab(label: 'Low Stock', icon: Icons.inventory_2_rounded,
                    active: _report == _ReportType.stock,
                    onTap: () => setState(() => _report = _ReportType.stock)),
                _ReportTab(label: 'Payments', icon: Icons.payments_rounded,
                    active: _report == _ReportType.payments,
                    onTap: () => setState(() => _report = _ReportType.payments)),
              ],
            ),
          ),
          const Divider(height: 1),
 
          Expanded(
            child: AnimatedSwitcher(
              duration: 250.ms,
              child: switch (_report) {
                _ReportType.sales    => _SalesReport(range: _range),
                _ReportType.gst      => _GstReport(range: _range),
                _ReportType.stock    => const _StockReport(),
                _ReportType.payments => _PaymentsReport(range: _range),
              },
            ),
          ),
        ],
      ),
    );
  }
}
 
// ─── Sales Summary ────────────────────────────────────────
class _SalesReport extends ConsumerWidget {
  final DateTimeRange range;
  const _SalesReport({required this.range});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db       = ref.watch(databaseProvider);
    final branchId = ref.watch(currentBranchIdProvider);
 
    return FutureBuilder<List<Invoice>>(
      future: (db.select(db.invoices)
            ..where((t) =>
                t.branchId.equals(branchId) &
                t.isDeleted.equals(false) &
                t.invoiceDate.isBiggerOrEqualValue(range.start) &
                t.invoiceDate.isSmallerOrEqualValue(
                    range.end.add(const Duration(days: 1))))
            ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: D.gold400));
        }
        final invoices = snap.data!;
        if (invoices.isEmpty) {
          return const EmptyState(
            icon:    Icons.bar_chart_rounded,
            title:   'No sales in range',
            message: 'Adjust the date range to see data',
          );
        }
 
        final Map<String, _DaySales> byDay = {};
        for (final inv in invoices) {
          final key = '${inv.invoiceDate.year}-'
              '${inv.invoiceDate.month.toString().padLeft(2, '0')}-'
              '${inv.invoiceDate.day.toString().padLeft(2, '0')}';
          byDay[key] ??= _DaySales(date: key);
          byDay[key]!.count++;
          byDay[key]!.revenue  += inv.totalWithTax;
          byDay[key]!.tax      += inv.totalSalesTax;
          byDay[key]!.discount += inv.discountAmount;
        }
        final days         = byDay.values.toList()..sort((a, b) => b.date.compareTo(a.date));
        final totalRevenue  = invoices.fold(0.0, (s, i) => s + i.totalWithTax);
        final totalTax      = invoices.fold(0.0, (s, i) => s + i.totalSalesTax);
        final totalDiscount = invoices.fold(0.0, (s, i) => s + i.discountAmount);
 
        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Total Revenue',       value: Fmt.pkr(totalRevenue),  goldVariant: true)),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(label: 'Invoices',            value: invoices.length.toString())),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(label: 'Sales Tax Collected', value: Fmt.pkr(totalTax))),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(label: 'Total Discounts',     value: Fmt.pkr(totalDiscount))),
                ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.05),
              ),
              SizedBox(height: 2.h),
              ErpCard(
                goldRule: true,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(1.5.w),
                      child: const Text('Daily Breakdown',
                        style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 18, color: D.ink800)),
                    ),
                    const Divider(height: 1, color: D.borderSubtle),
                    ErpTable(
                      headers: const ['Date', 'Invoices', 'Revenue', 'Tax', 'Discount'],
                      numericCols: const [false, true, true, true, true],
                      rows: days.map((d) => [
                        Text(d.date,
                          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: D.fgPrimary)),
                        Text(d.count.toString(),
                          style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: D.fgSecondary)),
                        AmountText(d.revenue,  fontSize: 12),
                        AmountText(d.tax,      fontSize: 12),
                        AmountText(d.discount, fontSize: 12),
                      ]).toList(),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
            ],
          ),
        );
      },
    );
  }
}
 
class _DaySales {
  final String date;
  int count = 0;
  double revenue = 0, tax = 0, discount = 0;
  _DaySales({required this.date});
}
 
// ─── FBR / GST Report ─────────────────────────────────────
class _GstReport extends ConsumerWidget {
  final DateTimeRange range;
  const _GstReport({required this.range});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db       = ref.watch(databaseProvider);
    final branchId = ref.watch(currentBranchIdProvider);
 
    return FutureBuilder<List<Invoice>>(
      future: (db.select(db.invoices)
            ..where((t) =>
                t.branchId.equals(branchId) &
                t.isDeleted.equals(false) &
                t.invoiceDate.isBiggerOrEqualValue(range.start) &
                t.invoiceDate.isSmallerOrEqualValue(
                    range.end.add(const Duration(days: 1)))))
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: D.gold400));
        }
        final invoices = snap.data!;
 
        final Map<String, _MonthGst> byMonth = {};
        for (final inv in invoices) {
          final key = '${inv.invoiceDate.year}-'
              '${inv.invoiceDate.month.toString().padLeft(2, '0')}';
          byMonth[key] ??= _MonthGst(month: key);
          byMonth[key]!.taxable    += inv.taxableAmount;
          byMonth[key]!.gst        += inv.totalSalesTax;
          byMonth[key]!.invoices++;
          if (inv.fbrStatus == 'verified') byMonth[key]!.fiscalized++;
        }
        final months   = byMonth.values.toList()..sort((a, b) => b.month.compareTo(a.month));
        final totalGst  = invoices.fold(0.0, (s, i) => s + i.totalSalesTax);
        final fiscalized = invoices.where((i) => i.fbrStatus == 'verified').length;
 
        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Total GST Collected', value: Fmt.pkr(totalGst), goldVariant: true)),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(label: 'Fiscalized',   value: fiscalized.toString(), sub: 'Verified by FBR')),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(
                    label: 'Pending / Failed',
                    value: invoices.where((i) =>
                        i.fbrStatus == 'pending' || i.fbrStatus == 'failed').length.toString(),
                  )),
                ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.05),
              ),
              SizedBox(height: 2.h),
              ErpCard(
                goldRule: true,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(1.5.w),
                      child: const Text('Monthly GST Summary',
                        style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 18, color: D.ink800)),
                    ),
                    const Divider(height: 1, color: D.borderSubtle),
                    if (months.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No data',
                          style: TextStyle(color: D.fgTertiary))),
                      )
                    else
                      ErpTable(
                        headers: const ['Month', 'Invoices', 'Taxable Amount', 'GST', 'Fiscalized'],
                        numericCols: const [false, true, true, true, true],
                        rows: months.map((m) => [
                          Text(m.month,
                            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: D.fgPrimary)),
                          Text(m.invoices.toString(),
                            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: D.fgSecondary)),
                          AmountText(m.taxable, fontSize: 12),
                          AmountText(m.gst, fontSize: 12, color: D.brand600),
                          Text('${m.fiscalized}/${m.invoices}',
                            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12,
                                color: m.fiscalized == m.invoices ? D.brand600 : D.warning700)),
                        ]).toList(),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
            ],
          ),
        );
      },
    );
  }
}
 
class _MonthGst {
  final String month;
  double taxable = 0, gst = 0;
  int invoices = 0, fiscalized = 0;
  _MonthGst({required this.month});
}
 
// ─── Low Stock Report ─────────────────────────────────────
class _StockReport extends ConsumerWidget {
  const _StockReport();
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db       = ref.watch(databaseProvider);
    final branchId = ref.watch(currentBranchIdProvider);
 
    return StreamBuilder<List<InventoryData>>(
      stream: (db.select(db.inventory)..where((t) => t.branchId.equals(branchId))).watch(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: D.gold400));
        }
        final all      = snap.data!;
        final lowStock  = all.where((i) => i.qtyOnHand <= i.reorderLevel).toList();
        final outOfStock = all.where((i) => i.qtyOnHand <= 0).toList();
 
        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Total SKUs',  value: all.length.toString())),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(label: 'Low Stock',   value: lowStock.length.toString(),
                      sub: 'At or below reorder level', goldVariant: true)),
                  SizedBox(width: 1.5.w),
                  Expanded(child: StatCard(label: 'Out of Stock', value: outOfStock.length.toString())),
                ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.05),
              ),
              SizedBox(height: 2.h),
              if (lowStock.isEmpty)
                const EmptyState(
                  icon:    Icons.check_circle_outline_rounded,
                  title:   'All items well-stocked',
                  message: 'No products are at or below their reorder level',
                )
              else
                ErpCard(
                  goldRule: true,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(1.5.w),
                        child: Row(
                          children: [
                            const Text('Low Stock Alert',
                              style: TextStyle(fontFamily: 'Instrument Serif',
                                  fontSize: 18, color: D.ink800)),
                            SizedBox(width: 1.w),
                            StatusBadge.warning('${lowStock.length} items'),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: D.borderSubtle),
                      ErpTable(
                        headers: const ['Product', 'On Hand', 'Reorder Level', 'Reorder Qty', 'Status'],
                        numericCols: const [false, true, true, true, false],
                        rows: lowStock.map((item) => [
                          _ProductNameWidget(productId: item.productId),
                          Text(item.qtyOnHand.toStringAsFixed(0),
                            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: item.qtyOnHand <= 0 ? D.danger500 : D.warning500)),
                          Text(item.reorderLevel.toStringAsFixed(0),
                            style: const TextStyle(fontFamily: 'JetBrains Mono',
                                fontSize: 12, color: D.fgSecondary)),
                          Text(item.reorderQty.toStringAsFixed(0),
                            style: const TextStyle(fontFamily: 'JetBrains Mono',
                                fontSize: 12, color: D.fgSecondary)),
                          item.qtyOnHand <= 0
                              ? StatusBadge.danger('Out of Stock')
                              : StatusBadge.warning('Low Stock'),
                        ]).toList(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
            ],
          ),
        );
      },
    );
  }
}
 
// ─── Payment Breakdown ────────────────────────────────────
class _PaymentsReport extends ConsumerWidget {
  final DateTimeRange range;
  const _PaymentsReport({required this.range});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db       = ref.watch(databaseProvider);
    final branchId = ref.watch(currentBranchIdProvider);
 
    return FutureBuilder<List<Invoice>>(
      future: (db.select(db.invoices)
            ..where((t) =>
                t.branchId.equals(branchId) &
                t.isDeleted.equals(false) &
                t.invoiceDate.isBiggerOrEqualValue(range.start) &
                t.invoiceDate.isSmallerOrEqualValue(
                    range.end.add(const Duration(days: 1)))))
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: D.gold400));
        }
        final invoices = snap.data!;
        if (invoices.isEmpty) {
          return const EmptyState(
            icon:    Icons.payments_rounded,
            title:   'No payments in range',
            message: 'Adjust the date range to see data',
          );
        }
 
        final Map<String, _PayMode> byMode = {};
        for (final inv in invoices) {
          final m = inv.paymentMode;
          byMode[m] ??= _PayMode(mode: m);
          byMode[m]!.count++;
          byMode[m]!.total += inv.totalWithTax;
        }
        final modes      = byMode.values.toList()..sort((a, b) => b.total.compareTo(a.total));
        final grandTotal = invoices.fold(0.0, (s, i) => s + i.totalWithTax);
 
        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: [
              Row(
                children: modes.asMap().entries.map((e) {
                  final m = e.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: e.key < modes.length - 1 ? 1.5.w : 0),
                      child: StatCard(
                        label:       m.mode.toUpperCase(),
                        value:       Fmt.pkr(m.total),
                        sub:         '${m.count} transactions',
                        goldVariant: m.mode == 'cash',
                      ),
                    ),
                  );
                }).toList()
                  .animate(interval: 60.ms).fadeIn().slideY(begin: 0.05),
              ),
              SizedBox(height: 2.h),
              ErpCard(
                goldRule: true,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(1.5.w),
                      child: const Text('Payment Mode Breakdown',
                        style: TextStyle(fontFamily: 'Instrument Serif',
                            fontSize: 18, color: D.ink800)),
                    ),
                    const Divider(height: 1, color: D.borderSubtle),
                    ErpTable(
                      headers: const ['Mode', 'Transactions', 'Amount', '% of Total'],
                      numericCols: const [false, true, true, true],
                      rows: modes.map((m) => [
                        StatusBadge.payment(m.mode),
                        Text(m.count.toString(),
                          style: const TextStyle(fontFamily: 'JetBrains Mono',
                              fontSize: 12, color: D.fgSecondary)),
                        AmountText(m.total, fontSize: 12),
                        Text(
                          grandTotal > 0
                              ? '${(m.total / grandTotal * 100).toStringAsFixed(1)}%'
                              : '0%',
                          style: const TextStyle(fontFamily: 'JetBrains Mono',
                              fontSize: 12, color: D.fgSecondary),
                        ),
                      ]).toList(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        color:  D.bgCream,
                        border: Border(top: BorderSide(color: D.borderGold)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Grand Total: ',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                                fontWeight: FontWeight.w600, color: D.fgSecondary)),
                          AmountText(grandTotal, fontSize: 14, bold: true, color: D.gold600),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
            ],
          ),
        );
      },
    );
  }
}
 
class _PayMode {
  final String mode;
  int count = 0;
  double total = 0;
  _PayMode({required this.mode});
}
 
// ─── Shared widgets ───────────────────────────────────────
class _ProductNameWidget extends ConsumerWidget {
  final String productId;
  const _ProductNameWidget({required this.productId});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Product?>(
      future: (db.select(db.products)..where((p) => p.id.equals(productId))).getSingleOrNull(),
      builder: (_, snap) => Text(snap.data?.name ?? productId,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
            fontWeight: FontWeight.w500, color: D.fgPrimary)),
    );
  }
}
 
class _ReportTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ReportTab({required this.label, required this.icon,
      required this.active, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1.2.w, vertical: 1.h),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: active ? D.gold400 : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? D.gold500 : D.fgTertiary),
            SizedBox(width: 0.4.w),
            Text(label,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12.sp,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? D.gold600 : D.fgTertiary)),
          ],
        ),
      ),
    );
  }
}