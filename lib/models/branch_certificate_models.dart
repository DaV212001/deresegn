class BranchCsrRequest {
  final String tin;
  final String systemNumber;
  final String organizationName;
  final String organizationalUnit;
  final String email;
  final bool? force;

  BranchCsrRequest({
    required this.tin,
    required this.systemNumber,
    required this.organizationName,
    required this.organizationalUnit,
    required this.email,
    this.force,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'tin': tin,
      'system_number': systemNumber,
      'organization_name': organizationName,
      'organizational_unit': organizationalUnit,
      'email': email,
    };
    if (force == true) {
      map['force'] = true;
    }
    return map;
  }

  factory BranchCsrRequest.fromJson(Map<String, dynamic> json) => BranchCsrRequest(
        tin: json['tin']?.toString() ?? '',
        systemNumber: json['system_number']?.toString() ?? '',
        organizationName: json['organization_name']?.toString() ?? '',
        organizationalUnit: json['organizational_unit']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        force: json['force'] == true,
      );
}

class BranchCsrResponse {
  final String message;
  final String csr;
  final int branchId;
  final bool alreadyInstalled;

  BranchCsrResponse({
    required this.message,
    required this.csr,
    required this.branchId,
    this.alreadyInstalled = false,
  });

  factory BranchCsrResponse.fromJson(Map<String, dynamic> json) => BranchCsrResponse(
        message: json['message']?.toString() ?? '',
        csr: json['csr']?.toString() ?? '',
        branchId: json['branch_id'] is int
            ? json['branch_id'] as int
            : (int.tryParse('${json['branch_id']}') ?? 0),
        alreadyInstalled: json['already_installed'] == true,
      );
}

class BranchCertificateUploadRequest {
  final String certificate;

  BranchCertificateUploadRequest({required this.certificate});

  Map<String, dynamic> toJson() => {
        'certificate': certificate,
      };

  factory BranchCertificateUploadRequest.fromJson(Map<String, dynamic> json) =>
      BranchCertificateUploadRequest(
        certificate: json['certificate']?.toString() ?? '',
      );
}

class BranchCertificateUploadResponse {
  final String message;
  final int branchId;
  final bool matchesPrivateKey;

  BranchCertificateUploadResponse({
    required this.message,
    required this.branchId,
    required this.matchesPrivateKey,
  });

  factory BranchCertificateUploadResponse.fromJson(Map<String, dynamic> json) =>
      BranchCertificateUploadResponse(
        message: json['message']?.toString() ?? '',
        branchId: json['branch_id'] is int
            ? json['branch_id'] as int
            : (int.tryParse('${json['branch_id']}') ?? 0),
        matchesPrivateKey: json['matches_private_key'] == true,
      );
}

class BranchCertificateStatusResponse {
  final int branchId;
  final bool hasPrivateKey;
  final bool hasCertificate;
  final bool certificateMatchesKey;
  final String status;
  final String message;
  final bool isInstalled;
  final bool hasCsr;
  final Map<String, dynamic> raw;

  BranchCertificateStatusResponse({
    this.branchId = 0,
    this.hasPrivateKey = false,
    this.hasCertificate = false,
    this.certificateMatchesKey = false,
    required this.status,
    required this.message,
    required this.isInstalled,
    required this.hasCsr,
    required this.raw,
  });

  factory BranchCertificateStatusResponse.fromJson(Map<String, dynamic> json) {
    final branchId = json['branch_id'] is int
        ? json['branch_id'] as int
        : (int.tryParse('${json['branch_id']}') ?? 0);

    final bool hasPrivateKey = json['has_private_key'] == true;
    final bool hasCertificate = json['has_certificate'] == true;
    final bool certificateMatchesKey = json['certificate_matches_key'] == true;

    final statusStr = (json['status'] ?? json['certificate_status'] ?? '').toString().toLowerCase();

    // A certificate is fully installed and operational when:
    // (hasCertificate && certificateMatchesKey) OR explicitly marked is_installed / active
    final bool installed = (hasCertificate && certificateMatchesKey) ||
        json['is_installed'] == true ||
        json['certificate_installed'] == true ||
        statusStr == 'installed' ||
        statusStr == 'active';

    // A CSR / private key exists if hasPrivateKey is true, or has_csr / csr_generated is true
    final bool csr = hasPrivateKey ||
        json['has_csr'] == true ||
        json['csr_generated'] == true ||
        statusStr == 'pending' ||
        statusStr == 'csr_generated';

    return BranchCertificateStatusResponse(
      branchId: branchId,
      hasPrivateKey: hasPrivateKey,
      hasCertificate: hasCertificate,
      certificateMatchesKey: certificateMatchesKey,
      status: statusStr,
      message: json['message']?.toString() ?? '',
      isInstalled: installed,
      hasCsr: csr,
      raw: json,
    );
  }
}

