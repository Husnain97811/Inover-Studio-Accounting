import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm, BooleanExpressionOperators;
import 'package:uuid/uuid.dart';
 
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
 
// ─── Tab enum ─────────────────────────────────────────────
enum _PurchaseTab { orders, vendors }
 
class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});
 
  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}
 
class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  _PurchaseTab _tab = _PurchaseTab.orders;
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bgApp,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow:  'Procurement',
            title:    'Purchases',
            subtitle: 'Vendors, purchase orders and goods receipt',
            actions: [
              if (_tab == _PurchaseTab.orders)
                GoldButton(label: 'New PO', icon: Icons.add_rounded,
                    onPressed: () => _showPoDialog(context)),
              if (_tab == _PurchaseTab.vendors)
                GoldButton(label: 'Add Vendor', icon: Icons.add_rounded,
                    onPressed: () => _showVendorDialog(context)),
            ],
          ),
          Container(
            color: D.bgSurface,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                _TabBtn(label: 'Purchase Orders', icon: Icons.receipt_rounded,
                    active: _tab == _PurchaseTab.orders,
                    onTap: () => setState(() => _tab = _PurchaseTab.orders)),
                SizedBox(width: 0.5.w),
                _TabBtn(label: 'Vendors', icon: Icons.people_alt_rounded,
                    active: _tab == _PurchaseTab.vendors,
                    onTap: () => setState(() => _tab = _PurchaseTab.vendors)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _tab == _PurchaseTab.orders
                ? _PurchaseOrderList(onNewPo: () => _showPoDialog(context))
                    .animate().fadeIn(duration: 250.ms)
                : _VendorList(onAdd: () => _showVendorDialog(context))
                    .animate().fadeIn(duration: 250.ms),
          ),
        ],
      ),
    );
  }
 
  void _showPoDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewPoDialog(onCreate: _createPo),
    );
  }
 
  void _showVendorDialog(BuildContext context, {Vendor? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VendorDialog(
        existing: existing,
        onSave: (name, phone, ntn, balance) =>
            _saveVendor(existing?.id, name, phone, ntn, balance),
      ),
    );
  }
 
  Future<void> _createPo(String vendorId, String notes, List<_PoLineItem> items) async {
    await AppErrorHandler.guard(
      ref:            ref,
      context:        context,
      successMessage: 'Purchase order created',
      action: () async {
        final db       = ref.read(databaseProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final branchId = ref.read(currentBranchIdProvider);
        const uuid     = Uuid();
        final poId     = uuid.v4();
        final now      = DateTime.now();
        final ts       = now.millisecondsSinceEpoch;
 
        final subtotal = items.fold(0.0, (s, i) => s + i.unitCost * i.qty);
        final taxAmt   = items.fold(0.0, (s, i) => s + i.unitCost * i.qty * i.taxRate / 100);
 
        final allPos = await db.select(db.purchaseOrders).get();
        final poNumber = 'PO-${(allPos.length + 1).toString().padLeft(5, '0')}';
 
        await db.into(db.purchaseOrders).insert(PurchaseOrdersCompanion.insert(
          id:          poId,
          tenantId:    tenantId,
          branchId:    branchId,
          vendorId:    vendorId,
          poNumber:    poNumber,
          orderDate:   now,
          subtotal:    Value(subtotal),
          taxAmount:   Value(taxAmt),
          totalAmount: Value(subtotal + taxAmt),
          notes:       Value(notes.isEmpty ? null : notes),
          updatedAt:   Value(ts),
        ));
 
        for (final item in items) {
          await db.into(db.purchaseOrderItems).insert(PurchaseOrderItemsCompanion.insert(
            id:          uuid.v4(),
            poId:        poId,
            productId:   item.productId,
            qtyOrdered:  item.qty,
            unitCost:    item.unitCost,
            taxRate:     Value(item.taxRate),
            lineTotal:   item.qty * item.unitCost * (1 + item.taxRate / 100),
          ));
        }
 
        ref.read(syncEngineProvider).enqueue(
          entityType: 'purchase_orders',
          entityId:   poId,
          operation:  'insert',
          payload: {
            'id':          poId,
            'tenant_id':   tenantId,
            'branch_id':   branchId,
            'vendor_id':   vendorId,
            'po_number':   poNumber,
            'total_amount': subtotal + taxAmt,
            'updated_at':  ts,
          },
        );
      },
    );
  }
 
  Future<void> _saveVendor(
    String? existingId, String name, String phone, String ntn, double balance,
  ) async {
    await AppErrorHandler.guard(
      ref:            ref,
      context:        context,
      successMessage: existingId == null ? 'Vendor added' : 'Vendor updated',
      action: () async {
        final db       = ref.read(databaseProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final id       = existingId ?? const Uuid().v4();
        final ts       = DateTime.now().millisecondsSinceEpoch;
 
        await db.into(db.vendors).insertOnConflictUpdate(VendorsCompanion.insert(
          id:        id,
          tenantId:  tenantId,
          name:      name,
          phone:     Value(phone.isEmpty ? null : phone),
          ntn:       Value(ntn.isEmpty ? null : ntn),
          balance:   Value(balance),
          updatedAt: Value(ts),
        ));
 
        ref.read(syncEngineProvider).enqueue(
          entityType: 'vendors',
          entityId:   id,
          operation:  existingId == null ? 'insert' : 'update',
          payload: {
            'id':         id,
            'tenant_id':  tenantId,
            'name':       name,
            'phone':      phone.isEmpty ? null : phone,
            'ntn':        ntn.isEmpty ? null : ntn,
            'balance':    balance,
            'updated_at': ts,
          },
        );
      },
    );
  }
}
 
// ─── PO List ──────────────────────────────────────────────
class _PurchaseOrderList extends ConsumerWidget {
  final VoidCallback onNewPo;
  const _PurchaseOrderList({required this.onNewPo});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db       = ref.watch(databaseProvider);
    final branchId = ref.watch(currentBranchIdProvider);
 
    return StreamBuilder<List<PurchaseOrder>>(
      stream: (db.select(db.purchaseOrders)
            ..where((t) => t.branchId.equals(branchId) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.orderDate)]))
          .watch(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: D.gold400));
        }
        final orders = snap.data!;
        if (orders.isEmpty) {
          return EmptyState(
            icon:    Icons.receipt_long_rounded,
            title:   'No purchase orders yet',
            message: 'Create your first PO to start tracking stock intake',
            action:  GoldButton(
              label: 'New Purchase Order', icon: Icons.add_rounded, onPressed: onNewPo,
            ),
          );
        }
 
        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: ErpCard(
            goldRule: true,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(1.5.w),
                  child: Row(
                    children: [
                      _PoStat(label: 'Total Orders', value: orders.length.toString()),
                      _PoStat(label: 'Draft',
                          value: orders.where((o) => o.status == 'draft').length.toString(),
                          color: D.warning500),
                      _PoStat(label: 'Confirmed',
                          value: orders.where((o) => o.status == 'confirmed').length.toString(),
                          color: D.info500),
                      _PoStat(label: 'Received',
                          value: orders.where((o) => o.status == 'received').length.toString(),
                          color: D.brand500),
                    ],
                  ),
                ),
                const Divider(height: 1, color: D.borderGold),
                ErpTable(
                  headers: const ['PO Number', 'Vendor', 'Date', 'Total', 'Status', 'Actions'],
                  numericCols: const [false, false, false, true, false, false],
                  rows: orders.map((po) => [
                    Text(po.poNumber,
                      style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12,
                          fontWeight: FontWeight.w500, color: D.fgPrimary)),
                    _VendorNameCell(vendorId: po.vendorId),
                    Text('${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: D.fgSecondary)),
                    AmountText(po.totalAmount, fontSize: 12),
                    _PoStatusBadge(po.status),
                    _PoActionsCell(po: po),
                  ]).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
 
class _VendorNameCell extends ConsumerWidget {
  final String vendorId;
  const _VendorNameCell({required this.vendorId});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Vendor?>(
      future: (db.select(db.vendors)..where((v) => v.id.equals(vendorId))).getSingleOrNull(),
      builder: (_, snap) => Text(snap.data?.name ?? '—',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: D.fgPrimary)),
    );
  }
}
 
