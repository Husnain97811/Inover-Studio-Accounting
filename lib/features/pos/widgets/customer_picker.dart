// lib/features/pos/widgets/customer_picker.dart
//
// F2 "Customer" → this dialog. Search existing customers or quick-add a new one.
// On select, attaches {id, name, ntn} to the cart.

import 'package:drift/drift.dart'
    show OrderingTerm, BooleanExpressionOperators, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class CustomerPicker extends ConsumerStatefulWidget {
  const CustomerPicker({super.key});
  @override
  ConsumerState<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<CustomerPicker> {
  String _q = '';
  bool _adding = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ntnCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ntnCtrl.dispose();
    super.dispose();
  }

  void _attach(Customer c) {
    ref
        .read(cartProvider.notifier)
        .setCustomer(id: c.id, name: c.name, ntn: c.ntn);
    Navigator.pop(context);
  }

  Future<void> _quickAdd() async {
    if (_nameCtrl.text.trim().isEmpty) {
      AppErrorHandler.showInfo(context, 'Name is required');
      return;
    }
    final db = ref.read(databaseProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db
        .into(db.customers)
        .insertOnConflictUpdate(
          CustomersCompanion.insert(
            id: id,
            tenantId: tenantId,
            name: _nameCtrl.text.trim(),
            phone: Value(
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            ),
            ntn: Value(
              _ntnCtrl.text.trim().isEmpty ? null : _ntnCtrl.text.trim(),
            ),
            updatedAt: Value(now),
          ),
        );
    ref
        .read(cartProvider.notifier)
        .setCustomer(
          id: id,
          name: _nameCtrl.text.trim(),
          ntn: _ntnCtrl.text.trim().isEmpty ? null : _ntnCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);

    return Dialog(
      child: Container(
        width: 460,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _adding ? 'Add Customer' : 'Select Customer',
                  style: const TextStyle(
                    fontFamily: 'Instrument Serif',
                    fontSize: 22,
                    color: D.ink800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_adding) ...[
              ErpField(
                label: 'Full Name',
                controller: _nameCtrl,
                required: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ErpField(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ErpField(label: 'NTN (B2B)', controller: _ntnCtrl),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _adding = false),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _quickAdd,
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Add & Attach'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search name or phone…',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: D.fgTertiary,
                        ),
                      ),
                      onChanged: (v) => setState(() => _q = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _adding = true),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Walk-in option
              _WalkInTile(
                onTap: () {
                  ref.read(cartProvider.notifier).clearCustomer();
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 16),
              Expanded(
                child: StreamBuilder<List<Customer>>(
                  stream:
                      (db.select(db.customers)
                            ..where(
                              (t) =>
                                  t.tenantId.equals(tenantId) &
                                  t.isDeleted.equals(false),
                            )
                            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                          .watch(),
                  builder: (_, snap) {
                    final all = snap.data ?? [];
                    final list = _q.isEmpty
                        ? all
                        : all
                              .where(
                                (c) =>
                                    c.name.toLowerCase().contains(_q) ||
                                    (c.phone?.contains(_q) ?? false),
                              )
                              .toList();
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'No customers found',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: D.fgTertiary,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _CustomerTile(
                        c: list[i],
                        onTap: () => _attach(list[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalkInTile extends StatelessWidget {
  final VoidCallback onTap;
  const _WalkInTile({required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    dense: true,
    leading: const CircleAvatar(
      backgroundColor: D.neutral100,
      child: Icon(Icons.person_outline_rounded, size: 18, color: D.fgTertiary),
    ),
    title: const Text(
      'Walk-in customer',
      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: D.fgPrimary),
    ),
    subtitle: const Text(
      'No account / cash sale',
      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: D.fgTertiary),
    ),
  );
}

class _CustomerTile extends StatelessWidget {
  final Customer c;
  final VoidCallback onTap;
  const _CustomerTile({required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    dense: true,
    leading: CircleAvatar(
      backgroundColor: D.brand50,
      child: Text(
        c.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          color: D.brand600,
        ),
      ),
    ),
    title: Text(
      c.name,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: D.fgPrimary,
      ),
    ),
    subtitle: Text(
      [
        if (c.phone != null) c.phone!,
        if (c.ntn != null) 'NTN ${c.ntn}',
      ].join(' · '),
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        color: D.fgTertiary,
      ),
    ),
    trailing: c.balance > 0
        ? StatusBadge.warning('Owes ${Fmt.pkrShort(c.balance)}')
        : null,
  );
}
