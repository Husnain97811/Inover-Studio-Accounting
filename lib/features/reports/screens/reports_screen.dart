// lib/features/reports/screens/reports_screen.dart
// Phase 2 stub — full implementation coming in v2.0
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../core/theme/app_theme.dart";
import "../../../shared/providers/app_providers.dart";
import "../../../shared/widgets/common_widgets.dart";

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: "Analytics",
            title: "Reports",
            subtitle: "Sales, FBR reconciliation, and business analytics",
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ComingSoonBanner(
                    title: "Business Reports",
                    description:
                        "Daily / monthly sales, FBR monthly GST return (ready to file), "
                        "inventory valuation, and customer aging.",
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (_, c) {
                      final cols = c.maxWidth > 700 ? 3 : 1;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 1 ? 3.5 : 2.2,
                        children: const [
                          _FeatureCard(
                            icon: Icons.receipt_long_rounded,
                            title: "FBR Monthly Report",
                            desc:
                                "GST return summary — pre-formatted for FBR filing.",
                            status: "Phase 2",
                          ),
                          _FeatureCard(
                            icon: Icons.bar_chart_rounded,
                            title: "Sales Analytics",
                            desc:
                                "Daily, weekly, monthly sales by product, cashier, and payment mode.",
                            status: "Phase 2",
                          ),
                          _FeatureCard(
                            icon: Icons.warning_amber_rounded,
                            title: "Customer Aging",
                            desc:
                                "Who owes how much and for how long. Credit management.",
                            status: "Phase 2",
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Shared stub widgets (defined at bottom of each screen file)
// These are defined inline per-file, NOT in a shared file.

class _ComingSoonBanner extends StatelessWidget {
  final String title;
  final String description;
  const _ComingSoonBanner({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [D.brand50, D.gold50],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: D.borderGold),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: D.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: D.borderGold),
            ),
            child: const Icon(
              Icons.construction_rounded,
              size: 28,
              color: D.gold500,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge.gold("Phase 2 — Coming Soon"),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Instrument Serif",
                    fontSize: 20,
                    color: D.ink800,
                    letterSpacing: -0.01,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: "Inter",
                    fontSize: 13,
                    color: D.fgSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final String status;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: D.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: D.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: D.bgCream,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: D.borderGold),
                ),
                child: Icon(icon, size: 18, color: D.gold500),
              ),
              const Spacer(),
              StatusBadge.neutral(status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Inter",
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: D.fgPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              fontFamily: "Inter",
              fontSize: 12,
              color: D.fgSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
