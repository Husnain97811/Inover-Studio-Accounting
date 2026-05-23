// lib/features/accounts/screens/accounts_screen.dart
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../shared/providers/app_providers.dart";
import "../../../shared/widgets/common_widgets.dart";

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        const PageHeader(title: "Accounts / GL", subtitle: "Coming in Phase 2"),
        const Expanded(child: Center(child: _Placeholder("Accounts / GL"))),
      ]),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.construction_rounded, size: 52, color: t.colorScheme.outline),
      const SizedBox(height: 16),
      Text(title, style: t.textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text("This module ships in Phase 2 (months 3-5).", style: t.textTheme.bodyMedium),
    ]);
  }
}
