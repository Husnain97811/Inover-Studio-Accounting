// lib/features/inventory/screens/inventory_screen.dart
// Responsive (sizer). Adds Opening Stock + Reorder Level + MRP fields.
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

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _State();
}

class _State extends ConsumerState<InventoryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(currentTenantIdProvider);
    final branchId = ref.watch(currentBranchIdProvider);
    final db = ref.watch(databaseProvider);
    final role = ref.watch(currentRoleProvider);
    final bizType = ref.watch(businessTypeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            eyebrow: 'Stock Management',
            title: bizType.productLabel,
            actions: [
              if (role.canManageProducts)
                ElevatedButton.icon(
                  onPressed: () => _showDialog(context),
                  icon: Icon(Icons.add_rounded, size: 13.sp),
                  label: Text('Add Product', style: TextStyle(fontSize: 11.sp)),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 0),
            child: TextField(
              style: TextStyle(fontFamily: 'Inter', fontSize: 11.sp),
              decoration: InputDecoration(
                hintText: 'Search ${bizType.productLabel.toLowerCase()}…',
                prefixIcon: const Icon(
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
            child: StreamBuilder<List<Product>>(
              stream:
                  (db.select(db.products)
                        ..where(
                          (t) =>
                              t.tenantId.equals(tenantId) &
                              t.isDeleted.equals(false),
                        )
                        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                      .watch(),
              builder: (_, snap) {
                final all = snap.data ?? [];
                final products = _q.isEmpty
                    ? all
                    : all
                          .where(
                            (p) =>
                                p.name.toLowerCase().contains(_q) ||
                                (p.sku?.toLowerCase().contains(_q) ?? false),
                          )
                          .toList();

                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No ${bizType.productLabel}',
                    message: 'Add your first product to get started.',
                    action: role.canManageProducts
                        ? ElevatedButton.icon(
                            onPressed: () => _showDialog(context),
                            icon: Icon(Icons.add_rounded, size: 13.sp),
                            label: Text(
                              'Add Product',
                              style: TextStyle(fontSize: 11.sp),
                            ),
                          )
                        : null,
                  );
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 4.h),
                  child: ErpCard(
                    padding: EdgeInsets.zero,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        // Responsive: drop SKU & PCT columns on narrow widths.
                        final showSku = c.maxWidth > 620;
                        final showPct = c.maxWidth > 520;
                        final widths = <int, TableColumnWidth>{};
                        var i = 0;
                        widths[i++] = const FlexColumnWidth(3); // product
                        if (showSku) widths[i++] = const FlexColumnWidth(1.5);
                        if (showPct) widths[i++] = const FlexColumnWidth(1.5);
                        widths[i++] = const FlexColumnWidth(1.4); // price
                        widths[i++] = const FlexColumnWidth(1); // stock
                        widths[i] = const FixedColumnWidth(94); // edit

                        final headers = <String>[
                          'Product',
                          if (showSku) 'SKU',
                          if (showPct) 'PCT',
                          'Price',
                          'Stock',
                          '',
                        ];

                        return Table(
                          columnWidths: widths,
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: D.bgCream),
                              children: [
                                for (final h in headers)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 1.4.w,
                                      vertical: 1.h,
                                    ),
                                    child: Text(
                                      h.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w700,
                                        color: D.gold600,
                                        letterSpacing: 0.12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            ...products.map((p) {
                              final hasMrp =
                                  p.mrp != null && p.mrp! > p.salePrice;
                              final cells = <Widget>[];
                              cells.add(
                                _tc(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w500,
                                          color: D.fgPrimary,
                                        ),
                                      ),
                                      if (!p.isActive)
                                        StatusBadge.neutral('Inactive'),
                                    ],
                                  ),
                                ),
                              );
                              if (showSku) {
                                cells.add(
                                  _tc(
                                    Text(
                                      p.sku ?? '—',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 10.sp,
                                        color: D.fgSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (showPct) {
                                cells.add(
                                  _tc(
                                    Text(
                                      p.pctCode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 10.sp,
                                        color: D.brand600,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              cells.add(
                                _tc(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (hasMrp)
                                        Text(
                                          'Rs. ${Fmt.pkrShort(p.mrp!)}',
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 8.5.sp,
                                            color: D.fgTertiary,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Text(
                                        'Rs. ${Fmt.pkrShort(p.salePrice)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: D.fgPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              cells.add(
                                _tc(
                                  _StockCell(
                                    branchId: branchId,
                                    productId: p.id,
                                    db: db,
                                  ),
                                ),
                              );
                              cells.add(
                                _tc(
                                  role.canManageProducts
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.edit_rounded,
                                            size: 13.sp,
                                            color: D.fgTertiary,
                                          ),
                                          onPressed: () =>
                                              _showDialog(context, product: p),
                                          style: IconButton.styleFrom(
                                            minimumSize: const Size(28, 28),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );

                              return TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: D.borderSubtle),
                                  ),
                                ),
                                children: cells,
                              );
                            }),
                          ],
                        );
                      },
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

  Widget _tc(Widget child) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 1.4.w, vertical: 1.2.h),
    child: child,
  );

  void _showDialog(BuildContext ctx, {Product? product}) {
    showDialog(
      context: ctx,
      builder: (_) => _ProductDialog(product: product),
    );
  }
}

class _StockCell extends StatelessWidget {
  final String branchId, productId;
  final AppDatabase db;
  const _StockCell({
    required this.branchId,
    required this.productId,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryData>>(
      stream:
          (db.select(db.inventory)..where(
                (t) =>
                    t.branchId.equals(branchId) & t.productId.equals(productId),
              ))
              .watch(),
      builder: (_, snap) {
        final qty = snap.data?.isNotEmpty == true
            ? snap.data!.first.qtyOnHand
            : 0.0;
        final color = qty <= 0
            ? D.danger500
            : qty <= 5
            ? D.warning500
            : D.success500;
        return Text(
          Fmt.qty(qty),
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
      },
    );
  }
}

class _ProductDialog extends ConsumerStatefulWidget {
  final Product? product;
  const _ProductDialog({this.product});
  @override
  ConsumerState<_ProductDialog> createState() => _PDState();
}

class _PDState extends ConsumerState<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barCtrl = TextEditingController();
  final _pctCtrl = TextEditingController(text: '9999.99');
  final _costCtrl = TextEditingController(text: '0');
  final _priceCtrl = TextEditingController(text: '0');
  final _mrpCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '17');
  final _stockCtrl = TextEditingController(text: '0');
  final _reorderCtrl = TextEditingController(text: '0');

  bool _loadingStock = false;

  @override
  void initState() {
    super.initState();
    if (widget.product case final p?) {
      _nameCtrl.text = p.name;
      _skuCtrl.text = p.sku ?? '';
      _barCtrl.text = p.barcode ?? '';
      _pctCtrl.text = p.pctCode;
      _costCtrl.text = p.costPrice.toString();
      _priceCtrl.text = p.salePrice.toString();
      _mrpCtrl.text = (p.mrp ?? 0).toString();
      _taxCtrl.text = (p.taxRate ?? 17.0).toString();
      _loadExistingStock(p.id);
    }
  }

  Future<void> _loadExistingStock(String productId) async {
    setState(() => _loadingStock = true);
    final db = ref.read(databaseProvider);
    final branchId = ref.read(currentBranchIdProvider);
    final inv =
        await (db.select(db.inventory)..where(
              (t) =>
                  t.branchId.equals(branchId) & t.productId.equals(productId),
            ))
            .getSingleOrNull();
    if (inv != null) {
      _stockCtrl.text = Fmt.qty(inv.qtyOnHand);
      _reorderCtrl.text = Fmt.qty(inv.reorderLevel);
    }
    if (mounted) setState(() => _loadingStock = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barCtrl.dispose();
    _pctCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _mrpCtrl.dispose();
    _taxCtrl.dispose();
    _stockCtrl.dispose();
    _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      message: widget.product == null ? 'Adding…' : 'Saving…',
      successMessage: widget.product == null ? 'Product added!' : 'Updated!',
      action: () async {
        final db = ref.read(databaseProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final branchId = ref.read(currentBranchIdProvider);
        final id = widget.product?.id ?? const Uuid().v4();
        final now = DateTime.now().millisecondsSinceEpoch;

        final mrp = double.tryParse(_mrpCtrl.text) ?? 0;
        await db
            .into(db.products)
            .insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: _nameCtrl.text.trim(),
                sku: Value(
                  _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
                ),
                barcode: Value(
                  _barCtrl.text.trim().isEmpty ? null : _barCtrl.text.trim(),
                ),
                pctCode: Value(_pctCtrl.text.trim()),
                costPrice: Value(double.tryParse(_costCtrl.text) ?? 0.0),
                salePrice: Value(double.tryParse(_priceCtrl.text) ?? 0.0),
                mrp: Value(mrp <= 0 ? null : mrp),
                taxRate: Value(double.tryParse(_taxCtrl.text)),
                updatedAt: Value(now),
              ),
            );

        // Inventory row — now writes the real opening stock + reorder level.
        await db
            .into(db.inventory)
            .insertOnConflictUpdate(
              InventoryCompanion.insert(
                id: '${branchId}_$id',
                tenantId: tenantId,
                branchId: branchId,
                productId: id,
                qtyOnHand: Value(double.tryParse(_stockCtrl.text) ?? 0.0),
                reorderLevel: Value(double.tryParse(_reorderCtrl.text) ?? 0.0),
                updatedAt: Value(now),
              ),
            );
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;
    return Dialog(
      child: Container(
        width: 90.w.clamp(360.0, 520.0),
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
                      isNew ? 'Add Product' : 'Edit Product',
                      style: TextStyle(
                        fontFamily: 'Instrument Serif',
                        fontSize: 20.sp,
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
                  label: 'Product Name',
                  controller: _nameCtrl,
                  required: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: 1.4.h),
                Row(
                  children: [
                    Expanded(
                      child: ErpField(label: 'SKU', controller: _skuCtrl),
                    ),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: ErpField(label: 'Barcode', controller: _barCtrl),
                    ),
                  ],
                ),
                SizedBox(height: 1.4.h),
                Row(
                  children: [
                    Expanded(
                      child: ErpField(
                        label: 'PCT Code (FBR)',
                        controller: _pctCtrl,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: ErpField(
                        label: 'Tax Rate %',
                        controller: _taxCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.4.h),
                Row(
                  children: [
                    Expanded(
                      child: ErpField(
                        label: 'Cost Price (PKR)',
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: ErpField(
                        label: 'Sale Price (PKR)',
                        controller: _priceCtrl,
                        required: true,
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0
                            ? 'Invalid'
                            : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.4.h),
                Row(
                  children: [
                    Expanded(
                      child: ErpField(
                        label: 'MRP / List Price (optional)',
                        controller: _mrpCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: ErpField(
                        label: 'Reorder Level',
                        controller: _reorderCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.4.h),
                // Opening / current stock
                ErpField(
                  label: isNew ? 'Opening Stock' : 'Current Stock',
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                ),
                if (_loadingStock)
                  Padding(
                    padding: EdgeInsets.only(top: 1.h),
                    child: const LinearProgressIndicator(),
                  ),
                SizedBox(height: 0.6.h),
                Text(
                  isNew
                      ? 'Stock you currently have on hand for this branch.'
                      : 'Editing sets the absolute stock value for this branch.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.sp,
                    color: D.fgTertiary,
                    fontStyle: FontStyle.italic,
                  ),
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
                      child: Text(isNew ? 'Add Product' : 'Save Changes'),
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
