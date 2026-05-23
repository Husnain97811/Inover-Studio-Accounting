// lib/features/pos/screens/pos_screen.dart
import 'package:drift/drift.dart'
    show Value, Variable, OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/views.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_search_field.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _screenFocus = FocusNode();
  int? _selIdx;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.f1:
        _searchFocus.requestFocus();
      case LogicalKeyboardKey.f10:
        _openPayment();
      case LogicalKeyboardKey.f12:
        _reprintLast();
      case LogicalKeyboardKey.escape:
        _clearCart();
      case LogicalKeyboardKey.delete:
        if (_selIdx != null)
          ref.read(cartProvider.notifier).removeItem(_selIdx!);
      case LogicalKeyboardKey.numpadAdd:
        if (_selIdx != null) {
          final item = ref.read(cartProvider).items[_selIdx!];
          ref
              .read(cartProvider.notifier)
              .updateQty(_selIdx!, item.quantity + 1);
        }
      case LogicalKeyboardKey.numpadSubtract:
        if (_selIdx != null) {
          final item = ref.read(cartProvider).items[_selIdx!];
          ref
              .read(cartProvider.notifier)
              .updateQty(_selIdx!, item.quantity - 1);
        }
    }
  }

  void _addProduct(Product p, double qty) {
    ref
        .read(cartProvider.notifier)
        .addItem(
          CartItem(
            productId: p.id,
            name: p.name,
            pctCode: p.pctCode,
            unitPrice: p.salePrice,
            taxRate: p.isTaxExempt ? 0.0 : p.taxRate ?? 17.0,
            quantity: qty,
          ),
        );
    _searchCtrl.clear();
    _searchFocus.requestFocus();
  }

  void _openPayment() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      AppErrorHandler.showInfo(context, 'Cart is empty');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(cart: cart, onConfirm: _processPayment),
    );
  }

  Future<void> _processPayment(CartState cart, String mode, double paid) async {
    await AppErrorHandler.guard(
      ref: ref,
      context: context,
      message: 'Saving invoice…',
      action: () async {
        final db = ref.read(databaseProvider);
        final branchId = ref.read(currentBranchIdProvider);
        final tenantId = ref.read(currentTenantIdProvider);
        final user = ref.read(currentUserProvider);
        const uuid = Uuid();
        final invId = uuid.v4();
        final now = DateTime.now();
        final cnt = await db
            .customSelect(
              'SELECT COUNT(*) as c FROM invoices WHERE tenant_id = ?',
              variables: [Variable.withString(tenantId)],
            )
            .getSingleOrNull();
        final seq = ((cnt?.data['c'] as int?) ?? 0) + 1;
        final invNum = Fmt.invoiceNo(seq);

        await db.transaction(() async {
          await db
              .into(db.invoices)
              .insert(
                InvoicesCompanion.insert(
                  id: invId,
                  tenantId: tenantId,
                  branchId: branchId,
                  invoiceNumber: invNum,
                  invoiceType: const Value('Sale'),
                  invoiceDate: now,
                  paymentMode: Value(mode),
                  cashierId: user?.id ?? 'offline',
                  subtotal: Value(cart.subtotal),
                  discountAmount: Value(cart.totalDiscount),
                  taxableAmount: Value(cart.subtotal - cart.totalDiscount),
                  totalSalesTax: Value(cart.totalTax),
                  totalWithTax: Value(cart.totalWithTax),
                  amountPaid: Value(paid),
                  changeGiven: Value(paid - cart.totalWithTax),
                  fbrStatus: const Value('pending'),
                  createdAt: Value(now.millisecondsSinceEpoch),
                  updatedAt: Value(now.millisecondsSinceEpoch),
                ),
              );
          int order = 0;
          for (final item in cart.items) {
            await db
                .into(db.invoiceItems)
                .insert(
                  InvoiceItemsCompanion.insert(
                    id: uuid.v4(),
                    invoiceId: invId,
                    productId: Value(item.productId),
                    description: item.name,
                    pctCode: Value(item.pctCode),
                    quantity: Value(item.quantity),
                    unitPrice: Value(item.unitPrice),
                    discountRate: Value(item.discountRate),
                    discountAmount: Value(item.discountAmount),
                    taxRate: Value(item.taxRate),
                    taxAmount: Value(item.taxAmount),
                    lineTotal: Value(item.lineTotal),
                    sortOrder: Value(order++),
                  ),
                );
            await db.customUpdate(
              'UPDATE inventory SET qty_on_hand = qty_on_hand - ?, updated_at = ? '
              'WHERE branch_id = ? AND product_id = ?',
              variables: [
                Variable.withReal(item.quantity),
                Variable.withInt(now.millisecondsSinceEpoch),
                Variable.withString(branchId),
                Variable.withString(item.productId),
              ],
            );
          }
        });
        ref.read(cartProvider.notifier).clear();
        ref.invalidate(dashStatsProvider);
        ref.read(fbrServiceProvider).fiscalize(invId).ignore();
      },
    );
  }

  Future<void> _clearCart() async {
    if (ref.read(cartProvider).isEmpty) return;
    final ok = await confirmDialog(
      context,
      title: 'Clear cart?',
      message: 'Remove all items from the current sale?',
      confirmLabel: 'Clear',
      confirmColor: D.danger500,
    );
    if (ok) ref.read(cartProvider.notifier).clear();
  }

  void _reprintLast() =>
      AppErrorHandler.showInfo(context, 'Reprint last receipt — coming soon');

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final bizType = ref.watch(businessTypeProvider);
    final tenantId = ref.watch(currentTenantIdProvider);

    return KeyboardListener(
      focusNode: _screenFocus,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // POS topbar
            _PosHeader(bizType: bizType),

            Expanded(
              child: Row(
                children: [
                  // Left — product search + grid
                  Expanded(
                    child: Column(
                      children: [
                        // Search bar row
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: D.bgSurface,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ProductSearchField(
                                      controller: _searchCtrl,
                                      focusNode: _searchFocus,
                                      tenantId: tenantId,
                                      onSelected: _addProduct,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.barcode_reader,
                                      size: 14,
                                    ),
                                    label: const Text('Scan'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.person_add_outlined,
                                      size: 14,
                                    ),
                                    label: Row(
                                      children: [
                                        const Text('Customer'),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: D.borderDefault,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: const Text(
                                            'F2',
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 10,
                                              color: D.fgSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Category quick filters
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 22,
                                child: Row(
                                  children: [
                                    const Text(
                                      'Quick:',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: D.fgTertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ..._categories(bizType).map(
                                      (c) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: StatusBadge.neutral(c),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: D.borderDefault),

                        // Product grid
                        Expanded(
                          child: Container(
                            color: D.bgApp,
                            child: _ProductGrid(
                              tenantId: tenantId,
                              onTap: _addProduct,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right — cart panel
                  Container(
                    width: 380,
                    decoration: const BoxDecoration(
                      color: D.bgSurface,
                      border: Border(left: BorderSide(color: D.borderDefault)),
                    ),
                    child: _Cart(
                      cart: cart,
                      selIdx: _selIdx,
                      onSelect: (i) => setState(() => _selIdx = i),
                      onPay: _openPayment,
                      onClear: _clearCart,
                    ),
                  ),
                ],
              ),
            ),

            // Keyboard shortcuts bar
            ShortcutBar(
              shortcuts: const [
                ('F1', 'Search'),
                ('F2', 'Customer'),
                ('F10', 'Pay'),
                ('F12', 'Reprint'),
                ('Del', 'Remove'),
                ('Esc', 'Clear'),
                ('+ / −', 'Qty'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _categories(BusinessType bt) => switch (bt) {
    BusinessType.medical => ['Antibiotics', 'OTC', 'Vitamins', 'BP/Cardiac'],
    BusinessType.restaurant => ['Mains', 'Drinks', 'Starters', 'Desserts'],
    BusinessType.bookshop => ['Fiction', 'Academic', 'Children', 'Islamic'],
    _ => ['Grocery', 'Beverage', 'Dairy', 'Bakery', 'Snacks'],
  };
}

class _PosHeader extends StatelessWidget {
  final BusinessType bizType;
  const _PosHeader({required this.bizType});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: D.bgSurface,
        border: Border(bottom: BorderSide(color: D.borderDefault)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.point_of_sale_rounded, size: 15, color: D.brand500),
          const SizedBox(width: 8),
          Text(
            '${bizType.saleLabel} Terminal',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: D.fgPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: D.bgCream,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: D.borderGold),
            ),
            child: Text(
              'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)} · draft',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: D.fgSecondary,
              ),
            ),
          ),
          const Spacer(),
          // FBR indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: D.success50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x330B6B43)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: D.brand500,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'FBR connected',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: D.success700,
                    letterSpacing: 0.04,
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

class _ProductGrid extends ConsumerWidget {
  final String tenantId;
  final void Function(Product, double) onTap;
  const _ProductGrid({required this.tenantId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Product>>(
      stream:
          (db.select(db.products)
                ..where(
                  (t) =>
                      t.tenantId.equals(tenantId) &
                      t.isActive.equals(true) &
                      t.isDeleted.equals(false),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.name)])
                ..limit(40))
              .watch(),
      builder: (_, snap) {
        final products = snap.data ?? [];
        if (products.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No Products',
            message: 'Add products from Inventory to start selling.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 155,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductTile(
            p: products[i],
            onTap: () => onTap(products[i], 1.0),
          ),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product p;
  final VoidCallback onTap;
  const _ProductTile({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: D.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: D.borderDefault),
          boxShadow: const [
            BoxShadow(
              color: Color(0x040A1A11),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Thumbnail area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: D.neutral100,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.sku ?? p.name.substring(0, 2).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: D.fgTertiary,
                  ),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: D.fgPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rs. ${Fmt.pkrShort(p.salePrice)}',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: D.brand700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cart extends ConsumerWidget {
  final CartState cart;
  final int? selIdx;
  final void Function(int) onSelect;
  final VoidCallback onPay;
  final Future<void> Function() onClear;

  const _Cart({
    required this.cart,
    required this.selIdx,
    required this.onSelect,
    required this.onPay,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Cart header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current sale',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: D.fgPrimary,
                    ),
                  ),
                  Text(
                    'draft · ${cart.items.length} items',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: D.fgTertiary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!cart.isEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: D.danger500,
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: D.borderDefault),

        // Cart items
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: D.neutral100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 24,
                          color: D.fgTertiary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Cart is empty.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: D.fgTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan or click a product to add.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: D.fgTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (_, i) => _CartLine(
                    item: cart.items[i],
                    index: i,
                    selected: selIdx == i,
                    onTap: () => onSelect(i),
                  ),
                ),
        ),

        // Summary
        if (!cart.isEmpty) ...[
          const Divider(height: 1, color: D.borderDefault),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SumRow('Subtotal', 'Rs. ${Fmt.pkrShort(cart.subtotal)}'),
                if (cart.totalDiscount > 0)
                  _SumRow(
                    'Discount',
                    '− Rs. ${Fmt.pkrShort(cart.totalDiscount)}',
                    color: D.danger500,
                  ),
                _SumRow('GST (17%)', 'Rs. ${Fmt.pkrShort(cart.totalTax)}'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: D.borderDefault),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: D.fgPrimary,
                        ),
                      ),
                      Text(
                        'Rs. ${Fmt.pkrShort(cart.totalWithTax)}',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: D.fgPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Pay button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onPay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: D.brand500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Checkout',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'F10',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CartLine extends ConsumerWidget {
  final CartItem item;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  const _CartLine({
    required this.item,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: selected ? D.brand50 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: D.fgPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Rs. ${Fmt.pkrShort(item.unitPrice)} ea',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: D.fgTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Qty stepper
            Row(
              children: [
                _QBtn(
                  Icons.remove_rounded,
                  () => cart.updateQty(index, item.quantity - 1),
                ),
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Text(
                      Fmt.qty(item.quantity),
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: D.fgPrimary,
                      ),
                    ),
                  ),
                ),
                _QBtn(
                  Icons.add_rounded,
                  () => cart.updateQty(index, item.quantity + 1),
                ),
              ],
            ),
            // Total
            SizedBox(
              width: 68,
              child: Text(
                'Rs. ${Fmt.pkrShort(item.lineTotal)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: D.fgPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(color: D.borderDefault),
        borderRadius: BorderRadius.circular(4),
        color: D.bgSurface,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 12, color: D.fgSecondary),
    ),
  );
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SumRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: D.fgSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
            color: color ?? D.fgPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