class _PoStatusBadge extends StatelessWidget {
  final String status;
  const _PoStatusBadge(this.status);
 
  @override
  Widget build(BuildContext context) => switch (status) {
    'confirmed' => StatusBadge.info('Confirmed'),
    'received'  => StatusBadge.success('Received'),
    _           => StatusBadge.warning('Draft'),
  };
}
 
class _PoActionsCell extends ConsumerWidget {
  final PurchaseOrder po;
  const _PoActionsCell({required this.po});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (po.status == 'draft')
          _ActionBtn(label: 'Confirm', color: D.info500,
              onTap: () => _updateStatus(ref, context, 'confirmed')),
        if (po.status == 'confirmed')
          _ActionBtn(label: 'Receive (GRN)', color: D.brand500,
              onTap: () => _receiveGrn(ref, context)),
      ],
    );
  }
 
  Future<void> _updateStatus(WidgetRef ref, BuildContext context, String status) async {
    await AppErrorHandler.guard(
      ref:            ref,
      context:        context,
      successMessage: 'PO status updated',
      action: () async {
        final db = ref.read(databaseProvider);
        final ts = DateTime.now().millisecondsSinceEpoch;
        await (db.update(db.purchaseOrders)..where((t) => t.id.equals(po.id)))
            .write(PurchaseOrdersCompanion(status: Value(status), updatedAt: Value(ts)));
        ref.read(syncEngineProvider).enqueue(
          entityType: 'purchase_orders',
          entityId:   po.id,
          operation:  'update',
          payload:    {'id': po.id, 'status': status, 'updated_at': ts},
        );
      },
    );
  }
 
  Future<void> _receiveGrn(WidgetRef ref, BuildContext context) async {
    await AppErrorHandler.guard(
      ref:            ref,
      context:        context,
      successMessage: 'GRN recorded — inventory updated',
      action: () async {
        final db       = ref.read(databaseProvider);
        final branchId = ref.read(currentBranchIdProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final ts       = DateTime.now().millisecondsSinceEpoch;
 
        final items = await (db.select(db.purchaseOrderItems)
              ..where((t) => t.poId.equals(po.id)))
            .get();
 
        for (final item in items) {
          final inv = await (db.select(db.inventory)
                ..where((t) =>
                    t.productId.equals(item.productId) & t.branchId.equals(branchId)))
              .getSingleOrNull();
 
          if (inv != null) {
            await (db.update(db.inventory)..where((t) => t.id.equals(inv.id)))
                .write(InventoryCompanion(
              qtyOnHand: Value(inv.qtyOnHand + item.qtyOrdered),
              updatedAt: Value(ts),
            ));
            ref.read(syncEngineProvider).enqueue(
              entityType: 'inventory',
              entityId:   inv.id,
              operation:  'update',
              payload: {
                'id':          inv.id,
                'qty_on_hand': inv.qtyOnHand + item.qtyOrdered,
                'updated_at':  ts,
              },
            );
          } else {
            final invId = const Uuid().v4();
            await db.into(db.inventory).insert(InventoryCompanion.insert(
              id:        invId,
              tenantId:  tenantId,
              branchId:  branchId,
              productId: item.productId,
              qtyOnHand: Value(item.qtyOrdered),
              updatedAt: Value(ts),
            ));
            ref.read(syncEngineProvider).enqueue(
              entityType: 'inventory',
              entityId:   invId,
              operation:  'insert',
              payload: {
                'id':          invId,
                'tenant_id':   tenantId,
                'branch_id':   branchId,
                'product_id':  item.productId,
                'qty_on_hand': item.qtyOrdered,
                'updated_at':  ts,
              },
            );
          }
 
          await (db.update(db.purchaseOrderItems)..where((t) => t.id.equals(item.id)))
              .write(PurchaseOrderItemsCompanion(qtyReceived: Value(item.qtyOrdered)));
        }
 
        await (db.update(db.purchaseOrders)..where((t) => t.id.equals(po.id)))
            .write(PurchaseOrdersCompanion(
          status:    const Value('received'),
          updatedAt: Value(ts),
        ));
        ref.read(syncEngineProvider).enqueue(
          entityType: 'purchase_orders',
          entityId:   po.id,
          operation:  'update',
          payload:    {'id': po.id, 'status': 'received', 'updated_at': ts},
        );
      },
    );
  }
}
 
