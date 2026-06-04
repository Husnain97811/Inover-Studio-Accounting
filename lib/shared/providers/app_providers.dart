// lib/shared/providers/app_providers.dart
import 'package:drift/drift.dart'
    show Value, ComparableExpr, OrderingTerm, BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/licensing/license_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/fbr/fbr_service.dart';

// ─────────────────────────────────────────────────
//  CORE SINGLETONS
// ─────────────────────────────────────────────────
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// Override in main()
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override prefsProvider in main()'),
);

// ─────────────────────────────────────────────────
//  SYNC
// ─────────────────────────────────────────────────
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    ref.watch(databaseProvider),
    ref.watch(supabaseProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStateProvider = StreamProvider<SyncState>(
  (ref) => ref.watch(syncEngineProvider).stream,
);

// ─────────────────────────────────────────────────
//  LICENSE
// ─────────────────────────────────────────────────
final licenseServiceProvider = Provider<LicenseService>(
  (ref) =>
      LicenseService(ref.watch(databaseProvider), ref.watch(prefsProvider)),
);

final licenseProvider = FutureProvider<LicenseResult>((ref) async {
  final prefs = ref.watch(prefsProvider);
  final tenantId = prefs.getString(AppConstants.keyTenantId) ?? '';
  return ref.read(licenseServiceProvider).checkLicense(tenantId);
});

// ─────────────────────────────────────────────────
//  FBR
// ─────────────────────────────────────────────────
final fbrServiceProvider = Provider<FbrService>((ref) {
  final svc = FbrService(ref.watch(databaseProvider), ref.watch(prefsProvider));
  ref.onDispose(svc.stop);
  return svc;
});

// ─────────────────────────────────────────────────
//  AUTH / SESSION
// ─────────────────────────────────────────────────
final currentUserProvider = Provider<User?>(
  (ref) => Supabase.instance.client.auth.currentUser,
);

final currentTenantIdProvider = Provider<String>(
  (ref) => ref.watch(prefsProvider).getString(AppConstants.keyTenantId) ?? '',
);

final currentBranchIdProvider = Provider<String>(
  (ref) => ref.watch(prefsProvider).getString(AppConstants.keyBranchId) ?? '',
);

final currentRoleProvider = Provider<UserRole>((ref) {
  final s =
      ref.watch(prefsProvider).getString(AppConstants.keyUserRole) ?? 'cashier';
  return UserRole.values.firstWhere(
    (r) => r.name == s,
    orElse: () => UserRole.cashier,
  );
});

// ─────────────────────────────────────────────────
//  LOCALE
// ─────────────────────────────────────────────────
class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final s = ref.read(prefsProvider).getString(AppConstants.keyLocale) ?? 'en';
    return AppLocale.values.firstWhere(
      (l) => l.code == s,
      orElse: () => AppLocale.english,
    );
  }

  void toggle() {
    final next = state == AppLocale.english
        ? AppLocale.urdu
        : AppLocale.english;
    state = next;
    ref.read(prefsProvider).setString(AppConstants.keyLocale, next.code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);

// ─────────────────────────────────────────────────
//  BUSINESS TYPE  (theme adapter)
// ─────────────────────────────────────────────────
class BusinessTypeNotifier extends Notifier<BusinessType> {
  @override
  BusinessType build() {
    final s =
        ref.read(prefsProvider).getString(AppConstants.keyBusinessType) ??
        'general';
    return BusinessType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => BusinessType.general,
    );
  }

  void set(BusinessType t) {
    state = t;
    ref.read(prefsProvider).setString(AppConstants.keyBusinessType, t.name);
  }
}

final businessTypeProvider =
    NotifierProvider<BusinessTypeNotifier, BusinessType>(
      BusinessTypeNotifier.new,
    );

// ─────────────────────────────────────────────────
//  POS CART
// ─────────────────────────────────────────────────
class CartItem {
  final String productId;
  final String name;
  final String pctCode;
  final double unitPrice; // the actual selling price (salePrice)
  final double taxRate;
  final double? mrp; // list price; strike when mrp != null && mrp > unitPrice
  double quantity;
  double discountRate;

  CartItem({
    required this.productId,
    required this.name,
    required this.pctCode,
    required this.unitPrice,
    required this.taxRate,
    this.mrp,
    this.quantity = 1.0,
    this.discountRate = 0.0,
  });

  bool get hasMrpDiscount => mrp != null && mrp! > unitPrice;

  double get discountAmount => unitPrice * quantity * discountRate / 100;
  double get taxableAmount => unitPrice * quantity - discountAmount;
  double get taxAmount => taxRate == 0 ? 0 : taxableAmount * taxRate / 100;
  double get lineTotal => taxableAmount + taxAmount;

  CartItem copyWith({double? quantity, double? discountRate}) => CartItem(
    productId: productId,
    name: name,
    pctCode: pctCode,
    unitPrice: unitPrice,
    taxRate: taxRate,
    mrp: mrp,
    quantity: quantity ?? this.quantity,
    discountRate: discountRate ?? this.discountRate,
  );
}

// ── CartState — add cartDiscount + customerNtn ────────────
class CartState {
  final List<CartItem> items;
  final String? customerId;
  final String? customerName; // for cart header display
  final String? customerNtn; // flows into FBR buyer fields
  final double
  cartDiscount; // whole-sale discount in RUPEES (resolved from % or Rs.)
  final String paymentMode;
  final double amountPaid;
  final String? notes;

