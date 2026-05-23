// lib/features/inventory/screens/inventory_screen.dart
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
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Add Product'),
                ),
            ],
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
            child: TextField(
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
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

          const SizedBox(height: 16),

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
                            icon: const Icon(Icons.add_rounded, size: 15),
                            label: const Text('Add Product'),
                          )
                        : null,
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: ErpCard(
                    padding: EdgeInsets.zero,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.5),
                        5: FixedColumnWidth(52),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: const BoxDecoration(color: D.bgCream),
                          children:
                              [
                                    'Product',
                                    'SKU',
                                    'PCT Code',
                                    'Sale Price',
                                    'Stock',
                                    '',
                                  ]
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
                        // Rows
                        ...products.map(
                          (p) => TableRow(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: D.borderSubtle),
                              ),
                            ),
                            children: [
                              _TC(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: D.fgPrimary,
                                      ),
                                    ),
                                    if (!p.isActive)
                                      StatusBadge.neutral('Inactive'),
                                  ],
                                ),
                              ),
                              _TC(
                                child: Text(
                                  p.sku ?? '—',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11.5,
                                    color: D.fgSecondary,
                                  ),
                                ),
                              ),
                              _TC(
                                child: Text(
                                  p.pctCode,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11.5,
                                    color: D.brand600,
                                  ),
                                ),
                              ),
                              _TC(
                                child: Text(
                                  'Rs. ${Fmt.pkrShort(p.salePrice)}',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: D.fgPrimary,
                                  ),
                                ),
                              ),
                              _TC(
                                child: _StockCell(
                                  branchId: branchId,
                                  productId: p.id,
                                  db: db,
                                ),
                              ),
                              _TC(
                                child: role.canManageProducts
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 14,
                                          color: D.fgTertiary,
                                        ),
                                        onPressed: () =>
                                            _showDialog(context, product: p),
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(28, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _showDialog(BuildContext ctx, {Product? product}) {
    showDialog(
      context: ctx,
      builder: (_) => _ProductDialog(product: product),
    );
  }
}

class _TC extends StatelessWidget {
  final Widget child;
  const _TC({required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: child,
  );
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
        final double qty = snap.data?.isNotEmpty == true
            ? snap.data!.first.qtyOnHand
            : 0.0;
        final Color color = qty <= 0
            ? D.danger500
            : qty <= 5
            ? D.warning500
            : D.success500;
        return Text(
          Fmt.qty(qty),
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
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
  final _taxCtrl = TextEditingController(text: '17');

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
      _taxCtrl.text = (p.taxRate ?? 17.0).toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barCtrl.dispose();
    _pctCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _taxCtrl.dispose();
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
                taxRate: Value(double.tryParse(_taxCtrl.text)),
                updatedAt: Value(now),
              ),
            );
        await db
            .into(db.inventory)
            .insertOnConflictUpdate(
              InventoryCompanion.insert(
                id: '${branchId}_$id',
                tenantId: tenantId,
                branchId: branchId,
                productId: id,
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
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog title
              Row(
                children: [
                  Text(
                    isNew ? 'Add Product' : 'Edit Product',
                    style: const TextStyle(
                      fontFamily: 'Instrument Serif',
                      fontSize: 24,
                      color: D.ink800,
                      letterSpacing: -0.01,
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
                label: 'Product Name',
                controller: _nameCtrl,
                required: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ErpField(label: 'SKU', controller: _skuCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ErpField(label: 'Barcode', controller: _barCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ErpField(
                      label: 'PCT Code (FBR)',
                      controller: _pctCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ErpField(
                      label: 'Tax Rate %',
                      controller: _taxCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ErpField(
                      label: 'Cost Price (PKR)',
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                    child: Text(isNew ? 'Add Product' : 'Save Changes'),
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
