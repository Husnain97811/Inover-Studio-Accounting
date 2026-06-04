// lib/core/fbr/fbr_dummy_data.dart
//
// Dummy-data factory for testing C1–C3 BEFORE your sandbox token arrives.
// Values mirror the published SN001 sandbox example (standard-rate goods,
// registered buyer, 18% GST). Swap real seller/buyer details in later.

import 'fbr_models.dart';

class FbrDummyData {
  /// SN001 — standard-rate sale to a registered buyer.
  static FbrInvoiceRequest sn001() => FbrInvoiceRequest(
    invoiceType: 'Sale Invoice',
    invoiceDate: _today(),
    sellerNTNCNIC: '7654321',
    sellerBusinessName: 'IS Accounting Test Seller',
    sellerProvince: 'Punjab',
    sellerAddress: 'Gujar Khan, Punjab',
    buyerNTNCNIC: '2046004',
    buyerBusinessName: 'ABC Trading Company',
    buyerProvince: 'Sindh',
    buyerAddress: 'Karachi',
    buyerRegistrationType: 'Registered',
    invoiceRefNo: '',
    scenarioId: 'SN001',
    items: const [
      FbrInvoiceItem(
        hsCode: '0101.2100',
        productDescription: 'Test Product (standard rate)',
        rate: '18%',
        uoM: 'Numbers, pieces, units',
        quantity: 1,
        valueSalesExcludingST: 1000,
        salesTaxApplicable: 180,
        totalValues: 1180,
        saleType: 'Goods at standard rate (default)',
      ),
    ],
  );

  /// SN002 — sale to an UNregistered buyer (different reg type).
  static FbrInvoiceRequest sn002() => FbrInvoiceRequest(
    invoiceType: 'Sale Invoice',
    invoiceDate: _today(),
    sellerNTNCNIC: '7654321',
    sellerBusinessName: 'IS Accounting Test Seller',
    sellerProvince: 'Punjab',
    sellerAddress: 'Gujar Khan, Punjab',
    buyerNTNCNIC: '1000000000000',
    buyerBusinessName: 'Walk-in Customer',
    buyerProvince: 'Punjab',
    buyerAddress: 'Rawalpindi',
    buyerRegistrationType: 'Unregistered',
    invoiceRefNo: '',
    scenarioId: 'SN002',
    items: const [
      FbrInvoiceItem(
        hsCode: '0101.2100',
        productDescription: 'Test Product (unreg buyer)',
        rate: '18%',
        uoM: 'Numbers, pieces, units',
        quantity: 2,
        valueSalesExcludingST: 500,
        salesTaxApplicable: 90,
        totalValues: 590,
      ),
    ],
  );

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}
