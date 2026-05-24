// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../core/constants/views.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizType = ref.watch(businessTypeProvider);
    final locale = ref.watch(localeProvider);
    final stats = ref.watch(dashStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            PageHeader(
              eyebrow: Fmt.date(DateTime.now()),
              title: 'Good afternoon.',
              subtitle: '${bizType.emoji} ${bizType.label}',
              actions: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.download_rounded, size: 15.sp),
                  label: Text('Export', style: TextStyle(fontSize: 11.sp)),
                ),
                SizedBox(width: 1.w),
                ElevatedButton.icon(
                  onPressed: () => context.go('/pos'),
                  icon: Icon(Icons.point_of_sale_rounded, size: 15.sp),
                  label: Row(
                    children: [
                      Text('Open POS', style: TextStyle(fontSize: 11.sp)),
                      SizedBox(width: 1.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 0.8.w,
                          vertical: 0.2.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(0.4.h),
                        ),
                        child: Text(
                          'F1',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 4.h, 5.w, 0),
              child: stats.when(
                loading: () => Center(
                  child: Padding(
                    padding: EdgeInsets.all(6.h),
                    child: CircularProgressIndicator(color: D.brand500),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(6.h),
                    child: Text('Error: $e', style: TextStyle(fontSize: 12.sp)),
                  ),
                ),
                data: (s) => _DashBody(stats: s, bizType: bizType),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashBody extends StatelessWidget {
  final DashStats stats;
  final BusinessType bizType;
  const _DashBody({required this.stats, required this.bizType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI grid
        LayoutBuilder(
          builder: (_, c) {
            final cols = c.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 1.5.w,
              mainAxisSpacing: 1.5.h,
              childAspectRatio: c.maxWidth > 900 ? 1.65 : 1.5,
              children: [
                StatCard(
                  label: "Sales today",
                  value: "Rs. ${Fmt.pkrShort(stats.todaySales.toDouble())}",
                  delta: "vs yesterday",
                  deltaUp: true,
                  spark: _MiniSparkLine(stats.todaySales.toDouble()),
                ),
                StatCard(
                  label: "Transactions",
                  value: stats.todayCount.toString(),
                  sub: '${bizType.saleLabel}s today',
                  delta: "+${stats.todayCount}",
                  deltaUp: false,
                ),
                StatCard(
                  label: "Pending FBR",
                  value: stats.fbrPending.toString(),
                  sub: 'Auto-retry in 4 min',
                  goldVariant: true,
                  extra: stats.fbrPending > 0
                      ? StatusBadge.warning('Queued · will sync')
                      : StatusBadge.success('All fiscalized'),
                ),
                StatCard(
                  label: "Low stock SKUs",
                  value: stats.lowStock.toString(),
                  sub: stats.lowStock > 0 ? 'Reorder needed' : 'Stock OK',
                  extra: stats.lowStock > 0
                      ? StatusBadge.danger('${stats.lowStock} items')
                      : StatusBadge.success('Healthy'),
                ),
              ],
            );
          },
        ),

        SizedBox(height: 2.h),

        // Chart + Sync panel
        LayoutBuilder(
          builder: (_, c) {
            if (c.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _HourlyChart()),
                  SizedBox(width: 2.w),
                  Expanded(flex: 2, child: _SyncPanel()),
                ],
              );
            }
            return Column(
              children: [
                _HourlyChart(),
                SizedBox(height: 2.h),
                _SyncPanel(),
              ],
            );
          },
        ),

        SizedBox(height: 2.h),

        // Recent invoices
        _RecentInvoices(invoices: stats.recentInvoices),
        SizedBox(height: 6.h),
      ],
    );
  }
}

class _MiniSparkLine extends StatelessWidget {
  final double peak;
  const _MiniSparkLine(this.peak);

