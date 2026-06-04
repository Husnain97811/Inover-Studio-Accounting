// lib/core/fbr/fbr_models.dart
//
// C2 (part 1) — typed request/response models matching the PRAL DI API spec.
//
// Field names mirror the FBR JSON EXACTLY (camelCase as the API expects).
// Do not rename these to match your Dart style — the wire format is fixed.

// ─────────────────────────────────────────────────────────
//  REQUEST
// ─────────────────────────────────────────────────────────
class FbrInvoiceItem {
  final String hsCode; // e.g. "0101.2100"
  final String productDescription;
  final String rate; // "18%" (or "18" per flags)
  final String uoM; // unit of measure
  final double quantity;
  final double valueSalesExcludingST; // taxable value
  final double salesTaxApplicable; // tax amount
  final double totalValues; // gross (0 lets FBR compute in some scenarios)
  final double fixedNotifiedValueOrRetailPrice;
  final double salesTaxWithheldAtSource;
  final String saleType; // e.g. "Goods at standard rate (default)"
  final String? productCode;
  final String? sroScheduleNo;
  final String? sroItemSerialNo;
  final double? furtherTax;
  final double? fedPayable;
  final String? extraTax;

  const FbrInvoiceItem({
    required this.hsCode,
    required this.productDescription,
    required this.rate,
    required this.uoM,
    required this.quantity,
    required this.valueSalesExcludingST,
    required this.salesTaxApplicable,
    this.totalValues = 0,
    this.fixedNotifiedValueOrRetailPrice = 0,
    this.salesTaxWithheldAtSource = 0,
    this.saleType = 'Goods at standard rate (default)',
    this.productCode,
    this.sroScheduleNo,
    this.sroItemSerialNo,
    this.furtherTax,
    this.fedPayable,
    this.extraTax,
  });
}

class FbrInvoiceRequest {
  // Header (added once)
  final String invoiceType; // "Sale Invoice"
  final String invoiceDate; // "YYYY-MM-DD"
  final String sellerNTNCNIC;
  final String sellerBusinessName;
  final String sellerProvince;
  final String sellerAddress;
  final String buyerNTNCNIC;
  final String buyerBusinessName;
  final String buyerProvince;
  final String buyerAddress;
  final String buyerRegistrationType; // "Registered" | "Unregistered"
  final String invoiceRefNo; // "" for new sale; ref for debit/credit notes
  final String? businessDestinationAddress;
  final String? scenarioId; // SANDBOX ONLY — null in production

  final List<FbrInvoiceItem> items;

  const FbrInvoiceRequest({
    required this.invoiceType,
    required this.invoiceDate,
    required this.sellerNTNCNIC,
    required this.sellerBusinessName,
    required this.sellerProvince,
    required this.sellerAddress,
    required this.buyerNTNCNIC,
    required this.buyerBusinessName,
    required this.buyerProvince,
    required this.buyerAddress,
    required this.buyerRegistrationType,
    required this.items,
    this.invoiceRefNo = '',
    this.businessDestinationAddress,
    this.scenarioId,
  });
}

// ─────────────────────────────────────────────────────────
//  RESPONSE
// ─────────────────────────────────────────────────────────
// FBR returns a validationResponse block plus, on success, the invoice number.
class FbrInvoiceResponse {
  final bool valid;
  final String? invoiceNumber; // the IRN — what makes the invoice legal
  final String? statusCode; // "00" = success in FBR convention
  final String? status; // "Valid" / "Invalid"
  final String? error; // top-level error text if any
  final List<FbrItemError> itemErrors;
  final Map<String, dynamic>
  raw; // full response kept for the 6-year audit trail

  const FbrInvoiceResponse({
    required this.valid,
    this.invoiceNumber,
    this.statusCode,
    this.status,
    this.error,
    this.itemErrors = const [],
    this.raw = const {},
  });

  factory FbrInvoiceResponse.fromJson(Map<String, dynamic> json) {
    // The DI API nests result under "validationResponse"; tolerate both shapes.
    final vr = (json['validationResponse'] as Map<String, dynamic>?) ?? json;

    final statusCode = vr['statusCode']?.toString();
    final status = vr['status']?.toString();
    final invoiceNumber = (json['invoiceNumber'] ?? vr['invoiceNumber'])
        ?.toString();

    final isValid =
        (statusCode == '00') ||
        (status?.toLowerCase() == 'valid') ||
        (invoiceNumber != null && invoiceNumber.isNotEmpty);

    final itemErrs = <FbrItemError>[];
    final invoiceStatuses = vr['invoiceStatuses'];
    if (invoiceStatuses is List) {
      for (final e in invoiceStatuses) {
        if (e is Map<String, dynamic> &&
            (e['statusCode']?.toString() ?? '') != '00') {
          itemErrs.add(
            FbrItemError(
              itemSNo: e['itemSNo']?.toString() ?? '',
              statusCode: e['statusCode']?.toString() ?? '',
              error: e['error']?.toString() ?? '',
            ),
          );
        }
      }
    }

    return FbrInvoiceResponse(
      valid: isValid,
      invoiceNumber: (invoiceNumber?.isEmpty ?? true) ? null : invoiceNumber,
      statusCode: statusCode,
      status: status,
      error: (vr['error'] ?? json['error'])?.toString(),
      itemErrors: itemErrs,
      raw: json,
    );
  }

  String get displayError {
    if (error != null && error!.isNotEmpty) return error!;
    if (itemErrors.isNotEmpty) {
      return itemErrors.map((e) => 'Item ${e.itemSNo}: ${e.error}').join('; ');
    }
    return 'Unknown FBR error (status: $statusCode)';
  }
}

class FbrItemError {
  final String itemSNo;
  final String statusCode;
  final String error;
  const FbrItemError({
    required this.itemSNo,
    required this.statusCode,
    required this.error,
  });
}
