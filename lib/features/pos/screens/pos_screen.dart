// lib/features/pos/screens/pos_screen.dart
import 'package:drift/drift.dart'
    show Value, Variable, OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/views.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_search_field.dart';

// Product grid stream — isolated so it only rebuilds on DB changes.
final _posProductsProvider = StreamProvider.autoDispose
    .family<List<Product>, String>((ref, tenantId) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.products)
            ..where(
              (t) =>
                  t.tenantId.equals(tenantId) &
                  t.isActive.equals(true) &
                  t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)])
            ..limit(40))
          .watch();
    });
// Live stock map (productId → qtyOnHand) for the current branch.
// Watched by cart lines (to show stock) and the footer (to block checkout).
// valueOrNull is null only while the stream is still loading.
final _branchStockProvider = StreamProvider.autoDispose<Map<String, double>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return (db.select(db.inventory)..where((t) => t.branchId.equals(branchId)))
      .watch()
      .map((rows) => {for (final r in rows) r.productId: r.qtyOnHand});
});

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
      case LogicalKeyboardKey.f2:
        _openCustomerPicker();
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

  void _openCustomerPicker() =>
      showDialog(context: context, builder: (_) => const CustomerPicker());

  void _openDiscount() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      AppErrorHandler.showInfo(context, 'Add items first');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => DiscountDialog(base: cart.itemsTotal),
    );
  }

  void _addProduct(Product p, double qty) {
    final stockMap = ref.read(_branchStockProvider).asData?.value;
    if (stockMap != null) {
      final available = stockMap[p.id] ?? 0;
      final inCart = ref
          .read(cartProvider)
          .items
          .firstWhere(
            (i) => i.productId == p.id,
            orElse: () => CartItem(
              productId: '',
              name: '',
              pctCode: '',
              unitPrice: 0,
              taxRate: 0,
            ),
          )
          .quantity;
      // block when this add would push the line over available stock
      if (inCart + qty > available) {
        AppErrorHandler.showInfo(
          context,
          available <= 0
              ? '${p.name} is out of stock'
              : 'Only ${Fmt.qty(available)} of ${p.name} in stock',
        );
        return;
      }
    }
    ref
        .read(cartProvider.notifier)
        .addItem(
          CartItem(
            productId: p.id,
            name: p.name,
            pctCode: p.pctCode,
            unitPrice: p.salePrice,
            mrp: p.mrp,
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
    final stockMap = ref.read(_branchStockProvider).asData?.value;
    if (stockMap != null) {
      final blocked = cart.items
          .where((i) => i.quantity > (stockMap[i.productId] ?? 0))
          .toList();
      if (blocked.isNotEmpty) {
        AppErrorHandler.showInfo(
          context,
          blocked.length == 1
              ? 'Not enough stock for ${blocked.first.name}'
              : '${blocked.length} items exceed available stock — cannot checkout',
        );
        return;
      }
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
                  customerId: Value(cart.customerId),
                  cartDiscount: Value(cart.cartDiscount),
                  subtotal: Value(cart.subtotal),
                  discountAmount: Value(cart.totalDiscount + cart.cartDiscount),
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

        // Credit (udhaar): log the unpaid remainder to the customer ledger.
        if (mode == 'credit' && cart.customerId != null) {
          final owed = (cart.totalWithTax - paid)
              .clamp(0, cart.totalWithTax)
              .toDouble();
          if (owed > 0) {
            await CustomerLedger(db).recordCreditSale(
              tenantId: tenantId,
              customerId: cart.customerId!,
              amount: owed,
              invoiceId: invId,
              note: 'Invoice $invNum',
            );
          }
        }

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
            _PosHeader(bizType: bizType),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // Responsive cart width: ~32% of width, clamped 320–420.
                  final cartW = (c.maxWidth * 0.32).clamp(320.0, 420.0);
                  return Row(
                    children: [
                      Expanded(
                        child: _PosLeft(
                          tenantId: tenantId,
                          bizType: bizType,
                          searchCtrl: _searchCtrl,
                          searchFocus: _searchFocus,
                          onAdd: _addProduct,
                          onCustomer: _openCustomerPicker,
                        ),
                      ),
                      SizedBox(
                        width: cartW,
                        child: _Cart(
                          cart: cart,
                          selIdx: _selIdx,
                          onSelect: (i) => setState(() => _selIdx = i),
                          onPay: _openPayment,
                          onClear: _clearCart,
                          onDiscount: _openDiscount,
                          onCustomer: _openCustomerPicker,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
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
}

// ── Left panel ────────────────────────────────────────────
class _PosLeft extends ConsumerStatefulWidget {
  final String tenantId;
  final BusinessType bizType;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final void Function(Product, double) onAdd;
  final VoidCallback onCustomer;

  const _PosLeft({
    required this.tenantId,
    required this.bizType,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onAdd,
    required this.onCustomer,
  });

  @override
  ConsumerState<_PosLeft> createState() => _PosLeftState();
}

class _PosLeftState extends ConsumerState<_PosLeft> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(2.w),
          color: D.bgSurface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ProductSearchField(
                      controller: widget.searchCtrl,
                      focusNode: widget.searchFocus,
                      tenantId: widget.tenantId,
                      onSelected: widget.onAdd,
                    ),
                  ),
                  SizedBox(width: 1.w),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.barcode_reader, size: 12.sp),
                    label: Text('Scan', style: TextStyle(fontSize: 10.sp)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, 4.h),
                      padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                    ),
                  ),
                  SizedBox(width: 1.w),
                  OutlinedButton.icon(
                    onPressed: widget.onCustomer,
                    icon: Icon(Icons.person_add_outlined, size: 12.sp),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Customer', style: TextStyle(fontSize: 10.sp)),
                        SizedBox(width: 0.6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 0.5.w,
                            vertical: 0.1.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: D.borderDefault),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'F2',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 8.5.sp,
                              color: D.fgSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(0, 4.h),
                      padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.2.h),
              SizedBox(
                height: 3.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 1.w, top: 0.4.h),
                      child: Text(
                        'Quick:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.sp,
                          color: D.fgTertiary,
                        ),
                      ),
                    ),
                    ..._categories(widget.bizType).map(
                      (c) => Padding(
                        padding: EdgeInsets.only(right: 0.6.w),
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
        Expanded(
          child: Container(
            color: D.bgApp,
            child: _ProductGrid(tenantId: widget.tenantId, onTap: widget.onAdd),
          ),
        ),
      ],
    );
  }

  List<String> _categories(BusinessType bt) => switch (bt) {
    BusinessType.medical => ['Antibiotics', 'OTC', 'Vitamins', 'BP/Cardiac'],
    BusinessType.restaurant => ['Mains', 'Drinks', 'Starters', 'Desserts'],
    BusinessType.bookshop => ['Fiction', 'Academic', 'Children', 'Islamic'],
    _ => ['Grocery', 'Beverage', 'Dairy', 'Bakery', 'Snacks'],
  };
}

