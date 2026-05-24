import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:drift/drift.dart'
    show Value, OrderingTerm, BooleanExpressionOperators;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

enum _AccountsTab { chart, journal, trial }

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  _AccountsTab _tab = _AccountsTab.chart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bgApp,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'Finance',
            title: 'Accounts',
            subtitle: 'Chart of accounts, journal entries, and trial balance',
            actions: [
              if (_tab == _AccountsTab.journal)
                GoldButton(
                  label: 'New Entry',
                  icon: Icons.add_rounded,
                  onPressed: () => _showJournalDialog(context),
                ),
            ],
          ),

          Container(
            color: D.bgSurface,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                _AccountTab(
                  label: 'Chart of Accounts',
                  icon: Icons.account_tree_rounded,
                  active: _tab == _AccountsTab.chart,
                  onTap: () => setState(() => _tab = _AccountsTab.chart),
                ),
                _AccountTab(
                  label: 'Journal Entries',
                  icon: Icons.edit_note_rounded,
                  active: _tab == _AccountsTab.journal,
                  onTap: () => setState(() => _tab = _AccountsTab.journal),
                ),
                _AccountTab(
                  label: 'Trial Balance',
                  icon: Icons.balance_rounded,
                  active: _tab == _AccountsTab.trial,
                  onTap: () => setState(() => _tab = _AccountsTab.trial),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: AnimatedSwitcher(
              duration: 250.ms,
              child: switch (_tab) {
                _AccountsTab.chart => const _ChartOfAccounts(),
                _AccountsTab.journal => const _JournalList(),
                _AccountsTab.trial => const _TrialBalance(),
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showJournalDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _JournalEntryDialog(
        onSave: (desc, date, lines) => _saveJournal(desc, date, lines),
      ),
    );
  }

  Future<void> _saveJournal(
    String description,
    DateTime date,
    List<_JournalLineItem> lines,
  ) async {
    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      successMessage: 'Journal entry posted',
      action: () async {
        final db = ref.read(databaseProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final branchId = ref.read(currentBranchIdProvider);
        const uuid = Uuid();
        final entryId = uuid.v4();
        final ts = DateTime.now().millisecondsSinceEpoch;

        await db
            .into(db.journalEntries)
            .insert(
              JournalEntriesCompanion.insert(
                id: entryId,
                tenantId: tenantId,
                branchId: branchId,
                description: description,
                entryDate: date,
                isPosted: const Value(true),
                createdAt: Value(ts),
              ),
            );

        for (final line in lines) {
          await db
              .into(db.journalLines)
              .insert(
                JournalLinesCompanion.insert(
                  id: uuid.v4(),
                  entryId: entryId,
                  accountId: line.accountId,
                  debit: Value(line.debit),
                  credit: Value(line.credit),
                  narration: Value(
                    line.narration.isEmpty ? null : line.narration,
                  ),
                ),
              );
        }

        ref
            .read(syncEngineProvider)
            .enqueue(
              entityType: 'journal_entries',
              entityId: entryId,
              operation: 'insert',
              payload: {
                'id': entryId,
                'tenant_id': tenantId,
                'branch_id': branchId,
                'description': description,
                'is_posted': true,
                'created_at': ts,
              },
            );
      },
    );
  }
}

// ─── Chart of Accounts ────────────────────────────────────
class _ChartOfAccounts extends ConsumerWidget {
  const _ChartOfAccounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);

    return StreamBuilder<List<Account>>(
      stream:
          (db.select(db.accounts)
                ..where(
                  (t) => t.tenantId.equals(tenantId) & t.isActive.equals(true),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.code)]))
              .watch(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: D.gold400),
          );
        }
        final accounts = snap.data!;
        if (accounts.isEmpty) {
          return EmptyState(
            icon: Icons.account_tree_rounded,
            title: 'No accounts yet',
            message:
                'Run the setup wizard to seed the default chart of accounts',
            action: Consumer(
              builder: (ctx, ref, _) => GoldButton(
                label: 'Seed Default Accounts',
                icon: Icons.auto_fix_high_rounded,
                onPressed: () async {
                  await AppErrorHandler.guard(
                    ref: ref,
                    context: ctx,
                    successMessage: 'Default accounts seeded',
                    action: () async {
                      final tenantId = ref.read(currentTenantIdProvider);
                      await ref
                          .read(databaseProvider)
                          .seedDefaultAccounts(tenantId);
                    },
                  );
                },
              ),
            ),
          );
        }

        final grouped = <String, List<Account>>{};
        for (final acc in accounts) {
          grouped[acc.type] ??= [];
          grouped[acc.type]!.add(acc);
        }
        const typeOrder = [
          'asset',
          'liability',
          'equity',
          'revenue',
          'expense',
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: typeOrder
                .where((t) => grouped.containsKey(t))
                .map(
                  (type) => Padding(
                    padding: EdgeInsets.only(bottom: 1.5.h),
                    child: ErpCard(
                      goldRule: type == 'asset',
                      goldCorner: type == 'revenue',
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 1.5.w,
                              vertical: 0.8.h,
                            ),
                            decoration: const BoxDecoration(
                              color: D.bgCream,
                              border: Border(
                                bottom: BorderSide(color: D.borderGold),
                              ),
                            ),
                            child: Row(
                              children: [
                                _TypeIcon(type: type),
                                SizedBox(width: 0.8.w),
                                Text(
                                  type.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: D.gold600,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                SizedBox(width: 0.8.w),
                                StatusBadge.neutral('${grouped[type]!.length}'),
                              ],
                            ),
                          ),
                          ErpTable(
                            headers: const [
                              'Code',
                              'Account Name',
                              'Urdu Name',
                              'Type',
                            ],
                            numericCols: const [false, false, false, false],
                            rows: grouped[type]!
                                .map(
                                  (a) => [
                                    Text(
                                      a.code,
                                      style: const TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: D.gold600,
                                      ),
                                    ),
                                    Text(
                                      a.name,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: D.fgPrimary,
                                      ),
                                    ),
                                    Text(
                                      a.nameUrdu ?? '—',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: D.fgSecondary,
                                      ),
                                    ),
                                    _TypeBadge(type: a.type),
                                  ],
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final String type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'asset' => (Icons.account_balance_wallet_rounded, D.brand500),
      'liability' => (Icons.trending_down_rounded, D.danger500),
      'equity' => (Icons.pie_chart_rounded, D.info500),
      'revenue' => (Icons.trending_up_rounded, D.brand500),
      _ => (Icons.money_off_rounded, D.warning500),
    };
    return Icon(icon, size: 14, color: color);
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) => switch (type) {
    'asset' => StatusBadge.brand('Asset'),
    'liability' => StatusBadge.danger('Liability'),
    'equity' => StatusBadge.info('Equity'),
    'revenue' => StatusBadge.success('Revenue'),
    _ => StatusBadge.warning('Expense'),
  };
}

