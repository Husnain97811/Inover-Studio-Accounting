// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/views.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

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
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('Export'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context.go('/pos'),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                  label: Row(
                    children: [
                      Text('Open POS'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'F1',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
              child: stats.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: D.brand500),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text('Error: $e'),
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
                  deltaUp: true,
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

        const SizedBox(height: 16),

        // Chart + Sync panel
        LayoutBuilder(
          builder: (_, c) {
            if (c.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _HourlyChart()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _SyncPanel()),
                ],
              );
            }
            return Column(
              children: [
                _HourlyChart(),
                const SizedBox(height: 16),
                _SyncPanel(),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // Recent invoices
        _RecentInvoices(invoices: stats.recentInvoices),
        const SizedBox(height: 48),
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
      height: 36,
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
                  const Text(
                    'SALES BY HOUR',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: D.gold500,
                      letterSpacing: 0.10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Instrument Serif',
                        fontSize: 20,
                        color: D.fgPrimary,
                      ),
                      children: [
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
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
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
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[v.toInt()],
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9,
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
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
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
              const Text(
                'Sync queue',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: D.fgPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.read(syncEngineProvider).sync(),
                icon: const Icon(Icons.sync_rounded, size: 13),
                label: const Text('Retry now'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SyncRow('To FBR', StatusBadge.warning('Queued')),
          _SyncRow('To Supabase', StatusBadge.success('0 records')),
          _SyncRow('From server', StatusBadge.info('Ready')),
          const Divider(height: 20, color: D.borderDefault),
          if (lastSync != null)
            Text(
              'Last sync  ${Fmt.timeOnly(lastSync)}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
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
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
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
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Recent invoices',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: D.fgPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View all'),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new_rounded, size: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: D.borderDefault),
          // Table
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No invoices today',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
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
                4: FixedColumnWidth(80),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: D.bgCream),
                  children: ['Invoice', 'Customer', 'FBR', 'Total', 'Time']
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            h.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
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
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11.5,
                            color: D.fgSecondary,
                          ),
                        ),
                      ),
                      _TCell(
                        child: Text(
                          'Walk-in',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
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
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
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
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: child,
  );
}