  @override
  Widget build(BuildContext context) {
    final pts = [20.0, 28, 22, 36, 40, 38, 52, 48, 60, 64, 72, 80, 86];
    return SizedBox(
      height: 4.5.h,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: pts
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: D.brand500,
              barWidth: 1.75,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: D.brand500.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = [12.0, 18, 28, 34, 22, 30, 42, 38, 26, 48, 36, 20];
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final labels = [
      '9a',
      '10a',
      '11a',
      '12p',
      '1p',
      '2p',
      '3p',
      '4p',
      '5p',
      '6p',
      '7p',
      '8p',
    ];

    return ErpCard(
      goldRule: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALES BY HOUR',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: D.gold500,
                      letterSpacing: 0.10,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Instrument Serif',
                        fontSize: 20.sp,
                        color: D.fgPrimary,
                      ),
                      children: const [
                        TextSpan(text: 'Peak hour '),
                        TextSpan(
                          text: '6–7 pm',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: D.gold500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              StatusBadge.brand('Live'),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            height: 15.h,
            child: BarChart(
              BarChartData(
                maxY: maxV * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: D.borderSubtle, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20.sp,
                      getTitlesWidget: (v, _) => Padding(
                        padding: EdgeInsets.only(top: 0.5.h),
                        child: Text(
                          labels[v.toInt()],
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9.sp,
                            color: D.fgTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: data.asMap().entries.map((e) {
                  final isPeak = e.value == maxV;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        width: 1.8.w,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(0.4.h),
                        ),
                        color: isPeak ? D.brand500 : D.brand100,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncStateProvider).value;
    final lastSync = sync?.lastSync;

    return ErpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sync queue',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: D.fgPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.read(syncEngineProvider).sync(),
                icon: Icon(Icons.sync_rounded, size: 13.sp),
                label: Text('Retry now', style: TextStyle(fontSize: 11.sp)),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 1.w),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.8.h),
          _SyncRow('To FBR', StatusBadge.warning('Queued')),
          _SyncRow('To Supabase', StatusBadge.success('0 records')),
          _SyncRow('From server', StatusBadge.info('Ready')),
          Divider(height: 2.5.h, color: D.borderDefault),
          if (lastSync != null)
            Text(
              'Last sync  ${Fmt.timeOnly(lastSync)}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                color: D.fgTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncRow extends StatelessWidget {
  final String label;
  final Widget badge;
  const _SyncRow(this.label, this.badge);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 1.2.h),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            color: D.fgSecondary,
          ),
        ),
        const Spacer(),
        badge,
      ],
    ),
  );
}

class _RecentInvoices extends StatelessWidget {
  final List<Map<String, dynamic>> invoices;
  const _RecentInvoices({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return ErpCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(2.w, 1.5.h, 2.w, 1.5.h),
            child: Row(
              children: [
                Text(
                  'Recent invoices',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: D.fgPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(horizontal: 1.w),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View all', style: TextStyle(fontSize: 11.sp)),
                      SizedBox(width: 0.5.w),
                      Icon(Icons.open_in_new_rounded, size: 11.sp),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: D.borderDefault),
          if (invoices.isEmpty)
            Padding(
              padding: EdgeInsets.all(4.h),
              child: Center(
                child: Text(
                  'No invoices today',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    color: D.fgTertiary,
                  ),
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.5),
                4: FixedColumnWidth(
                  80,
                ), // keep as fixed for time column; could also use Sizer but time column width is ok
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: D.bgCream),
                  children: ['Invoice', 'Customer', 'FBR', 'Total', 'Time']
                      .map(
                        (h) => Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 1.8.w,
                            vertical: 1.2.h,
                          ),
                          child: Text(
                            h.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: D.gold600,
                              letterSpacing: 0.14,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...invoices.map(
                  (inv) => TableRow(
                    children: [
                      _TCell(
                        child: Text(
                          inv['number'] as String? ?? '',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11.5.sp,
                            color: D.fgSecondary,
                          ),
                        ),
                      ),
                      _TCell(
                        child: Text(
                          'Walk-in',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            color: D.fgPrimary,
                          ),
                        ),
                      ),
                      _TCell(
                        child: StatusBadge.fbr(
                          inv['fbrStatus'] as String? ?? 'pending',
                        ),
                      ),
                      _TCell(
                        child: Text(
                          'Rs. ${Fmt.pkrShort((inv['amount'] as num?)?.toDouble() ?? 0.0)}',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: D.fgPrimary,
                          ),
                        ),
                      ),
                      _TCell(
                        child: Text(
                          Fmt.timeOnly(
                            inv['date'] as DateTime? ?? DateTime.now(),
                          ),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13.sp,
                            color: D.fgSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TCell extends StatelessWidget {
  final Widget child;
  const _TCell({required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 1.8.w, vertical: 1.4.h),
    child: child,
  );
}