// ─── Journal List ─────────────────────────────────────────
class _JournalList extends ConsumerWidget {
  const _JournalList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final branchId = ref.watch(currentBranchIdProvider);

    return StreamBuilder<List<JournalEntry>>(
      stream:
          (db.select(db.journalEntries)
                ..where((t) => t.branchId.equals(branchId))
                ..orderBy([(t) => OrderingTerm.desc(t.entryDate)]))
              .watch(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: D.gold400),
          );
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.edit_note_rounded,
            title: 'No journal entries',
            message: 'Create your first double-entry journal posting',
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: entries
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(bottom: 1.h),
                    child: ErpCard(
                      goldCorner: true,
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 1.5.w,
                              vertical: 0.8.h,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.description,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: D.fgPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${e.entryDate.day}/${e.entryDate.month}/${e.entryDate.year}',
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 11,
                                          color: D.fgTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                e.isPosted
                                    ? StatusBadge.success('Posted')
                                    : StatusBadge.warning('Draft'),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: D.borderSubtle),
                          _JournalLinesWidget(entryId: e.id),
                        ],
                      ),
                    ).animate().fadeIn(duration: 250.ms),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _JournalLinesWidget extends ConsumerWidget {
  final String entryId;
  const _JournalLinesWidget({required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder<List<JournalLine>>(
      future: (db.select(
        db.journalLines,
      )..where((t) => t.entryId.equals(entryId))).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 32);
        final lines = snap.data!;
        final totalDebit = lines.fold(0.0, (s, l) => s + l.debit);
        final totalCredit = lines.fold(0.0, (s, l) => s + l.credit);

        return Column(
          children: [
            ErpTable(
              headers: const ['Account', 'Narration', 'Debit', 'Credit'],
              numericCols: const [false, false, true, true],
              rows: lines
                  .map(
                    (l) => [
                      _AccountCodeCell(accountId: l.accountId),
                      Text(
                        l.narration ?? '—',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: D.fgSecondary,
                        ),
                      ),
                      l.debit > 0
                          ? AmountText(
                              l.debit,
                              fontSize: 12,
                              color: D.brand600,
                              bold: true,
                            )
                          : const Text(
                              '—',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                color: D.fgTertiary,
                              ),
                            ),
                      l.credit > 0
                          ? AmountText(
                              l.credit,
                              fontSize: 12,
                              color: D.danger500,
                              bold: true,
                            )
                          : const Text(
                              '—',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                color: D.fgTertiary,
                              ),
                            ),
                    ],
                  )
                  .toList(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: D.bgCream,
                border: Border(top: BorderSide(color: D.borderGold)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: D.fgTertiary,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  AmountText(
                    totalDebit,
                    fontSize: 12,
                    bold: true,
                    color: D.brand600,
                  ),
                  SizedBox(width: 2.w),
                  AmountText(
                    totalCredit,
                    fontSize: 12,
                    bold: true,
                    color: D.danger500,
                  ),
                  SizedBox(width: 1.w),
                  (totalDebit - totalCredit).abs() < 0.01
                      ? StatusBadge.success('Balanced')
                      : StatusBadge.danger('Unbalanced'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountCodeCell extends ConsumerWidget {
  final String accountId;
  const _AccountCodeCell({required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Account?>(
      future: (db.select(
        db.accounts,
      )..where((a) => a.id.equals(accountId))).getSingleOrNull(),
      builder: (_, snap) {
        final acc = snap.data;
        if (acc == null) {
          return Text(
            accountId.length > 8 ? accountId.substring(0, 8) : accountId,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: D.fgTertiary,
            ),
          );
        }
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${acc.code} ',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: D.gold600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: acc.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: D.fgPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Trial Balance ────────────────────────────────────────
class _TrialBalance extends ConsumerWidget {
  const _TrialBalance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);

    return FutureBuilder<_TrialData>(
      future: _buildTrialBalance(db, tenantId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: D.gold400),
          );
        }
        final data = snap.data!;
        final balanced = (data.totalDebit - data.totalCredit).abs() < 0.01;

        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InfoBanner(
                      message: balanced
                          ? 'Books are balanced. Total debits equal total credits.'
                          : 'Warning: Debits and credits do not match. Check journal entries for errors.',
                      color: balanced ? D.brand500 : D.danger500,
                      bgColor: balanced ? D.success50 : D.danger50,
                      icon: balanced
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                    ),
                  ),
                ],
              ).animate().fadeIn(),
              SizedBox(height: 1.5.h),

              ErpCard(
                goldRule: true,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ErpTable(
                      headers: const ['Code', 'Account', 'Debit', 'Credit'],
                      numericCols: const [false, false, true, true],
                      rows: data.rows
                          .map(
                            (r) => [
                              Text(
                                r.code,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: D.gold600,
                                ),
                              ),
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: D.fgPrimary,
                                ),
                              ),
                              r.debit > 0
                                  ? AmountText(
                                      r.debit,
                                      fontSize: 12,
                                      color: D.brand600,
                                    )
                                  : const Text(
                                      '—',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        color: D.fgTertiary,
                                      ),
                                    ),
                              r.credit > 0
                                  ? AmountText(
                                      r.credit,
                                      fontSize: 12,
                                      color: D.danger500,
                                    )
                                  : const Text(
                                      '—',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 12,
                                        color: D.fgTertiary,
                                      ),
                                    ),
                            ],
                          )
                          .toList(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: D.ink800,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTALS',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: D.gold300,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          AmountText(
                            data.totalDebit,
                            fontSize: 14,
                            bold: true,
                            color: D.gold300,
                          ),
                          SizedBox(width: 2.w),
                          AmountText(
                            data.totalCredit,
                            fontSize: 14,
                            bold: true,
                            color: D.gold300,
                          ),
                          SizedBox(width: 1.w),
                          balanced
                              ? StatusBadge.success('Balanced')
                              : StatusBadge.danger('Unbalanced'),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            ],
          ),
        );
      },
    );
  }

  Future<_TrialData> _buildTrialBalance(AppDatabase db, String tenantId) async {
    final accounts =
        await (db.select(db.accounts)
              ..where(
                (t) => t.tenantId.equals(tenantId) & t.isActive.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.code)]))
            .get();

    final allEntries =
        await (db.select(db.journalEntries)..where(
              (t) => t.tenantId.equals(tenantId) & t.isPosted.equals(true),
            ))
            .get();
    final postedIds = allEntries.map((e) => e.id).toSet();

    final allLines = await db.select(db.journalLines).get();

    final Map<String, double> debits = {};
    final Map<String, double> credits = {};

    for (final line in allLines) {
      if (!postedIds.contains(line.entryId)) continue;
      debits[line.accountId] = (debits[line.accountId] ?? 0) + line.debit;
      credits[line.accountId] = (credits[line.accountId] ?? 0) + line.credit;
    }

    final rows = accounts
        .where((a) => (debits[a.id] ?? 0) > 0 || (credits[a.id] ?? 0) > 0)
        .map(
          (a) => _TrialRow(
            code: a.code,
            name: a.name,
            debit: debits[a.id] ?? 0,
            credit: credits[a.id] ?? 0,
          ),
        )
        .toList();

    return _TrialData(
      rows: rows,
      totalDebit: rows.fold(0.0, (s, r) => s + r.debit),
      totalCredit: rows.fold(0.0, (s, r) => s + r.credit),
    );
  }
}

