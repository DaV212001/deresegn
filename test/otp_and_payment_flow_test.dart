import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/config/config_preference.dart';
import 'package:deresegn/models/otp_models.dart';
import 'package:deresegn/models/payment_package_models.dart';

void main() {
  group('OTP Flow Models and Payloads', () {
    test('CompanyOtpVerifyRequest serializes correctly with phone and code', () {
      final req = CompanyOtpVerifyRequest(phone: '0949384998', code: '123456');
      final json = req.toJson();

      expect(json['phone'], '0949384998');
      expect(json['code'], '123456');
    });

    test('BranchOtpVerifyRequest serializes with phone_number and code', () {
      final req = BranchOtpVerifyRequest(phoneNumber: '0949384998', code: '969532');
      final json = req.toJson();

      expect(json['phone_number'], '0949384998');
      expect(json['code'], '969532');
    });

    test('ResendOtpRequest serializes with phone', () {
      final req = ResendOtpRequest(phone: '0949384998');
      final json = req.toJson();

      expect(json['phone'], '0949384998');
    });
  });

  group('Payment Packages Flow Models and Status Checks', () {
    test('PaymentPackage parses from API response correctly', () {
      final raw = {
        "id": 2,
        "name": "Standard",
        "description": "Standard MOR package for medium businesses",
        "price": "1200.00",
        "duration_days": 30,
        "daily_invoice_limit": 50,
      };

      final pkg = PaymentPackage.fromJson(raw);
      expect(pkg.id, 2);
      expect(pkg.name, 'Standard');
      expect(pkg.price, 1200.0);
      expect(pkg.formattedPrice, '1200 ETB');
      expect(pkg.durationDays, 30);
      expect(pkg.dailyInvoiceLimit, 50);
      expect(pkg.isUnlimitedInvoices, false);
      expect(pkg.isAnnual, false);
    });

    test('PaymentPackage handles unlimited invoices and annual duration', () {
      final raw = {
        "id": 5,
        "name": "Annual Premium",
        "description": "Premium MOR package - annual billing",
        "price": "25000.00",
        "duration_days": 365,
        "daily_invoice_limit": null,
      };

      final pkg = PaymentPackage.fromJson(raw);
      expect(pkg.id, 5);
      expect(pkg.isUnlimitedInvoices, true);
      expect(pkg.isAnnual, true);
      expect(pkg.formattedPrice, '25000 ETB');
    });

    test('PaymentInitializeRequest serializes to expected payload', () {
      final req = PaymentInitializeRequest(
        branchId: 29,
        packageId: 1,
        email: 'samuelasamnew13@gmail.com',
        firstName: 'SAMUEL',
        lastName: 'ASAMNEW',
        phoneNumber: '0949384998',
        returnUrl: 'https://deresegn.com/payment/done',
      );

      final json = req.toJson();
      expect(json['branch_id'], 29);
      expect(json['package_id'], 1);
      expect(json['email'], 'samuelasamnew13@gmail.com');
      expect(json['first_name'], 'SAMUEL');
      expect(json['last_name'], 'ASAMNEW');
      expect(json['phone_number'], '0949384998');
      expect(json['return_url'], 'https://deresegn.com/payment/done');
    });

    test('PaymentStatusResponse parses success and branch subscription data', () {
      final raw = {
        "status": "success",
        "tx_ref": "DERESEGN-29-20260907084937-IQXDJY",
        "ref_id": "APfydyqE0qx38",
        "amount": "500.00",
        "paid_at": "2026-09-07T08:50:47.000000Z",
        "branch": {
          "id": 29,
          "package_id": 1,
          "payment_date": "2026-09-07T08:50:47.000000Z",
          "no_of_day": 30,
          "expired_date": "2026-10-07T00:00:00.000000Z",
        },
      };

      final res = PaymentStatusResponse.fromJson(raw);
      expect(res.isSuccess, true);
      expect(res.txRef, 'DERESEGN-29-20260907084937-IQXDJY');
      expect(res.amount, '500.00');
      expect(res.branch?['package_id'], 1);
      expect(res.branch?['no_of_day'], 30);
    });

    test('Login response status evaluation logic distinguishes active vs pending/expired', () {
      // Branch Login Response (test_credentials account)
      final activeLoginResponse = {
        "branch": {
          "id": 29,
          "status": "active",
          "package_id": 1,
          "expired_date": "2099-12-31T00:00:00.000000Z",
        },
        "token": "valid_token",
      };

      final branchData = activeLoginResponse['branch'] as Map<String, dynamic>;
      final status = '${branchData['status']}'.toLowerCase();
      final expiredDate = branchData['expired_date']?.toString();
      bool isActive = status == 'active';
      if (expiredDate != null && expiredDate.isNotEmpty) {
        final expiry = DateTime.tryParse(expiredDate);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          isActive = false;
        }
      }
      expect(isActive, true);

      // Pending / Unpaid Branch
      final pendingResponse = {
        "branch": {
          "id": 37,
          "status": "pending",
          "package_id": null,
          "expired_date": null,
        },
      };
      final pendingData = pendingResponse['branch'] as Map<String, dynamic>;
      expect('${pendingData['status']}'.toLowerCase() == 'active', false);

      // Expired Branch
      final expiredResponse = {
        "branch": {
          "id": 29,
          "status": "active",
          "package_id": 1,
          "expired_date": "2020-01-01T00:00:00.000000Z", // Past date
        },
      };
      final expiredData = expiredResponse['branch'] as Map<String, dynamic>;
      final expStatus = '${expiredData['status']}'.toLowerCase();
      final expDate = expiredData['expired_date']?.toString();
      bool isExpActive = expStatus == 'active';
      if (expDate != null) {
        final expiry = DateTime.tryParse(expDate);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          isExpActive = false;
        }
      }
      expect(isExpActive, false);
    });

    test('Registration response structure differences handled', () {
      // Registration response has user and branch without token initially
      final regResponse = {
        "message": "Registration initiated. Please verify your phone number with the OTP sent.",
        "user": {
          "company_id": 41,
          "name": "Owner",
          "phone": "0988112234",
          "is_verified": false,
        },
        "branch": {
          "id": 37,
          "branch_name": "Head Office",
          "status": "pending",
        },
      };

      final user = regResponse['user'] as Map<String, dynamic>;
      final branch = regResponse['branch'] as Map<String, dynamic>;
      final isVerified = user['is_verified'] == true;
      final branchStatus = '${branch['status']}'.toLowerCase();

      expect(isVerified, false);
      expect(branchStatus, 'pending');
    });

    test('Receipt URL path detection accurately detects redirection to receipt', () {
      bool isReceiptUrl(String url) {
        final uri = Uri.tryParse(url);
        final path = (uri?.path ?? '').toLowerCase();
        final full = url.toLowerCase();
        return path.contains('receipt') ||
            path.contains('/receipt') ||
            full.contains('/checkout/payment-receipt') ||
            full.contains('receipt');
      }

      // Should match URLs containing receipt
      expect(isReceiptUrl('https://checkout.chapa.co/checkout/payment-receipt/DERESEGN-29-20260907084937-IQXDJY'), true);
      expect(isReceiptUrl('https://api.deresegn.com/api/payment/receipt/12345'), true);
      expect(isReceiptUrl('https://deresegn.com/payment/receipt'), true);
      expect(isReceiptUrl('https://checkout.chapa.co/receipt?ref=123'), true);

      // Should not match non-receipt checkout URLs
      expect(isReceiptUrl('https://checkout.chapa.co/checkout/payment/APfydyqE0qx38'), false);
      expect(isReceiptUrl('https://checkout.chapa.co/checkout/otp-verify'), false);
      expect(isReceiptUrl('https://api.deresegn.com/api/payment/initialize'), false);
    });
  });
}
