// lib/core/fbr/fbr_payload_builder.dart
//
// C2 (part 2) — the JSON payload builder.
//
// Converts a typed FbrInvoiceRequest into the exact Map<String,dynamic> the
// PRAL DI API expects. Field PRESENCE is driven by FbrFieldFlags so a draft-spec
// change is a config edit. scenarioId is automatically stripped in production.

import 'fbr_config.dart';
import 'fbr_models.dart';

class FbrPayloadBuilder {
  final FbrFieldFlags flags;
  const FbrPayloadBuilder({this.flags = FbrFieldFlags.standard});

  Map<String, dynamic> build(FbrInvoiceRequest req, {required bool isSandbox}) {
    final header = <String, dynamic>{
      'invoiceType': req.invoiceType,
      'invoiceDate': req.invoiceDate,
      'sellerNTNCNIC': req.sellerNTNCNIC,
      'sellerBusinessName': req.sellerBusinessName,
      'sellerProvince': req.sellerProvince,
      'sellerAddress': req.sellerAddress,
      'buyerNTNCNIC': req.buyerNTNCNIC,
      'buyerBusinessName': req.buyerBusinessName,
      'buyerProvince': req.buyerProvince,
      'buyerAddress': req.buyerAddress,
      'buyerRegistrationType': req.buyerRegistrationType,
      'invoiceRefNo': req.invoiceRefNo,
    };

    if (flags.includeBusinessDestinationAddress) {
      header['businessDestinationAddress'] =
          req.businessDestinationAddress ?? '';
    }

    // scenarioId is SANDBOX ONLY. In production it must be absent, or FBR
    // rejects the invoice. This single guard prevents the most common go-live bug.
    if (isSandbox && req.scenarioId != null && req.scenarioId!.isNotEmpty) {
      header['scenarioId'] = req.scenarioId;
    }

    header['items'] = req.items.map(_buildItem).toList();
    return header;
  }

  Map<String, dynamic> _buildItem(FbrInvoiceItem it) {
    final m = <String, dynamic>{
      'hsCode': it.hsCode,
      'productDescription': it.productDescription,
      'rate': flags.sendRateAsPercentString
          ? it.rate
          : it.rate.replaceAll('%', '').trim(),
      'uoM': it.uoM,
      'quantity': it.quantity,
      'totalValues': it.totalValues,
      'valueSalesExcludingST': it.valueSalesExcludingST,
      'fixedNotifiedValueOrRetailPrice': it.fixedNotifiedValueOrRetailPrice,
      'salesTaxApplicable': it.salesTaxApplicable,
      'salesTaxWithheldAtSource': it.salesTaxWithheldAtSource,
      'saleType': it.saleType,
    };

    if (flags.includeProductCode) m['productCode'] = it.productCode ?? '';
    if (flags.includeSroFields) {
      m['sroScheduleNo'] = it.sroScheduleNo ?? '';
      m['sroItemSerialNo'] = it.sroItemSerialNo ?? '';
    }
    if (flags.includeFurtherTax) m['furtherTax'] = it.furtherTax ?? 0;
    if (flags.includeFedPayable) m['fedPayable'] = it.fedPayable ?? 0;
    m['extraTax'] = it.extraTax ?? '';

    return m;
  }
}
