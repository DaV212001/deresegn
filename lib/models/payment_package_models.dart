class PaymentPackage {
  final int id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final int? dailyInvoiceLimit;

  PaymentPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    this.dailyInvoiceLimit,
  });

  factory PaymentPackage.fromJson(Map<String, dynamic> json) {
    return PaymentPackage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse('${json['price']}') ?? 0.0,
      durationDays: json['duration_days'] is int
          ? json['duration_days']
          : int.tryParse('${json['duration_days']}') ?? 30,
      dailyInvoiceLimit: json['daily_invoice_limit'] == null
          ? null
          : (json['daily_invoice_limit'] is int
              ? json['daily_invoice_limit']
              : int.tryParse('${json['daily_invoice_limit']}')),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price.toStringAsFixed(2),
        'duration_days': durationDays,
        'daily_invoice_limit': dailyInvoiceLimit,
      };

  bool get isUnlimitedInvoices => dailyInvoiceLimit == null;
  bool get isAnnual => durationDays >= 365;
  String get formattedPrice => '${price.toStringAsFixed(0)} ETB';
}

class PaymentInitializeRequest {
  final int branchId;
  final int packageId;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String returnUrl;

  PaymentInitializeRequest({
    required this.branchId,
    required this.packageId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.returnUrl = 'https://deresegn.com/payment/done',
  });

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'package_id': packageId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'return_url': returnUrl,
      };
}

class PaymentInitializeResponse {
  final String? checkoutUrl;
  final String? txRef;
  final String? status;
  final String? message;
  final Map<String, dynamic>? raw;

  PaymentInitializeResponse({
    this.checkoutUrl,
    this.txRef,
    this.status,
    this.message,
    this.raw,
  });

  factory PaymentInitializeResponse.fromJson(dynamic json) {
    if (json is! Map) {
      return PaymentInitializeResponse(raw: {});
    }
    final map = Map<String, dynamic>.from(json);
    final data = map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map;

    return PaymentInitializeResponse(
      checkoutUrl: data['checkout_url'] ?? data['url'] ?? map['checkout_url'],
      txRef: data['tx_ref'] ?? data['reference'] ?? map['tx_ref'],
      status: map['status']?.toString(),
      message: map['message']?.toString(),
      raw: map,
    );
  }
}

class PaymentStatusResponse {
  final String status;
  final String? txRef;
  final String? refId;
  final String? amount;
  final String? paidAt;
  final Map<String, dynamic>? branch;

  PaymentStatusResponse({
    required this.status,
    this.txRef,
    this.refId,
    this.amount,
    this.paidAt,
    this.branch,
  });

  bool get isSuccess => status.toLowerCase() == 'success';

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponse(
      status: json['status']?.toString() ?? '',
      txRef: json['tx_ref']?.toString(),
      refId: json['ref_id']?.toString(),
      amount: json['amount']?.toString(),
      paidAt: json['paid_at']?.toString(),
      branch: json['branch'] is Map ? Map<String, dynamic>.from(json['branch']) : null,
    );
  }
}
