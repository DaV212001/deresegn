class LoginRequest {
  final String clientId;
  final String clientSecret;
  final String apikey;
  final String tin;

  LoginRequest({
    required this.clientId,
    required this.clientSecret,
    required this.apikey,
    required this.tin,
  });

  Map<String, dynamic> toJson() => {
    "clientId": clientId,
    "clientSecret": clientSecret,
    "apiKey": apikey,
    "tin": tin,
  };
}

class BranchLoginRequest {
  final String tinNumber;
  final String password;

  BranchLoginRequest({required this.tinNumber, required this.password});

  Map<String, dynamic> toJson() => {
    "phone_number": tinNumber,
    "password": password,
  };
}

class InvoiceVerificationRequest {
  final String irn;

  InvoiceVerificationRequest({required this.irn});

  Map<String, dynamic> toJson() => {"irn": irn};
}

class FcmTokenRegistrationRequest {
  final String fcmToken;
  final String platform;

  FcmTokenRegistrationRequest({
    required this.fcmToken,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
        "fcm_token": fcmToken,
        "device_info": {
          "platform": platform,
        },
      };
}