class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});
 
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
        style: TextStyle(fontFamily: 'Inter', fontSize: 11,
            fontWeight: FontWeight.w600, color: color)),
    ),
  );
}
 
class _PoStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _PoStat({required this.label, required this.value, this.color = D.fgPrimary});
 
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value,
          style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 18,
              fontWeight: FontWeight.w600, color: color)),
        Text(label.toUpperCase(),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 10,
              fontWeight: FontWeight.w700, color: D.fgTertiary, letterSpacing: 0.1)),
      ],
    ),
  );
}
 
// ─── Vendor List ──────────────────────────────────────────
class _VendorList extends ConsumerWidget {
  final VoidCallback onAdd;
  const _VendorList({required this.onAdd});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db       = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);
 
    return StreamBuilder<List<Vendor>>(
      stream: (db.select(db.vendors)
            ..where((t) => t.tenantId.equals(tenantId) & t.isDeleted.equals(false)))
          .watch(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: D.gold400));
        }
        final vendors = snap.data!;
        if (vendors.isEmpty) {
          return EmptyState(
            icon:    Icons.people_alt_rounded,
            title:   'No vendors yet',
            message: 'Add suppliers to create purchase orders',
            action:  GoldButton(label: 'Add Vendor', icon: Icons.add_rounded, onPressed: onAdd),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(3.w),
          child: ErpCard(
            goldRule: true,
            padding: EdgeInsets.zero,
            child: ErpTable(
              headers: const ['Vendor', 'Phone', 'NTN', 'Balance', 'Actions'],
              numericCols: const [false, false, false, true, false],
              rows: vendors.map((v) => [
                Text(v.name,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                      fontWeight: FontWeight.w500, color: D.fgPrimary)),
                Text(v.phone ?? '—',
                  style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: D.fgSecondary)),
                Text(v.ntn ?? '—',
                  style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: D.fgSecondary)),
                AmountText(v.balance, fontSize: 12),
                _VendorEditBtn(vendor: v),
              ]).toList(),
            ),
          ),
        );
      },
    );
  }
}
 