// ── Product grid ──────────────────────────────────────────
class _ProductGrid extends ConsumerWidget {
  final String tenantId;
  final void Function(Product, double) onTap;
  const _ProductGrid({required this.tenantId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(_posProductsProvider(tenantId));
    return products.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: D.gold400)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No Products',
            message: 'Add products from Inventory to start selling.',
          );
        }
        return GridView.builder(
          padding: EdgeInsets.all(2.w),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 20.w.clamp(140.0, 175.0),
            mainAxisSpacing: 1.5.h,
            crossAxisSpacing: 1.5.w,
            childAspectRatio: 1.05,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) =>
              _ProductTile(p: list[i], onTap: () => onTap(list[i], 1.0)),
        );
      },
    );
  }
}

// ── Product tile ──────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Product p;
  final VoidCallback onTap;
  const _ProductTile({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasMrp = p.mrp != null && p.mrp! > p.salePrice;
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
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9.sp,
                    color: D.fgTertiary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(1.2.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                      color: D.fgPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.3.h),
                  if (hasMrp)
                    Text(
                      'Rs. ${Fmt.pkrShort(p.mrp!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 8.5.sp,
                        color: D.fgTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    'Rs. ${Fmt.pkrShort(p.salePrice)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10.sp,
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

// ── POS header ────────────────────────────────────────────
class _PosHeader extends StatelessWidget {
  final BusinessType bizType;
  const _PosHeader({required this.bizType});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6.h,
      decoration: const BoxDecoration(
        color: D.bgSurface,
        border: Border(bottom: BorderSide(color: D.borderDefault)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2.5.w),
      child: Row(
        children: [
          Icon(Icons.point_of_sale_rounded, size: 13.sp, color: D.brand500),
          SizedBox(width: 1.w),
          Flexible(
            child: Text(
              '${bizType.saleLabel} Terminal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: D.fgPrimary,
              ),
            ),
          ),
          SizedBox(width: 1.5.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1.2.w, vertical: 0.3.h),
            decoration: BoxDecoration(
              color: D.bgCream,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: D.borderGold),
            ),
            child: Text(
              'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)} · draft',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9.sp,
                color: D.fgSecondary,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.3.h),
            decoration: BoxDecoration(
              color: D.success50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x330B6B43)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 1.5.w,
                  height: 1.5.w,
                  constraints: const BoxConstraints(
                    maxWidth: 7,
                    maxHeight: 7,
                    minWidth: 5,
                    minHeight: 5,
                  ),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: D.brand500,
                  ),
                ),
                SizedBox(width: 0.5.w),
                Text(
                  'FBR connected',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.sp,
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

// ── Cart ──────────────────────────────────────────────────
class _Cart extends ConsumerWidget {
  final CartState cart;
  final int? selIdx;
  final void Function(int) onSelect;
  final VoidCallback onPay;
  final Future<void> Function() onClear;
  final VoidCallback onDiscount;
  final VoidCallback onCustomer;

  const _Cart({
    required this.cart,
    required this.selIdx,
    required this.onSelect,
    required this.onPay,
    required this.onClear,
    required this.onDiscount,
    required this.onCustomer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockMap = ref.watch(_branchStockProvider).asData?.value;
    final outOfStockItems = stockMap == null
        ? const <CartItem>[] // still loading → don't block
        : cart.items
              .where((i) => i.quantity > (stockMap[i.productId] ?? 0))
              .toList();
    final hasOutOfStock = outOfStockItems.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: D.bgSurface,
        border: Border(left: BorderSide(color: D.borderDefault)),
      ),
      child: Column(
        children: [
          // Header — customer aware + tappable to attach/change
          InkWell(
            onTap: onCustomer,
            child: Padding(
              padding: EdgeInsets.fromLTRB(2.w, 1.6.h, 2.w, 1.6.h),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 4.w,
                    constraints: const BoxConstraints(
                      maxWidth: 34,
                      maxHeight: 34,
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cart.hasCustomer ? D.brand50 : D.neutral100,
                      border: Border.all(
                        color: cart.hasCustomer ? D.brand100 : D.borderDefault,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      cart.hasCustomer
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      size: 11.sp,
                      color: cart.hasCustomer ? D.brand600 : D.fgTertiary,
                    ),
                  ),
                  SizedBox(width: 1.5.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cart.hasCustomer ? cart.customerName! : 'Walk-in',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: D.fgPrimary,
                          ),
                        ),
                        Text(
                          cart.hasCustomer
                              ? 'Billing customer · ${cart.items.length} items'
                              : 'Tap to attach · ${cart.items.length} items',
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
                  if (!cart.isEmpty)
                    TextButton.icon(
                      onPressed: onClear,
                      icon: Icon(Icons.delete_outline_rounded, size: 11.sp),
                      label: Text('Clear', style: TextStyle(fontSize: 10.sp)),
                      style: TextButton.styleFrom(
                        foregroundColor: D.danger500,
                        minimumSize: Size(0, 3.5.h),
                        padding: EdgeInsets.symmetric(horizontal: 1.w),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: D.borderDefault),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 22.sp,
                          color: D.fgTertiary,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Cart is empty.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            color: D.fgTertiary,
                          ),
                        ),
                        SizedBox(height: 0.4.h),
                        Text(
                          'Scan or click a product to add.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.sp,
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
                      stock:
                          stockMap?[cart
                              .items[i]
                              .productId], // null = still loading
                    ),
                  ),
          ),
          if (!cart.isEmpty) ...[
            const Divider(height: 1, color: D.borderDefault),
            Padding(
              padding: EdgeInsets.all(2.w),
              child: Column(
                children: [
                  _SumRow('Subtotal', 'Rs. ${Fmt.pkrShort(cart.subtotal)}'),
                  if (cart.totalDiscount > 0)
                    _SumRow(
                      'Item discount',
                      '− Rs. ${Fmt.pkrShort(cart.totalDiscount)}',
                      color: D.danger500,
                    ),
                  _SumRow('GST', 'Rs. ${Fmt.pkrShort(cart.totalTax)}'),

                  // ── Cart-level discount row (tappable) ──
                  SizedBox(height: 0.4.h),
                  InkWell(
                    onTap: onDiscount,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 0.5.w,
                        vertical: 0.6.h,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.percent_rounded,
                                size: 11.sp,
                                color: D.gold600,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                cart.cartDiscount > 0
                                    ? 'Cart discount'
                                    : 'Add discount',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: D.gold600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            cart.cartDiscount > 0
                                ? '− Rs. ${Fmt.pkrShort(cart.cartDiscount)}'
                                : 'Tap',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11.sp,
                              color: cart.cartDiscount > 0
                                  ? D.danger500
                                  : D.fgTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 0.6.h),
                  if (hasOutOfStock) ...[
                    SizedBox(height: 0.8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 1.5.w,
                        vertical: 0.8.h,
                      ),
                      decoration: BoxDecoration(
                        color: D.danger50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0x339C2922)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 11.sp,
                            color: D.danger500,
                          ),
                          SizedBox(width: 1.w),
                          Expanded(
                            child: Text(
                              outOfStockItems.length == 1
                                  ? 'Not enough stock for ${outOfStockItems.first.name}'
                                  : '${outOfStockItems.length} items exceed available stock',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w600,
                                color: D.danger700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 0.6.h),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 1.h),
                    decoration: const BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: D.borderDefault),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: D.fgPrimary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Rs. ${Fmt.pkrShort(cart.totalWithTax)}',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: D.fgPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 1.2.h),
                  SizedBox(
                    width: double.infinity,
                    height: 5.h,
                    child: ElevatedButton(
                      onPressed: hasOutOfStock ? null : onPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: D.brand500,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: D.neutral200,
                        disabledForegroundColor: D.fgTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Checkout',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 1.5.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 1.w,
                              vertical: 0.2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'F10',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9.sp,
                                color: Colors.white,
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
      ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  final CartItem item;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final double? stock; // live on-hand; null while loading

  const _CartLine({
    required this.item,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.stock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);

    final stockMap = ref.watch(_branchStockProvider).asData?.value;
    final stockKnown = stockMap != null;
    final stock = stockMap?[item.productId] ?? 0.0; // no row → 0
    final outOfStock = stockKnown && stock <= 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: selected ? D.brand50 : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 1.2.h),
        child: Row(
          children: [
            // Name + unit price — flexes to fill leftover space
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: D.fgPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (item.hasMrpDiscount) ...[
                        Flexible(
                          child: Text(
                            'Rs. ${Fmt.pkrShort(item.mrp!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9.5.sp,
                              color: D.fgTertiary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        SizedBox(width: 1.w),
                      ],
                      Flexible(
                        child: Text(
                          'Rs. ${Fmt.pkrShort(item.unitPrice)} ea',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 8.5.sp,
                            color: D.ink800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── stock line, shown after the price ──
                  if (stockKnown) ...[
                    SizedBox(height: 0.2.h),
                    Text(
                      outOfStock
                          ? 'Out of stock'
                          : 'In stock: ${Fmt.qty(stock)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9.5.sp,
                        fontWeight: outOfStock
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: outOfStock ? D.danger500 : D.fgTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: 1.w),

            // Qty stepper — compact, fixed-small, never shrinks
            _QBtn(
              Icons.remove_rounded,
              () => cart.updateQty(index, item.quantity - 1),
            ),
            SizedBox(
              width: 24,
              child: Center(
                child: Text(
                  Fmt.qty(item.quantity),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: D.fgPrimary,
                  ),
                ),
              ),
            ),
            _QBtn(Icons.add_rounded, () {
              // Strict: never let cart qty exceed live stock.
              if (stock != null && item.quantity + 1 > stock!) {
                AppErrorHandler.showInfo(
                  context,
                  'Only ${Fmt.qty(stock!)} in stock',
                );
                return;
              }
              cart.updateQty(index, item.quantity + 1);
            }),

            SizedBox(width: 1.w),

            // Line total — flexes, right-aligned, ellipsis if huge
            Expanded(
              flex: 3,
              child: Text(
                'Rs. ${Fmt.pkrShort(item.lineTotal)}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11.sp,
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
      width: 5.w,
      height: 5.w,
      constraints: const BoxConstraints(
        maxWidth: 24,
        maxHeight: 24,
        minWidth: 20,
        minHeight: 20,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: D.borderDefault),
        borderRadius: BorderRadius.circular(4),
        color: D.bgSurface,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 10.sp, color: D.fgSecondary),
    ),
  );
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _SumRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 0.4.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.sp,
            color: D.fgSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11.sp,
            color: color ?? D.fgPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
