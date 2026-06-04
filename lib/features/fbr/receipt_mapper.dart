// lib/features/fbr/receipt_mapper.dart
//
// Maps Drift invoice + items + tenant prefs into a ReceiptData bundle.
// Keep DB-shaped code here so the widget/PDF stay pure.

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import 'receipt_data.dart';

class ReceiptMapper {
  static ReceiptData fromInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required SharedPreferences prefs,
  }) {
    return ReceiptData(
      businessName:
          prefs.getString(AppConstants.keyTenantName) ?? 'My Business',
      businessAddress: prefs.getString(AppConstants.keyTenantAddress),
      ntn: prefs.getString(AppConstants.keyTenantNtn),
      invoiceNumber: invoice.invoiceNumber,
      date: invoice.invoiceDate,
      paymentMode: invoice.paymentMode,
      subtotal: invoice.subtotal,
      discount: invoice.discountAmount,
      tax: invoice.totalSalesTax,
      total: invoice.totalWithTax,
      irn: invoice.usin, // IRN stored here by fiscalize()
      fbrStatus: invoice.fbrStatus,
      lines: items
          .map(
            (i) => ReceiptLine(
              name: i.description,
              qty: i.quantity,
              unitPrice: i.unitPrice,
              lineTotal: i.lineTotal,
            ),
          )
          .toList(),
    );
  }
}