  const CartState({
    this.items = const [],
    this.customerId,
    this.customerName,
    this.customerNtn,
    this.cartDiscount = 0.0,
    this.paymentMode = 'cash',
    this.amountPaid = 0.0,
    this.notes,
  });

  // Sum of line totals BEFORE the cart-level discount.
  double get itemsTotal => items.fold(0.0, (s, i) => s + i.lineTotal);

  double get subtotal =>
      items.fold(0.0, (s, i) => s + i.unitPrice * i.quantity);
  double get totalDiscount => items.fold(0.0, (s, i) => s + i.discountAmount);
  double get totalTax => items.fold(0.0, (s, i) => s + i.taxAmount);

  // Final payable = items total minus the whole-cart discount (never below 0).
  double get totalWithTax {
    final t = itemsTotal - cartDiscount;
    return t < 0 ? 0 : t;
  }

  double get change => amountPaid - totalWithTax;
  bool get isEmpty => items.isEmpty;
  bool get hasCustomer => customerId != null;

  CartState copyWith({
    List<CartItem>? items,
    String? customerId,
    String? customerName,
    String? customerNtn,
    double? cartDiscount,
    String? paymentMode,
    double? amountPaid,
    String? notes,
    bool clearCustomer = false,
  }) => CartState(
    items: items ?? this.items,
    customerId: clearCustomer ? null : (customerId ?? this.customerId),
    customerName: clearCustomer ? null : (customerName ?? this.customerName),
    customerNtn: clearCustomer ? null : (customerNtn ?? this.customerNtn),
    cartDiscount: cartDiscount ?? this.cartDiscount,
    paymentMode: paymentMode ?? this.paymentMode,
    amountPaid: amountPaid ?? this.amountPaid,
    notes: notes ?? this.notes,
  );
}

// ── CartNotifier — add discount + customer methods ────────
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addItem(CartItem item) {
    final idx = state.items.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      final list = List<CartItem>.from(state.items);
      list[idx] = list[idx].copyWith(
        quantity: list[idx].quantity + item.quantity,
      );
      state = state.copyWith(items: list);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void removeItem(int i) {
    final list = List<CartItem>.from(state.items)..removeAt(i);
    state = state.copyWith(items: list);
  }

  void updateQty(int i, double qty) {
    if (qty <= 0) {
      removeItem(i);
      return;
    }
    final list = List<CartItem>.from(state.items);
    list[i] = list[i].copyWith(quantity: qty);
    state = state.copyWith(items: list);
  }

  void setPaymentMode(String m) => state = state.copyWith(paymentMode: m);
  void setAmountPaid(double a) => state = state.copyWith(amountPaid: a);

  // Customer attach / detach
  void setCustomer({String? id, String? name, String? ntn}) => state = state
      .copyWith(customerId: id, customerName: name, customerNtn: ntn);
  void clearCustomer() => state = state.copyWith(clearCustomer: true);

  // Whole-cart discount (already resolved to rupees by the dialog)
  void setCartDiscount(double rupees) =>
      state = state.copyWith(cartDiscount: rupees < 0 ? 0 : rupees);

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

// ─────────────────────────────────────────────────
//  DASHBOARD STATS
// ─────────────────────────────────────────────────
class DashStats {
  final double todaySales;
  final int todayCount;
  final double monthSales;
  final int fbrPending;
  final int lowStock;
  final List<Map<String, dynamic>> recentInvoices;

  const DashStats({
    this.todaySales = 0,
    this.todayCount = 0,
    this.monthSales = 0,
    this.fbrPending = 0,
    this.lowStock = 0,
    this.recentInvoices = const [],
  });
}

final dashStatsProvider = FutureProvider<DashStats>((ref) async {
  final db = ref.watch(databaseProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);

  final todayInvs =
      await (db.select(db.invoices)..where(
            (t) =>
                t.branchId.equals(branchId) &
                t.invoiceDate.isBiggerOrEqualValue(todayStart) &
                t.isDeleted.equals(false),
          ))
          .get();

  final monthInvs =
      await (db.select(db.invoices)..where(
            (t) =>
                t.branchId.equals(branchId) &
                t.invoiceDate.isBiggerOrEqualValue(monthStart) &
                t.isDeleted.equals(false),
          ))
          .get();

  final fbrPending =
      await (db.select(db.invoices)..where(
            (t) =>
                t.tenantId.equals(tenantId) &
                t.fbrStatus.isIn(['pending', 'failed']),
          ))
          .get();

  final lowStockItems =
      await (db.select(db.inventory)..where(
            (t) =>
                t.branchId.equals(branchId) &
                t.qtyOnHand.isSmallerOrEqualValue(0),
          ))
          .get();

  final recent =
      await (db.select(db.invoices)
            ..where(
              (t) => t.branchId.equals(branchId) & t.isDeleted.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)])
            ..limit(6))
          .get();

  return DashStats(
    todaySales: todayInvs.fold(0.0, (s, i) => s + i.totalWithTax),
    todayCount: todayInvs.length,
    monthSales: monthInvs.fold(0.0, (s, i) => s + i.totalWithTax),
    fbrPending: fbrPending.length,
    lowStock: lowStockItems.length,
    recentInvoices: recent
        .map(
          (i) => {
            'id': i.id,
            'number': i.invoiceNumber,
            'amount': i.totalWithTax,
            'date': i.invoiceDate,
            'fbrStatus': i.fbrStatus,
            'payMode': i.paymentMode,
          },
        )
        .toList(),
  );
});
