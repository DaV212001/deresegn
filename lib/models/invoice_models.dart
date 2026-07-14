class InvoiceRegisterRequest {
  final Map<String, dynamic> documentDetails;
  final String transactionType;
  final Map<String, dynamic> sourceSystem;
  final Map<String, dynamic> sellerDetails;
  final Map<String, dynamic> buyerDetails;
  final List<Map<String, dynamic>> itemList;
  final Map<String, dynamic> valueDetails;
  final Map<String, dynamic> paymentDetails;
  final Map<String, dynamic> referenceDetails;
  final String version;

  InvoiceRegisterRequest({
    required this.documentDetails,
    required this.transactionType,
    required this.sourceSystem,
    required this.sellerDetails,
    required this.buyerDetails,
    required this.itemList,
    required this.valueDetails,
    required this.paymentDetails,
    required this.referenceDetails,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
    'DocumentDetails': documentDetails,
    'TransactionType': transactionType,
    'SourceSystem': sourceSystem,
    'SellerDetails': sellerDetails,
    'BuyerDetails': buyerDetails,
    'ItemList': itemList,
    'ValueDetails': valueDetails,
    'PaymentDetails': paymentDetails,
    'ReferenceDetails': referenceDetails,
    'Version': version,
  };
}

class InvoiceCancelRequest {
  final String irn;
  final String reasonCode;

  InvoiceCancelRequest({required this.irn, required this.reasonCode});

  Map<String, dynamic> toJson() => {'Irn': irn, 'ReasonCode': reasonCode};
}

class SupplyItem {
  final String? id;
  final String itemCode;
  final String productDescription;
  final String natureOfSupplies;
  final double unitPrice;
  final String unit;
  final String taxCode;
  final double discount;
  final double exciseTaxRate;
  final bool isExciseTaxable;

  SupplyItem({
    this.id,
    required this.itemCode,
    required this.productDescription,
    required this.natureOfSupplies,
    required this.unitPrice,
    required this.unit,
    required this.taxCode,
    this.discount = 0,
    this.exciseTaxRate = 0,
    this.isExciseTaxable = false,
  });

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
    id: json['id'] is String ? json['id'] : json['id'].toString(),
    itemCode: json['item_code'] ?? '',
    productDescription: json['product_description'] ?? '',
    natureOfSupplies: json['nature_of_supplies'] ?? '',
    unitPrice: (num.parse(json['unit_price'])).toDouble() ?? 0.0,
    unit: json['unit'] ?? 'pcs',
    taxCode: json['tax_code'] ?? 'VAT15',
    discount: (num.parse(json['discount'])).toDouble() ?? 0.0,
    exciseTaxRate: (num.parse(json['excise_tax_rate'])).toDouble() ?? 0.0,
    isExciseTaxable: json['is_excise_taxable'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'item_code': itemCode,
    'product_description': productDescription,
    'nature_of_supplies': natureOfSupplies,
    'unit_price': unitPrice,
    'unit': unit,
    'tax_code': taxCode,
    'discount': discount,
    'excise_tax_rate': exciseTaxRate,
    'is_excise_taxable': isExciseTaxable,
  };
}
