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
  /// 1. api.deresegn.com Leaf Certificate
  /// 2. Let's Encrypt Intermediate CA (YR1)
  /// 3. Let's Encrypt Root CA (ISRG Root X1)
  static const Set<String> pinnedSha256Fingerprints = {
    // 1. api.deresegn.com Leaf Certificate
    'AB:C7:DD:71:67:2F:9C:38:A2:B0:A7:EB:1D:44:51:08:02:ED:5F:46:34:25:AA:89:23:29:54:95:60:B3:B8:65',
    'ABC7DD71672F9C38A2B0A7EB1D44510802ED5F463425AA892329549560B3B865',
    'q8fdcWcvnDiisKfrHURRCALtX0Y0JaqJIylUlWCzuGU=',

    // 2. Intermediate CA (YR1 / Let's Encrypt)
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
