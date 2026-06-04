// lib/features/customers/screens/customers_screen.dart
// Responsive (sizer). Tapping a customer opens the khata detail screen;
// the edit pencil still opens the edit dialog.
import 'package:drift/drift.dart'
    show Value, OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/views.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'customer_detail_screen.dart';

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
                onPressed: () => _showEdit(context),
                icon: Icon(Icons.person_add_rounded, size: 13.sp),
                label: Text('Add Customer', style: TextStyle(fontSize: 11.sp)),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 0),
            child: TextField(
              style: TextStyle(fontFamily: 'Inter', fontSize: 11.sp),
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
          SizedBox(height: 2.h),
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
                  padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 4.h),
                  child: ErpCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: filtered
                          .map(
                            (c) => _CustomerRow(
                              customer: c,
                              onOpen: () => _showDetail(context, c),
                              onEdit: () => _showEdit(context, customer: c),
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

  void _showDetail(BuildContext ctx, Customer c) => showDialog(
    context: ctx,
    builder: (_) => CustomerDetailScreen(customer: c),
  );

  void _showEdit(BuildContext ctx, {Customer? customer}) => showDialog(
    context: ctx,
    builder: (_) => _CustomerDialog(customer: customer),
  );
}

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  const _CustomerRow({
    required this.customer,
    required this.onOpen,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen, // tapping the row opens the khata detail
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.4.h),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: D.borderSubtle)),
        ),
        child: Row(
          children: [
            Container(
              width: 4.5.w,
              height: 4.5.w,
              constraints: const BoxConstraints(
                maxWidth: 36,
                maxHeight: 36,
                minWidth: 28,
                minHeight: 28,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: D.brand50,
                border: Border.all(color: D.brand100),
              ),
              alignment: Alignment.center,
              child: Text(
                customer.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: D.brand600,
                ),
              ),
            ),
            SizedBox(width: 1.5.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: D.fgPrimary,
                    ),
                  ),
                  if (customer.phone != null || customer.ntn != null)
                    Text(
                      [
                        if (customer.phone != null) customer.phone!,
                        if (customer.ntn != null) 'NTN ${customer.ntn}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.sp,
                        color: D.fgTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (customer.balance > 0) ...[
              if (customer.balance != 0) ...[
                _BalanceBadge(balance: customer.balance),
                SizedBox(width: 1.w),
              ],
              SizedBox(width: 1.w),
            ],
            Icon(Icons.chevron_right_rounded, size: 15.sp, color: D.fgTertiary),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 13.sp, color: D.fgTertiary),
              onPressed: onEdit,
              style: IconButton.styleFrom(
                minimumSize: const Size(28, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final double balance; // internal: >0 owes, <0 advance/credit
  const _BalanceBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    final owes = balance > 0;
    // Display flips the sign, same as the khata detail screen:
    //   owes  → − Rs. X (warning)   |   advance/credit → + Rs. X (brand)
    final (bg, fg, border, text) = owes
        ? (
            D.warning50,
            D.warning500,
            const Color(0x33B07013), // warning500 @ ~20%
            '− Rs. ${Fmt.pkrShort(balance.abs())}',
          )
        : (
            D.brand50,
            D.brand600,
            const Color(0x330B6B43), // brand500 @ ~20%
            '+ Rs. ${Fmt.pkrShort(balance.abs())}',
          );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.2.w, vertical: 0.4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
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
        width: 90.w.clamp(360.0, 460.0),
        padding: EdgeInsets.all(3.w),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      isNew ? 'Add Customer' : 'Edit Customer',
                      style: TextStyle(
                        fontFamily: 'Instrument Serif',
                        fontSize: 15.sp,
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
                SizedBox(height: 2.h),
                ErpField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  required: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: 1.4.h),
                Row(
                  children: [
                    Expanded(
                      child: ErpField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: ErpField(label: 'CNIC', controller: _cnicCtrl),
                    ),
                  ],
                ),
                SizedBox(height: 1.4.h),
                Row(
                  children: [
                    Expanded(
                      child: ErpField(
                        label: 'NTN (for FBR / B2B)',
                        controller: _ntnCtrl,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: ErpField(label: 'Address', controller: _addrCtrl),
                    ),
                  ],
                ),
                SizedBox(height: 2.5.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    SizedBox(width: 1.5.w),
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
      ),
    );
  }
}
