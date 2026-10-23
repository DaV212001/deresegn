class CompanyOtpVerifyRequest {
  final String phone;
  final String code;

  CompanyOtpVerifyRequest({required this.phone, required this.code});

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'code': code,
      };
}

class BranchOtpVerifyRequest {
  final String phoneNumber;
  final String code;

  BranchOtpVerifyRequest({required this.phoneNumber, required this.code});

  Map<String, dynamic> toJson() => {
        'phone_number': phoneNumber,
        'code': code,
      };
}

class ResendOtpRequest {
  final String phone;

  ResendOtpRequest({required this.phone});

  Map<String, dynamic> toJson() => {
        'phone': phone,
      };
}
