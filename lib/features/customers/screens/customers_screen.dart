// lib/features/customers/screens/customers_screen.dart
import 'package:drift/drift.dart'
    show Value, OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/views.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _State();
}

class _State extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(currentTenantIdProvider);
    final db = ref.watch(databaseProvider);
    final bizType = ref.watch(businessTypeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            eyebrow: 'CRM',
            title: bizType.customerLabel,
            actions: [
              ElevatedButton.icon(
                onPressed: () => _showDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 15),
                label: const Text('Add Customer'),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
            child: TextField(
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: D.fgTertiary,
                ),
              ),
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 16),

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
                final filtered = _q.isEmpty
                    ? all
                    : all
                          .where(
                            (c) =>
                                c.name.toLowerCase().contains(_q) ||
                                (c.phone?.contains(_q) ?? false),
                          )
                          .toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No ${bizType.customerLabel}',
                    message:
                        'Add your first ${bizType.customerLabel.toLowerCase()}',
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: ErpCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: filtered
                          .map(
                            (c) => _CustomerRow(
                              customer: c,
                              onEdit: () => _showDialog(context, customer: c),
                            ),
                          )
                          .toList(),
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

  void _showDialog(BuildContext ctx, {Customer? customer}) {
    showDialog(
      context: ctx,
      builder: (_) => _CustomerDialog(customer: customer),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  const _CustomerRow({required this.customer, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: D.borderSubtle)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: D.brand50,
              border: Border.all(color: D.brand100),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: D.brand600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: D.fgPrimary,
                  ),
                ),
                if (customer.phone != null || customer.cnic != null)
                  Text(
                    customer.phone ?? customer.cnic ?? '',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: D.fgTertiary,
                    ),
                  ),
              ],
            ),
          ),
          // Balance badge
          if (customer.balance > 0) ...[
            StatusBadge.warning('Owes Rs. ${Fmt.pkrShort(customer.balance)}'),
            const SizedBox(width: 8),
          ],
          // Edit
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 14, color: D.fgTertiary),
            onPressed: onEdit,
            style: IconButton.styleFrom(
              minimumSize: const Size(28, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDialog extends ConsumerStatefulWidget {
  final Customer? customer;
  const _CustomerDialog({this.customer});
  @override
  ConsumerState<_CustomerDialog> createState() => _CDState();
}

class _CDState extends ConsumerState<_CustomerDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _ntnCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.customer case final c?) {
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone ?? '';
      _cnicCtrl.text = c.cnic ?? '';
      _ntnCtrl.text = c.ntn ?? '';
      _addrCtrl.text = c.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _ntnCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      message: widget.customer == null ? 'Adding…' : 'Saving…',
      successMessage: 'Saved!',
      action: () async {
        final db = ref.read(databaseProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final id = widget.customer?.id ?? const Uuid().v4();
        await db
            .into(db.customers)
            .insertOnConflictUpdate(
              CustomersCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: _nameCtrl.text.trim(),
                phone: Value(
                  _phoneCtrl.text.trim().isEmpty
                      ? null
                      : _phoneCtrl.text.trim(),
                ),
                cnic: Value(
                  _cnicCtrl.text.trim().isEmpty ? null : _cnicCtrl.text.trim(),
                ),
                ntn: Value(
                  _ntnCtrl.text.trim().isEmpty ? null : _ntnCtrl.text.trim(),
                ),
                address: Value(
                  _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
                ),
                updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
              ),
            );
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.customer == null;
    return Dialog(
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    isNew ? 'Add Customer' : 'Edit Customer',
                    style: const TextStyle(
                      fontFamily: 'Instrument Serif',
                      fontSize: 24,
                      color: D.ink800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(foregroundColor: D.fgTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ErpField(
                label: 'Full Name',
                controller: _nameCtrl,
                required: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ErpField(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ErpField(label: 'CNIC', controller: _cnicCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ErpField(
                      label: 'NTN (for FBR)',
                      controller: _ntnCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ErpField(label: 'Address', controller: _addrCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(isNew ? 'Add' : 'Save'),
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
