// lib/core/constants/app_constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();
  static const appName = 'IS Accounting';
  static const appVersion = '1.0.0';
  // ─── CHANGE THESE in lib/core/constants/app_constants.dart ───
  // Get from: https://app.supabase.com → Your Project → Settings → API
  static const supabaseUrl = 'https://arednahdmuguxvwyvhua.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFyZWRuYWhkbXVndXh2d3l2aHVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNjM0NTcsImV4cCI6MjA5NDgzOTQ1N30.K0cyNueCqI58I8I1_MriXLIpOOGXuzYPKS8Q9Xg5JeY';
  // ────────────────────────────────────────────────────────────
  static const licenseCheckIntervalHours = 24;
  static const licenseGracePeriodDays = 3;
  static const fbrApiUrl = 'https://gw.fbr.gov.pk/imsp/v1/api/Live/PostData';
  static const fbrMaxRetries = 5;
  static const syncIntervalSeconds = 30;
  static const outboxBatchSize = 50;
  // SharedPrefs keys
  static const keyTenantId = 'tenant_id';
  static const keyBranchId = 'branch_id';
  static const keyUserRole = 'user_role';
  static const keyBusinessType = 'business_type';
  static const keyLocale = 'locale';
}

class SemColor {
  SemColor._();
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const successBg = Color(0x2022C55E);
  static const warningBg = Color(0x20F59E0B);
  static const errorBg = Color(0x20EF4444);
  static const infoBg = Color(0x203B82F6);
}

enum BusinessType {
  retail,
  medical,
  restaurant,
  electronics,
  bookshop,
  clothing,
  distribution,
  services,
  general,
}

extension BusinessTypeX on BusinessType {
  String get label => const {
    'retail': 'Retail / General Store',
    'medical': 'Medical / Pharmacy',
    'restaurant': 'Restaurant / Food',
    'electronics': 'Electronics / Mobile',
    'bookshop': 'Books / Stationery',
    'clothing': 'Clothing / Garments',
    'distribution': 'Distribution / Wholesale',
    'services': 'Services',
    'general': 'General Business',
  }[name]!;
  String get emoji => const {
    'retail': '🏪',
    'medical': '🏥',
    'restaurant': '🍽️',
    'electronics': '📱',
    'bookshop': '📚',
    'clothing': '👗',
    'distribution': '🚚',
    'services': '🔧',
    'general': '🏢',
  }[name]!;
  String get productLabel => this == BusinessType.medical
      ? 'Medicines'
      : this == BusinessType.restaurant
      ? 'Menu Items'
      : this == BusinessType.bookshop
      ? 'Books'
      : 'Products';
  String get customerLabel => this == BusinessType.medical
      ? 'Patients'
      : this == BusinessType.restaurant
      ? 'Guests'
      : this == BusinessType.services
      ? 'Clients'
      : 'Customers';
  String get saleLabel => this == BusinessType.medical
      ? 'Prescription'
      : this == BusinessType.restaurant
      ? 'Order'
      : this == BusinessType.services
      ? 'Job Card'
      : 'Invoice';
  IconData get moduleIcon => this == BusinessType.medical
      ? Icons.local_hospital_rounded
      : this == BusinessType.restaurant
      ? Icons.restaurant_rounded
      : this == BusinessType.bookshop
      ? Icons.menu_book_rounded
      : this == BusinessType.electronics
      ? Icons.devices_rounded
      : this == BusinessType.clothing
      ? Icons.checkroom_rounded
      : this == BusinessType.distribution
      ? Icons.local_shipping_rounded
      : Icons.store_rounded;
}

enum UserRole { owner, manager, cashier, accountant, viewer }

extension UserRoleX on UserRole {
  String get label => name[0].toUpperCase() + name.substring(1);
  bool get canDeleteInvoice =>
      this == UserRole.owner || this == UserRole.manager;
  bool get canManageProducts =>
      this != UserRole.cashier && this != UserRole.viewer;
  bool get canViewReports =>
      this != UserRole.cashier && this != UserRole.viewer;
  bool get canManageUsers => this == UserRole.owner;
  bool get canViewAccounts =>
      this == UserRole.owner || this == UserRole.accountant;
}

enum FbrStatus { pending, submitted, verified, failed, exempt }

extension FbrStatusX on FbrStatus {
  String get label => const {
    'pending': 'Pending',
    'submitted': 'Submitted',
    'verified': 'Verified ✓',
    'failed': 'Failed',
    'exempt': 'Exempt',
  }[name]!;
}

enum PaymentMode { cash, card, online, credit, cheque }

extension PaymentModeX on PaymentMode {
  String get label => const {
    'cash': 'Cash',
    'card': 'Card',
    'online': 'Online',
    'credit': 'Credit (Udhaar)',
    'cheque': 'Cheque',
  }[name]!;
  String get fbrCode => const {
    'cash': '1',
    'card': '2',
    'cheque': '4',
    'online': '5',
    'credit': '1',
  }[name]!;
}

enum PlanType { trial, starter, growth, enterprise }

extension PlanTypeX on PlanType {
  int get maxDevices =>
      const {'trial': 1, 'starter': 2, 'growth': 5, 'enterprise': 20}[name]!;
}

enum LicenseStatus {
  valid,
  expired,
  gracePeriod,
  deviceBlocked,
  maxDevices,
  notActivated,
  revoked,
}

enum AppLocale {
  english('en', 'English', false),
  urdu('ur', 'اردو', true);

  final String code;
  final String nativeName;
  final bool isRtl;
  const AppLocale(this.code, this.nativeName, this.isRtl);
}
