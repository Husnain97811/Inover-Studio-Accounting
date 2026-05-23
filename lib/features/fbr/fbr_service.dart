// lib/features/fbr/fbr_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart'
    show Value, ComparableExpr, BooleanExpressionOperators;
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';

class FbrService {
  final AppDatabase _db;
  Timer? _retryTimer;
  String _fbrToken = '';

  FbrService(this._db);

  void setToken(String token) => _fbrToken = token;

  void startRetryJob() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _retryPending(),
    );
  }

  void stop() => _retryTimer?.cancel();

  Future<void> fiscalize(String invoiceId) async {
    if (_fbrToken.isEmpty) return;
    final invoice = await (_db.select(
      _db.invoices,
    )..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    if (invoice == null) return;

    final items = await (_db.select(
      _db.invoiceItems,
    )..where((t) => t.invoiceId.equals(invoiceId))).get();

    await (_db.update(
      _db.invoices,
    )..where((t) => t.id.equals(invoiceId))).write(
      InvoicesCompanion(
        fbrStatus: const Value('submitted'),
        fbrSubmittedAt: Value(DateTime.now()),
      ),
    );

    try {
      final payload = {
        'InvoiceNumber': invoice.invoiceNumber,
        'POSID': 'YOUR_POS_ID',
        'USIN': '',
        'DateTime': invoice.invoiceDate.toIso8601String(),
        'BuyerNTN': '',
        'BuyerCNIC': '',
        'BuyerName': 'Walk-in Customer',
        'BuyerPhoneNumber': '',
        'TotalSaleValue': invoice.subtotal,
        'TotalQuantity': items.fold(0.0, (s, i) => s + i.quantity),
        'TotalBillAmount': invoice.totalWithTax,
        'TotalTaxCharged': invoice.totalSalesTax,
        'Discount': invoice.discountAmount,
        'PaymentMode': _pmCode(invoice.paymentMode),
        'InvoiceType': 'Sale',
        'Items': items
            .map(
              (i) => {
                'ItemCode': i.pctCode,
                'ItemName': i.description,
                'Quantity': i.quantity,
                'PCTCode': i.pctCode,
                'TaxRate': i.taxRate,
                'SaleValue': i.unitPrice * i.quantity - i.discountAmount,
                'TaxCharged': i.taxAmount,
                'TotalAmount': i.lineTotal,
                'Discount': i.discountAmount,
              },
            )
            .toList(),
      };

      final res = await http
          .post(
            Uri.parse(AppConstants.fbrApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_fbrToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['Code'] == '100') {
        await (_db.update(
          _db.invoices,
        )..where((t) => t.id.equals(invoiceId))).write(
          InvoicesCompanion(
            fbrStatus: const Value('verified'),
            usin: Value(data['InvoiceRefNo'] as String?),
            qrCodeString: Value(data['QRCode'] as String?),
            fbrRawResponse: Value(jsonEncode(data)),
            fbrVerifiedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await _fail(
          invoiceId,
          invoice.fbrRetryCount,
          'FBR: ${data['Errors'] ?? data['Message']}',
        );
      }
    } on SocketException {
      await _fail(invoiceId, invoice.fbrRetryCount, 'No internet');
    } on TimeoutException {
      await _fail(invoiceId, invoice.fbrRetryCount, 'Timeout');
    } catch (e) {
      await _fail(invoiceId, invoice.fbrRetryCount, e.toString());
    }
  }

  Future<void> _fail(String id, int retries, String err) async {
    await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
      InvoicesCompanion(
        fbrStatus: const Value('failed'),
        fbrRetryCount: Value(retries + 1),
        fbrErrorMessage: Value(err),
      ),
    );
  }

  Future<void> _retryPending() async {
    final pending =
        await (_db.select(_db.invoices)..where(
              (t) =>
                  t.fbrStatus.isIn(['pending', 'failed']) &
                  t.fbrRetryCount.isSmallerThanValue(
                    AppConstants.fbrMaxRetries,
                  ),
            ))
            .get();
    for (final inv in pending) {
      await Future.delayed(const Duration(seconds: 2));
      await fiscalize(inv.id);
    }
  }

  String _pmCode(String m) => switch (m) {
    'card' => '2',
    'cheque' => '4',
    'online' => '5',
    _ => '1',
  };
}
