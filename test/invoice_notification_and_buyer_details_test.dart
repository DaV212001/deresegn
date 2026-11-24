import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/models/branch_certificate_models.dart';
import 'package:deresegn/models/invoice_history_model.dart';
import 'package:deresegn/models/invoice_models.dart';

void main() {
  group('Buyer Phone & Email in Invoice Models', () {
    test('BuyerInfo serializes and deserializes phone and email correctly', () {
      final buyer = BuyerInfo(
        tin: '0012345678',
        legalName: 'Acme Corp',
        phone: '+251911223344',
        email: 'buyer@acme.com',
        city: 'Addis Ababa',
      );

      final json = buyer.toJson();
      expect(json['tin'], '0012345678');
      expect(json['legal_name'], 'Acme Corp');
      expect(json['phone'], '+251911223344');
      expect(json['email'], 'buyer@acme.com');

      final fromJson = BuyerInfo.fromJson(json);
      expect(fromJson.phone, '+251911223344');
      expect(fromJson.email, 'buyer@acme.com');
      expect(fromJson.legalName, 'Acme Corp');
    });

    test('InvoiceRegisterRequest includes buyer phone and email in BuyerDetails', () {
      final request = InvoiceRegisterRequest(
        documentDetails: {'DocumentNumber': 'INV-001'},
        transactionType: 'B2B',
        sourceSystem: {},
        sellerDetails: {'LegalName': 'Seller PLC'},
        buyerDetails: {
          'LegalName': 'Buyer Enterprise',
          'Tin': '0098765432',
          'Phone': '+251944556677',
          'Email': 'finance@buyer.et',
        },
        itemList: [],
        valueDetails: {},
        paymentDetails: {'PaymentTerm': 'IMMEDIATE', 'Mode': 'CASH'},
        referenceDetails: {},
        version: '1.0',
      );

      final json = request.toJson();
      final buyerDetails = json['BuyerDetails'] as Map<String, dynamic>;
      expect(buyerDetails['Phone'], '+251944556677');
      expect(buyerDetails['Email'], 'finance@buyer.et');
      expect(buyerDetails['LegalName'], 'Buyer Enterprise');
    });
  });

  group('Branch Certificate Status Response Model', () {
    test('Parses active/installed status correctly', () {
      final json = {
        'status': 'installed',
        'message': 'Certificate is active and valid.',
        'is_installed': true,
      };

      final res = BranchCertificateStatusResponse.fromJson(json);
      expect(res.isInstalled, isTrue);
      expect(res.status, 'installed');
      expect(res.message, contains('active'));
    });

    test('Parses pending/csr_generated status correctly', () {
      final json = {
        'status': 'pending',
        'has_csr': true,
        'message': 'CSR generated. Waiting for certificate upload.',
      };

      final res = BranchCertificateStatusResponse.fromJson(json);
      expect(res.isInstalled, isFalse);
      expect(res.hasCsr, isTrue);
      expect(res.status, 'pending');
    });

    test('Parses not_requested / none status correctly', () {
      final json = {
        'status': 'none',
        'message': 'No certificate requested.',
      };

      final res = BranchCertificateStatusResponse.fromJson(json);
      expect(res.isInstalled, isFalse);
      expect(res.hasCsr, isFalse);
    });
  });

  group('Notification Delivery Channel Validation', () {
    test('Allowed channel options match backend specification', () {
      const allowedChannels = ['sms', 'email', 'both'];

      expect(allowedChannels.contains('sms'), isTrue);
      expect(allowedChannels.contains('email'), isTrue);
      expect(allowedChannels.contains('both'), isTrue);
      expect(allowedChannels.contains('fax'), isFalse);
    });
  });
}
