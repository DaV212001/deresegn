class CompanyRegisterRequest {
  final String companyName,
      tinNumber,
      ownerName,
      phone,
      password,
      email,
      website;
  CompanyRegisterRequest({
    required this.companyName,
    required this.tinNumber,
    required this.ownerName,
    required this.phone,
    required this.password,
    required this.email,
    required this.website,
  });
  Map<String, dynamic> toJson() => {
    'company_name': companyName,
    'tin_number': tinNumber,
    'owner_name': ownerName,
    'phone': phone,
    'password': password,
    'email': email,
    'website': website,
  };
}

class CompanyLoginRequest {
  final String phone, password, companyId;
  CompanyLoginRequest({
    required this.phone,
    required this.password,
    required this.companyId,
  });
  Map<String, dynamic> toJson() => {
    'phone': phone,
    'password': password,
    'company_id': int.tryParse(companyId) ?? companyId,
  };
}

class CompanySummary {
  final String id, name;
  CompanySummary({required this.id, required this.name});
  factory CompanySummary.fromJson(Map<String, dynamic> json) => CompanySummary(
    id: '${json['id'] ?? json['company_id'] ?? ''}',
    name:
        '${json['company_name'] ?? json['name'] ?? json['legal_name'] ?? 'Company'}',
  );
}
