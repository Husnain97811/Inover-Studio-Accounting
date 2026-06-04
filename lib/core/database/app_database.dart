// lib/core/database/app_database.dart

// IMPORTANT: After adding this file, run:
//   dart run build_runner build --delete-conflicting-outputs
// This generates app_database.g.dart which is required for Drift.
// ignore_for_file: type=lint
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ════════════════════════════════════════════════════════════
//  TABLE DEFINITIONS  (Drift generates Companions from these)
// ════════════════════════════════════════════════════════════

class DeviceLicenses extends Table {
  TextColumn get id => text()();
  TextColumn get deviceFingerprint => text()();
  TextColumn get deviceName => text()();
  TextColumn get tenantId => text()();
  TextColumn get planType => text().withDefault(const Constant('trial'))();
  DateTimeColumn get activatedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get lastOnlineCheck => dateTime().nullable()();
  BoolColumn get isRevoked => boolean().withDefault(const Constant(false))();
  TextColumn get licenseToken => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Tenants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get businessType =>
      text().withDefault(const Constant('general'))();
  TextColumn get ntn => text().withDefault(const Constant(''))();
  TextColumn get strn => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  RealColumn get defaultTaxRate => real().withDefault(const Constant(17.0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Branches extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get fbrPosId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text().nullable()();
  TextColumn get fullName => text()();
  TextColumn get email => text()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  TextColumn get pin => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class ProductCategories extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameUrdu => text().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#3B82F6'))();
  TextColumn get icon => text().withDefault(const Constant('📦'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameUrdu => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get pctCode => text().withDefault(const Constant('9999.99'))();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().nullable()();
  BoolColumn get isTaxExempt => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  RealColumn get mrp => real().nullable()();
  Set<Column> get primaryKey => {id};
}

class Inventory extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get productId => text()();
  RealColumn get qtyOnHand => real().withDefault(const Constant(0.0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();
  RealColumn get reorderQty => real().withDefault(const Constant(0.0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get cnic => text().nullable()();
  TextColumn get ntn => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get customerId => text().nullable()();
  RealColumn get cartDiscount => real().withDefault(const Constant(0))();
  TextColumn get invoiceNumber => text()();
  TextColumn get invoiceType => text().withDefault(const Constant('Sale'))();
  DateTimeColumn get invoiceDate => dateTime()();
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  TextColumn get cashierId => text()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxableAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalSalesTax => real().withDefault(const Constant(0.0))();
  RealColumn get totalWithTax => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  RealColumn get changeGiven => real().withDefault(const Constant(0.0))();
  TextColumn get fbrStatus => text().withDefault(const Constant('pending'))();
  TextColumn get usin => text().nullable()();
  TextColumn get qrCodeString => text().nullable()();
  TextColumn get fbrRawResponse => text().nullable()();
  IntColumn get fbrRetryCount => integer().withDefault(const Constant(0))();
  TextColumn get fbrErrorMessage => text().nullable()();
  DateTimeColumn get fbrSubmittedAt => dateTime().nullable()();
  DateTimeColumn get fbrVerifiedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get description => text()();
  TextColumn get pctCode => text().withDefault(const Constant('9999.99'))();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get discountRate => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().withDefault(const Constant(17.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0.0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Vendors extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get ntn => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseOrders extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get vendorId => text()();
  TextColumn get poNumber => text()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get orderDate => dateTime()();
  DateTimeColumn get expectedDate => dateTime().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get poId => text()();
  TextColumn get productId => text()();
  RealColumn get qtyOrdered => real()();
  RealColumn get qtyReceived => real().withDefault(const Constant(0.0))();
  RealColumn get unitCost => real()();
  RealColumn get taxRate => real().withDefault(const Constant(17.0))();
  RealColumn get lineTotal => real()();
  @override
  Set<Column> get primaryKey => {id};
}

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get nameUrdu => text().nullable()();
  TextColumn get type => text()();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get description => text()();
  DateTimeColumn get entryDate => dateTime()();
  BoolColumn get isPosted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class JournalLines extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text()();
  TextColumn get accountId => text()();
  RealColumn get debit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  TextColumn get narration => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class OutboxQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class SyncWatermarks extends Table {
  TextColumn get entityType => text()();
  IntColumn get lastSyncAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {entityType};
}

// CustomerTransactions (the khata ledger)
class CustomerTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get customerId => text()();
  // 'sale' (+balance), 'payment' (-balance), 'adjustment' (+/-)
  TextColumn get type => text()();
  RealColumn get amount => real()(); // always positive; sign by type
  RealColumn get balanceAfter => real()(); // running balance snapshot
  TextColumn get invoiceId => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ════════════════════════════════════════════════════════════
//  DATABASE  — extends _$AppDatabase (generated by build_runner)
// ════════════════════════════════════════════════════════════
@DriftDatabase(
  tables: [
    DeviceLicenses,
    Tenants,
    Branches,
    UserProfiles,
    ProductCategories,
    Products,
    Inventory,
    Customers,
    Invoices,
    InvoiceItems,
    Vendors,
    PurchaseOrders,
    PurchaseOrderItems,
    Accounts,
    JournalEntries,
    JournalLines,
    OutboxQueue,
    SyncWatermarks,
    CustomerTransactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override
  int get schemaVersion => 2; // was 1

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(customerTransactions);
        await m.addColumn(products, products.mrp);
        await m.addColumn(invoices, invoices.customerId);
        await m.addColumn(invoices, invoices.cartDiscount);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
    },
  );

  // Seed Pakistan default chart of accounts
  Future<void> seedDefaultAccounts(String tenantId) async {
    final rows = [
      ('1000', 'Cash in Hand', 'نقد', 'asset'),
      ('1010', 'Bank Account', 'بینک', 'asset'),
      ('1100', 'Accounts Receivable', 'وصولنی', 'asset'),
      ('1200', 'Inventory', 'مال', 'asset'),
      ('2000', 'Accounts Payable', 'ادائیگی', 'liability'),
      ('2100', 'Sales Tax Payable', 'جی ایس ٹی', 'liability'),
      ('3000', 'Owner Equity', 'سرمایہ', 'equity'),
      ('4000', 'Sales Revenue', 'فروخت', 'revenue'),
      ('5000', 'Cost of Goods Sold', 'قیمت', 'expense'),
      ('6000', 'Rent Expense', 'کرایہ', 'expense'),
      ('6100', 'Salary Expense', 'تنخواہ', 'expense'),
    ];
    for (final (code, name, urdu, type) in rows) {
      await into(accounts).insertOnConflictUpdate(
        AccountsCompanion.insert(
          id: '${tenantId}_$code',
          tenantId: tenantId,
          code: code,
          name: name,
          nameUrdu: Value(urdu),
          type: type,
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'is_accounting.db'));
    return driftDatabase(
      name: file.path,

      // path: file.path
    );
  });
}
