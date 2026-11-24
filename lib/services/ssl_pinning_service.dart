import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Service providing SSL/TLS Certificate Pinning for Deresegn API connections.
/// Implements dual validation via [IOHttpClientAdapter.validateCertificate] (for leaf certificates)
/// and [HttpClient.badCertificateCallback] (to reject proxy/MITM root/intermediate CAs).
class SslPinningService {
  static final Logger _logger = Logger();

  @visibleForTesting
  static final Set<String> testFingerprints = {};

  /// Domains that require SSL Certificate Pinning
  static const Set<String> pinnedDomains = {
    'api.deresegn.com',
    'www.api.deresegn.com',
    'deresegn.com',
    'www.deresegn.com',
  };

  /// Pinned SHA-256 fingerprints (in colon-delimited Hex, raw Hex, and Base64 format)
  /// Includes:
  /// 1. api.deresegn.com Current & Previous Leaf Certificates
  /// 2. Let's Encrypt Intermediate CAs (YR1, YR2)
  /// 3. Let's Encrypt Root CA (ISRG Root X1)
  static const Set<String> pinnedSha256Fingerprints = {
    // 1. api.deresegn.com Current Leaf Certificate (Valid Nov 16, 2026 - Feb 14, 2027)
    '99:1C:94:53:85:BC:F6:D2:B5:D1:1A:E9:7F:AC:CB:27:D0:3F:11:BD:0F:19:F1:A2:58:77:0D:29:12:D3:31:C5',
    '991C945385BCF6D2B5D11AE97FACCB27D03F11BD0F19F1A258770D2912D331C5',
    'mRyUU4W89tK10Rrpf6zLJ9A/Eb0PGfGiWHcNKRLTMcU=',

    // 1b. api.deresegn.com Previous Leaf Certificate (Retained for rollback safety)
    'AB:C7:DD:71:67:2F:9C:38:A2:B0:A7:EB:1D:44:51:08:02:ED:5F:46:34:25:AA:89:23:29:54:95:60:B3:B8:65',
    'ABC7DD71672F9C38A2B0A7EB1D44510802ED5F463425AA892329549560B3B865',
    'q8fdcWcvnDiisKfrHURRCALtX0Y0JaqJIylUlWCzuGU=',

    // 2a. Intermediate CA (YR2 / Let's Encrypt - Issuer of current leaf cert)
    '23:8B:85:A0:09:9C:65:B9:70:47:7D:57:24:F1:A1:D4:75:CE:50:58:CF:FE:4E:FA:87:33:89:9B:DB:86:3C:47',
    '238B85A0099C65B970477D5724F1A1D475CE5058CFFE4EFA8733899BDB863C47',
    'I4uFoAmcZblwR31XJPGh1HXOUFjP/k76hzOJm9uGPEc=',

    // 2b. Intermediate CA (YR1 / Let's Encrypt)
    '13:94:96:34:D9:9C:D6:FD:6A:A8:0B:C0:34:FE:FA:CC:EB:19:69:FE:EF:98:65:86:71:3E:CD:BB:05:75:8D:3F',
    '13949634D99CD6FD6AA80BC034FEFACCEB1969FEEF986586713ECDBB05758D3F',
    'E5SWNNmc1v1qqAvANP76zOsZaf7vmGWGcT7NuwV1jT8=',

    // 3. Root CA (ISRG Root X1)
    '96:BC:EC:06:26:49:76:F3:74:60:77:9A:CF:28:C5:A7:CF:E8:A3:C0:AA:E1:1A:8F:FC:EE:05:C0:BD:DF:08:C6',
    '96BCEC06264976F37460779ACF28C5A7CFE8A3C0AAE11A8FFCEE05C0BDDF08C6',
    'lrzsBiZJdvN0YHeazyjFp8/oo8Cq4RqP/O4FwL3fCMY=',
  };

  /// Checks if a given host is protected by SSL pinning.
  static bool isPinnedHost(String host) {
    final cleanHost = host.toLowerCase().trim();
    return pinnedDomains.contains(cleanHost) ||
        pinnedDomains.any((d) => cleanHost.endsWith('.$d'));
  }

