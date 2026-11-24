import '../utils/phone_utils.dart';

class CompanyOtpVerifyRequest {
  final String phone;
  final String code;

  CompanyOtpVerifyRequest({required String phone, required this.code})
      : phone = PhoneUtils.formatForAuth(phone);

  Map<String, dynamic> toJson() => {
        'phone': PhoneUtils.formatForAuth(phone),
        'code': code,
      };
}

class BranchOtpVerifyRequest {
  final String phoneNumber;
  final String code;

  BranchOtpVerifyRequest({required String phoneNumber, required this.code})
      : phoneNumber = PhoneUtils.isValidEthiopianPhone(phoneNumber)
            ? PhoneUtils.formatForAuth(phoneNumber)
            : phoneNumber;

  Map<String, dynamic> toJson() => {
        'phone_number': PhoneUtils.isValidEthiopianPhone(phoneNumber)
            ? PhoneUtils.formatForAuth(phoneNumber)
            : phoneNumber,
        'code': code,
      };
}

class ResendOtpRequest {
  final String phone;

  ResendOtpRequest({required String phone}) : phone = PhoneUtils.formatForAuth(phone);

  Map<String, dynamic> toJson() => {
        'phone': PhoneUtils.formatForAuth(phone),
      };
}
