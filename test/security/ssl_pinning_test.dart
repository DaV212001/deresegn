import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/services/ssl_pinning_service.dart';

class MockX509Certificate implements X509Certificate {
  @override
  final Uint8List der;
  @override
  final String subject;
  @override
  final String issuer;
  @override
  final DateTime startValidity;
  @override
  final DateTime endValidity;
  @override
  final Uint8List sha1;
  @override
  final String pem;

  MockX509Certificate({
    required this.der,
    this.subject = 'CN=api.deresegn.com',
    this.issuer = 'CN=YR1, O=Let\'s Encrypt, C=US',
    DateTime? startValidity,
    DateTime? endValidity,
    Uint8List? sha1,
    this.pem = '',
  })  : startValidity = startValidity ?? DateTime(2026, 1, 1),
        endValidity = endValidity ?? DateTime(2027, 1, 1),
        sha1 = sha1 ?? Uint8List(20);
}

void main() {
  group('SslPinningService Tests', () {
    tearDown(() {
      SslPinningService.testFingerprints.clear();
    });

    test('isPinnedHost correctly identifies target domains', () {
      expect(SslPinningService.isPinnedHost('api.deresegn.com'), isTrue);
      expect(SslPinningService.isPinnedHost('www.api.deresegn.com'), isTrue);
      expect(SslPinningService.isPinnedHost('deresegn.com'), isTrue);
      expect(SslPinningService.isPinnedHost('sub.api.deresegn.com'), isTrue);

      // Unpinned hosts
      expect(SslPinningService.isPinnedHost('google.com'), isFalse);
      expect(SslPinningService.isPinnedHost('attacker-mitm.net'), isFalse);
    });

    test('isCertificateValid rejects arbitrary certificate on pinned domain', () {
      final cert = MockX509Certificate(
        der: Uint8List.fromList(utf8.encode('untrusted-proxy-cert')),
      );

      final isApproved = SslPinningService.isCertificateValid(cert, 'api.deresegn.com');
      expect(isApproved, isFalse);
    });

    test('isCertificateValid approves certificate matching registered fingerprint', () {
      final testDerBytes = Uint8List.fromList(utf8.encode('trusted-test-cert-data'));
      final digest = sha256.convert(testDerBytes);
      final b64Fingerprint = base64Encode(digest.bytes);

      // Register the fingerprint as trusted
      SslPinningService.testFingerprints.add(b64Fingerprint);

      final cert = MockX509Certificate(der: testDerBytes);
      final isApproved = SslPinningService.isCertificateValid(cert, 'api.deresegn.com');
      expect(isApproved, isTrue);
    });

    test('isCertificateValid allows unpinned hosts through standard validation', () {
      final cert = MockX509Certificate(
        der: Uint8List.fromList(utf8.encode('random-cert')),
      );

      // For unpinned domains, isCertificateValid returns true (delegated to OS)
      final isApproved = SslPinningService.isCertificateValid(cert, 'other-service.com');
      expect(isApproved, isTrue);
    });

    test('isCertificateValid rejects null certificate on pinned domain', () {
      final isApproved = SslPinningService.isCertificateValid(null, 'api.deresegn.com');
      expect(isApproved, isFalse);
    });

    test('createPinnedAdapter returns non-null adapter', () {
      final adapter = SslPinningService.createPinnedAdapter();
      expect(adapter, isNotNull);
    });
  });
}
