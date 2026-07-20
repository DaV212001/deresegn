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
    "clientId": "127ae9ad-8de2-4856-ba88-4e6a49ad10d0",
    "clientSecret": "d3ddb848-9daa-44ab-8d96-374fcc8c9e6b",
    "apikey": "dc481579-a6e7-4594-abcf-5493e261685e",
    "tin": "0000037187",
  };
}

// {
//   "url": "https://api.deresegn.com/api/login",
//   "method": "POST",
//   "headers": {
//     "content-type": "application/json"
//   },
//   "body": {
//     "clientId": "127ae9ad-8de2-4856-ba88-4e6a49ad10d0",
//     "clientSecret": "d3ddb848-9daa-44ab-8d96-374fcc8c9e6b",
//     "apiKey": "dc481579-a6e7-4594-abcf-5493e261685e",
//     "tin": "0000037187"
//   }
// }