class _TrialData {
  final List<_TrialRow> rows;
  final double totalDebit, totalCredit;
  _TrialData({
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
  });
}

class _TrialRow {
  final String code, name;
  final double debit, credit;
  _TrialRow({
    required this.code,
    required this.name,
    required this.debit,
    required this.credit,
  });
}

// ─── Tab button ───────────────────────────────────────────
class _AccountTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _AccountTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 1.2.w, vertical: 1.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? D.gold400 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? D.gold500 : D.fgTertiary),
            SizedBox(width: 0.4.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? D.gold600 : D.fgTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Journal Entry Dialog ─────────────────────────────────
class _JournalLineItem {
  final String accountId, narration;
  final double debit, credit;
  _JournalLineItem({
    required this.accountId,
    required this.debit,
    required this.credit,
    required this.narration,
  });
}

class _JournalEntryDialog extends ConsumerStatefulWidget {
  final Future<void> Function(
    String desc,
    DateTime date,
    List<_JournalLineItem> lines,
  )
  onSave;
  const _JournalEntryDialog({required this.onSave});

  @override
  ConsumerState<_JournalEntryDialog> createState() =>
      _JournalEntryDialogState();
}

class _JournalEntryDialogState extends ConsumerState<_JournalEntryDialog> {
  final _descCtrl = TextEditingController();
  final _debitCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  final _narCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _accId;
  final List<_JournalLineItem> _lines = [];

  @override
  void dispose() {
    _descCtrl.dispose();
    _debitCtrl.dispose();
    _creditCtrl.dispose();
    _narCtrl.dispose();
    super.dispose();
  }

  void _addLine() {
    if (_accId == null) return;
    final debit = double.tryParse(_debitCtrl.text) ?? 0;
    final credit = double.tryParse(_creditCtrl.text) ?? 0;
    if (debit == 0 && credit == 0) return;
    setState(() {
      _lines.add(
        _JournalLineItem(
          accountId: _accId!,
          debit: debit,
          credit: credit,
          narration: _narCtrl.text.trim(),
        ),
      );
      _accId = null;
      _debitCtrl.clear();
      _creditCtrl.clear();
      _narCtrl.clear();
    });
  }

  double get _totalDebit => _lines.fold(0.0, (s, l) => s + l.debit);
  double get _totalCredit => _lines.fold(0.0, (s, l) => s + l.credit);
  bool get _balanced =>
      (_totalDebit - _totalCredit).abs() < 0.01 && _lines.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);

    return Dialog(
      child: Container(
        width: 640,
        padding: EdgeInsets.all(2.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Journal Entry',
                style: TextStyle(
                  fontFamily: 'Instrument Serif',
                  fontSize: 24,
                  color: D.ink800,
                ),
              ),
              SizedBox(height: 1.5.h),

              Row(
                children: [
                  Expanded(
                    child: ErpField(
                      label: 'Description',
                      controller: _descCtrl,
                      required: true,
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: D.fgSecondary,
                        ),
                      ),
                      SizedBox(height: 0.4.h),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: D.gold400,
                                  onPrimary: D.ink800,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: Container(
                          height: 36,
                          padding: EdgeInsets.symmetric(horizontal: 1.w),
                          decoration: BoxDecoration(
                            color: D.bgSurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: D.neutral300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: D.fgTertiary,
                              ),
                              SizedBox(width: 0.4.w),
                              Text(
                                '${_date.day}/${_date.month}/${_date.year}',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  color: D.fgPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 1.h),

              FutureBuilder<List<Account>>(
                future:
                    (db.select(db.accounts)
                          ..where(
                            (a) =>
                                a.tenantId.equals(tenantId) &
                                a.isActive.equals(true),
                          )
                          ..orderBy([(a) => OrderingTerm.asc(a.code)]))
                        .get(),
                builder: (_, snap) {
                  final accs = snap.data ?? [];
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: D.fgSecondary,
                              ),
                            ),
                            SizedBox(height: 0.4.h),
                            DropdownButtonFormField<String>(
                              value: _accId,
                              decoration: const InputDecoration(),
                              hint: const Text('Select account'),
                              items: accs
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(
                                        '${a.code} — ${a.name}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _accId = v),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 0.8.w),
                      Expanded(
                        child: ErpField(
                          label: 'Debit',
                          controller: _debitCtrl,
                          keyboardType: TextInputType.number,
                          hint: '0.00',
                        ),
                      ),
                      SizedBox(width: 0.8.w),
                      Expanded(
                        child: ErpField(
                          label: 'Credit',
                          controller: _creditCtrl,
                          keyboardType: TextInputType.number,
                          hint: '0.00',
                        ),
                      ),
                      SizedBox(width: 0.8.w),
                      Expanded(
                        child: ErpField(
                          label: 'Narration',
                          controller: _narCtrl,
                        ),
                      ),
                      SizedBox(width: 0.8.w),
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: ElevatedButton(
                          onPressed: _addLine,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: D.brand500,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 1.h),

              if (_lines.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: D.bgCream,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: D.borderGold),
                  ),
                  child: Column(
                    children: [
                      ..._lines.asMap().entries.map((e) {
                        final l = e.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: D.borderSubtle),
                            ),
                          ),
                          child: Row(
                            children: [
                              _AccountCodeCell(accountId: l.accountId),
                              const Spacer(),
                              if (l.debit > 0) ...[
                                const Text(
                                  'Dr ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: D.brand600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                AmountText(
                                  l.debit,
                                  fontSize: 12,
                                  color: D.brand600,
                                  bold: true,
                                ),
                              ],
                              if (l.credit > 0) ...[
                                SizedBox(width: 1.w),
                                const Text(
                                  'Cr ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: D.danger500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                AmountText(
                                  l.credit,
                                  fontSize: 12,
                                  color: D.danger500,
                                  bold: true,
                                ),
                              ],
                              SizedBox(width: 1.w),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _lines.removeAt(e.key)),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: D.danger500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Dr ${Fmt.pkrShort(_totalDebit)}  '
                              'Cr ${Fmt.pkrShort(_totalCredit)}',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                color: D.fgSecondary,
                              ),
                            ),
                            SizedBox(width: 0.8.w),
                            _balanced
                                ? StatusBadge.success('Balanced')
                                : StatusBadge.danger('Unbalanced'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 1.h),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 1.w),
                  GoldButton(
                    label: 'Post Entry',
                    icon: Icons.check_rounded,
                    onPressed: !_balanced
                        ? null
                        : () async {
                            if (_descCtrl.text.trim().isEmpty) return;
                            await widget.onSave(
                              _descCtrl.text.trim(),
                              _date,
                              _lines,
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