class _VendorEditBtn extends ConsumerWidget {
  final Vendor vendor;
  const _VendorEditBtn({required this.vendor});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.edit_rounded, size: 15, color: D.fgTertiary),
      onPressed: () => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _VendorDialog(
          existing: vendor,
          onSave: (name, phone, ntn, balance) async {
            await AppErrorHandler.guard(
              ref:            ref,
              context:        context,
              successMessage: 'Vendor updated',
              action: () async {
                final db = ref.read(databaseProvider);
                final ts = DateTime.now().millisecondsSinceEpoch;
                await (db.update(db.vendors)..where((v) => v.id.equals(vendor.id)))
                    .write(VendorsCompanion(
                  name:      Value(name),
                  phone:     Value(phone.isEmpty ? null : phone),
                  ntn:       Value(ntn.isEmpty ? null : ntn),
                  balance:   Value(balance),
                  updatedAt: Value(ts),
                ));
                ref.read(syncEngineProvider).enqueue(
                  entityType: 'vendors',
                  entityId:   vendor.id,
                  operation:  'update',
                  payload: {
                    'id': vendor.id, 'name': name,
                    'phone': phone.isEmpty ? null : phone,
                    'ntn': ntn.isEmpty ? null : ntn,
                    'balance': balance, 'updated_at': ts,
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
 
// ─── Tab Button ───────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.icon, required this.active, required this.onTap});
 
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
 
// ─── Vendor Dialog ────────────────────────────────────────
class _VendorDialog extends StatefulWidget {
  final Vendor? existing;
  final Future<void> Function(String name, String phone, String ntn, double balance) onSave;
  const _VendorDialog({this.existing, required this.onSave});
 
  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}
 
class _VendorDialogState extends State<_VendorDialog> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _ntnCtrl     = TextEditingController();
  final _balanceCtrl = TextEditingController();
 
  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text    = widget.existing!.name;
      _phoneCtrl.text   = widget.existing!.phone ?? '';
      _ntnCtrl.text     = widget.existing!.ntn ?? '';
      _balanceCtrl.text = widget.existing!.balance.toString();
    }
  }
 
  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _ntnCtrl.dispose(); _balanceCtrl.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      child: Container(
        width: 400,
        padding: EdgeInsets.all(2.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Edit Vendor' : 'Add Vendor',
              style: const TextStyle(fontFamily: 'Instrument Serif', fontSize: 22, color: D.ink800)),
            SizedBox(height: 1.5.h),
            ErpField(label: 'Vendor Name', controller: _nameCtrl, required: true),
            SizedBox(height: 1.h),
            Row(children: [
              Expanded(child: ErpField(label: 'Phone', controller: _phoneCtrl)),
              SizedBox(width: 1.w),
              Expanded(child: ErpField(label: 'NTN', controller: _ntnCtrl)),
            ]),
            SizedBox(height: 1.h),
            ErpField(label: 'Opening Balance (PKR)', controller: _balanceCtrl,
                keyboardType: TextInputType.number),
            SizedBox(height: 2.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                SizedBox(width: 1.w),
                GoldButton(
                  label: isEdit ? 'Update' : 'Add Vendor',
                  onPressed: () async {
                    if (_nameCtrl.text.trim().isEmpty) return;
                    await widget.onSave(
                      _nameCtrl.text.trim(), _phoneCtrl.text.trim(),
                      _ntnCtrl.text.trim(), double.tryParse(_balanceCtrl.text) ?? 0,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
 
// ─── PO line item model ───────────────────────────────────
class _PoLineItem {
  final String productId;
  final double qty, unitCost, taxRate;
  _PoLineItem({required this.productId, required this.qty,
      required this.unitCost, required this.taxRate});
}
 
// ─── New PO Dialog ────────────────────────────────────────
class _NewPoDialog extends ConsumerStatefulWidget {
  final Future<void> Function(String vendorId, String notes, List<_PoLineItem> items) onCreate;
  const _NewPoDialog({required this.onCreate});
 
  @override
  ConsumerState<_NewPoDialog> createState() => _NewPoDialogState();
}
 
class _NewPoDialogState extends ConsumerState<_NewPoDialog> {
  String? _selectedVendorId;
  String? _selectedProductId;
  final _notesCtrl = TextEditingController();
  final _qtyCtrl   = TextEditingController(text: '1');
  final _costCtrl  = TextEditingController();
  final _taxCtrl   = TextEditingController(text: '17');
  final List<_PoLineItem> _lines = [];
 
  @override
  void dispose() {
    _notesCtrl.dispose(); _qtyCtrl.dispose();
    _costCtrl.dispose(); _taxCtrl.dispose();
    super.dispose();
  }
 
  void _addLine() {
    if (_selectedProductId == null) return;
    final qty  = double.tryParse(_qtyCtrl.text) ?? 1;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final tax  = double.tryParse(_taxCtrl.text) ?? 17;
    setState(() {
      _lines.add(_PoLineItem(productId: _selectedProductId!,
          qty: qty, unitCost: cost, taxRate: tax));
      _selectedProductId = null;
      _qtyCtrl.text = '1'; _costCtrl.clear();
    });
  }
 
  @override
  Widget build(BuildContext context) {
    final db       = ref.watch(databaseProvider);
    final tenantId = ref.watch(currentTenantIdProvider);
    final total    = _lines.fold(0.0, (s, l) => s + l.qty * l.unitCost * (1 + l.taxRate / 100));
 
    return Dialog(
      child: Container(
        width: 620,
        padding: EdgeInsets.all(2.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Purchase Order',
                style: TextStyle(fontFamily: 'Instrument Serif', fontSize: 24, color: D.ink800)),
              SizedBox(height: 1.5.h),
 
              // Vendor selector
              FutureBuilder<List<Vendor>>(
                future: (db.select(db.vendors)
                      ..where((v) => v.tenantId.equals(tenantId) & v.isDeleted.equals(false)))
                    .get(),
                builder: (_, snap) {
                  final vendors = snap.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vendor *',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11.sp,
                            fontWeight: FontWeight.w500, color: D.fgSecondary)),
                      SizedBox(height: 0.4.h),
                      DropdownButtonFormField<String>(
                        value:       _selectedVendorId,
                        decoration:  const InputDecoration(),
                        hint:        const Text('Select vendor'),
                        items:       vendors.map((v) => DropdownMenuItem(
                            value: v.id, child: Text(v.name))).toList(),
                        onChanged: (v) => setState(() => _selectedVendorId = v),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 1.h),
 
              // Product line add row
              FutureBuilder<List<Product>>(
                future: (db.select(db.products)
                      ..where((p) => p.tenantId.equals(tenantId) & p.isDeleted.equals(false)))
                    .get(),
                builder: (_, snap) {
                  final products = snap.data ?? [];
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Product',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11.sp,
                                  fontWeight: FontWeight.w500, color: D.fgSecondary)),
                            SizedBox(height: 0.4.h),
                            DropdownButtonFormField<String>(
                              value:      _selectedProductId,
                              decoration: const InputDecoration(),
                              hint:       const Text('Select product'),
                              items:      products.map((p) => DropdownMenuItem(
                                  value: p.id, child: Text(p.name))).toList(),
                              onChanged: (v) => setState(() => _selectedProductId = v),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 0.8.w),
                      Expanded(child: ErpField(label: 'Qty',      controller: _qtyCtrl,  keyboardType: TextInputType.number)),
                      SizedBox(width: 0.8.w),
                      Expanded(child: ErpField(label: 'Cost (PKR)', controller: _costCtrl, keyboardType: TextInputType.number)),
                      SizedBox(width: 0.8.w),
                      Expanded(child: ErpField(label: 'Tax %',    controller: _taxCtrl,  keyboardType: TextInputType.number)),
                      SizedBox(width: 0.8.w),
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: ElevatedButton(
                          onPressed: _addLine,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: D.brand500,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 1.h),
 
              // Lines preview
              if (_lines.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: D.bgCream,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: D.borderGold),
                  ),
                  child: Column(
                    children: _lines.asMap().entries.map((e) {
                      final l = e.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: D.borderSubtle))),
                        child: Row(
                          children: [
                            _ProductNameWidget(productId: l.productId),
                            SizedBox(width: 1.w),
                            Text('${l.qty} × ${Fmt.pkrShort(l.unitCost)}',
                              style: const TextStyle(fontFamily: 'JetBrains Mono',
                                  fontSize: 11, color: D.fgSecondary)),
                            const Spacer(),
                            Text(Fmt.pkr(l.qty * l.unitCost * (1 + l.taxRate / 100)),
                              style: const TextStyle(fontFamily: 'JetBrains Mono',
                                  fontSize: 12, fontWeight: FontWeight.w600, color: D.fgPrimary)),
                            SizedBox(width: 0.8.w),
                            GestureDetector(
                              onTap: () => setState(() => _lines.removeAt(e.key)),
                              child: const Icon(Icons.close_rounded, size: 14, color: D.danger500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 0.8.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: ${Fmt.pkr(total)}',
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14,
                        fontWeight: FontWeight.w700, color: D.gold600)),
                ),
                SizedBox(height: 1.h),
              ],
 
              ErpField(label: 'Notes', controller: _notesCtrl, maxLines: 2),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  SizedBox(width: 1.w),
                  GoldButton(
                    label: 'Create PO',
                    icon:  Icons.check_rounded,
                    onPressed: () async {
                      if (_selectedVendorId == null || _lines.isEmpty) return;
                      await widget.onCreate(_selectedVendorId!, _notesCtrl.text, _lines);
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
 
class _ProductNameWidget extends ConsumerWidget {
  final String productId;
  const _ProductNameWidget({required this.productId});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Product?>(
      future: (db.select(db.products)..where((p) => p.id.equals(productId))).getSingleOrNull(),
      builder: (_, snap) => Text(snap.data?.name ?? productId,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
            fontWeight: FontWeight.w500, color: D.fgPrimary)),
    );
  }
}