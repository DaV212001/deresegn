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
        'clientId': clientId,
        'clientSecret': clientSecret,
        'apikey': apikey,
        'tin': tin,
      };
}