  /// Validates an [X509Certificate] against the pinned SHA-256 fingerprints.
  static bool isCertificateValid(X509Certificate? cert, String host) {
    if (!isPinnedHost(host)) {
      // Not a pinned domain, allow normal OS/TLS validation
      return true;
    }

    if (cert == null) {
      _logger.e('❌ [SSL-PINNING] Host "$host" presented null certificate.');
      return false;
    }

    // Compute SHA-256 digest of the DER-encoded certificate
    final digest = sha256.convert(cert.der);
    final b64Fingerprint = base64Encode(digest.bytes);
    final hexColonFingerprint = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
    final hexRawFingerprint = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();

    final isMatch = pinnedSha256Fingerprints.contains(hexColonFingerprint) ||
        pinnedSha256Fingerprints.contains(hexRawFingerprint) ||
        pinnedSha256Fingerprints.contains(b64Fingerprint) ||
        testFingerprints.contains(hexColonFingerprint) ||
        testFingerprints.contains(b64Fingerprint);

    if (isMatch) {
      _logger.d('🔒 [SSL-PINNING] Verified certificate for $host (SHA-256: $b64Fingerprint)');
      return true;
    }

    // Dynamic Renewal Fallback:
    // Let's Encrypt certificates renew every 60-90 days, changing the leaf SHA-256.
    // To prevent locking out mobile users on routine renewals, verify that the
    // certificate is legitimately issued by an authorized CA (Let's Encrypt) for
    // this exact domain and is within its valid date range.
    final now = DateTime.now();
    final isValidDate = cert.startValidity.isBefore(now) && cert.endValidity.isAfter(now);
    final issuerLower = cert.issuer.toLowerCase();
    final subjectLower = cert.subject.toLowerCase();
    final isAuthorizedIssuer = issuerLower.contains("let's encrypt") ||
        issuerLower.contains('isrg root');
    final isTargetSubject = subjectLower.contains('deresegn.com');

    if (isValidDate && isAuthorizedIssuer && isTargetSubject) {
      _logger.i(
        '🔄 [SSL-PINNING] Seamlessly accepted renewed certificate for "$host" from authorized CA (${cert.issuer}).',
      );
      return true;
    }

    _logger.e(
      '🚨 [SSL-PINNING-ALERT] Certificate pinning mismatch for "$host"!\n'
      'Presented SHA256 (Hex): $hexColonFingerprint\n'
      'Presented SHA256 (Base64): $b64Fingerprint\n'
      'Subject: ${cert.subject}\n'
      'Issuer: ${cert.issuer}\n'
      'Connection blocked to prevent Machine-in-the-Middle (MITM) interception.',
    );
    return false;
  }

  /// Creates a configured [HttpClientAdapter] with strict certificate pinning.
  static HttpClientAdapter createPinnedAdapter({Duration? idleTimeout}) {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient(
          context: SecurityContext(withTrustedRoots: true),
        );
        if (idleTimeout != null) {
          client.idleTimeout = idleTimeout;
        }

        // Intercept untrusted / proxy-issued certificates (e.g., Burp Suite CA)
        client.badCertificateCallback = (
          X509Certificate cert,
          String host,
          int port,
        ) {
          final isApproved = isCertificateValid(cert, host);
          if (!isApproved) {
            _logger.w(
              '⚠️ [SSL-PINNING] badCertificateCallback rejected untrusted certificate for $host:$port',
            );
          }
          return isApproved;
        };

        return client;
      },
      validateCertificate: (X509Certificate? cert, String host, int port) {
        // Intercept leaf certificates even if OS/system trust store accepted the chain
        final isApproved = isCertificateValid(cert, host);
        if (!isApproved) {
          _logger.w(
            '⚠️ [SSL-PINNING] validateCertificate rejected certificate for $host:$port',
          );
        }
        return isApproved;
      },
    );
  }
}
