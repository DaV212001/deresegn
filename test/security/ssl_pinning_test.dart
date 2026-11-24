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
    this.issuer = 'CN=PortSwigger CA, O=PortSwigger, C=UK',
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

    test('isCertificateValid approves live api.deresegn.com production certificate', () {
      const liveHex =
          '99:1C:94:53:85:BC:F6:D2:B5:D1:1A:E9:7F:AC:CB:27:D0:3F:11:BD:0F:19:F1:A2:58:77:0D:29:12:D3:31:C5';
      expect(SslPinningService.pinnedSha256Fingerprints.contains(liveHex), isTrue);
    });

    test('isCertificateValid dynamically approves future auto-renewed Let\'s Encrypt certificates', () {
      final cert = MockX509Certificate(
        der: Uint8List.fromList(utf8.encode('future-renewed-cert-unseen-hash')),
        issuer: 'CN=YR3, O=Let\'s Encrypt, C=US',
        subject: 'CN=www.api.deresegn.com',
        startValidity: DateTime.now().subtract(const Duration(days: 1)),
        endValidity: DateTime.now().add(const Duration(days: 89)),
      );

      final isApproved = SslPinningService.isCertificateValid(cert, 'api.deresegn.com');
      expect(isApproved, isTrue);
    });

    test('isCertificateValid rejects expired certificates even if from Let\'s Encrypt', () {
      final cert = MockX509Certificate(
        der: Uint8List.fromList(utf8.encode('expired-cert')),
        issuer: 'CN=YR2, O=Let\'s Encrypt, C=US',
        subject: 'CN=www.api.deresegn.com',
        startValidity: DateTime(2025, 1, 1),
        endValidity: DateTime(2025, 4, 1),
      );

      final isApproved = SslPinningService.isCertificateValid(cert, 'api.deresegn.com');
      expect(isApproved, isFalse);
    });
  });
}
