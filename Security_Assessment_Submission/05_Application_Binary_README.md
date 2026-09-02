# Deresegn POS — Application Binary Submission Instructions

**Document Version:** 1.0  
**Application Version:** 1.0.3+4  
**Date:** August 5, 2026  
**Classification:** Confidential  
**Prepared by:** Micro Sun & Solution PLC  

---

## 1. Binary Details

| Property | Value |
|---|---|
| Application Name | Deresegn POS |
| Package Identifier | com.example.deresegn |
| Version | 1.0.3+4 |
| Framework | Flutter (Dart SDK ^3.12.2) |
| Target Platforms | Android (APK), iOS (IPA) |
| Build Type | Release |

---

## 2. Building the Binary

### 2.1 Android APK

To generate the release APK, run the following command from the project root:

```bash
flutter build apk --release
```

The output APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### 2.2 iOS IPA

To generate the iOS build (requires macOS with Xcode):

```bash
flutter build ios --release
```

Then archive and export via Xcode to produce the IPA file.

---

## 3. Submission Package Structure

```
Mobile_App_Binary.zip
├── app-release.apk          (Android release binary)
├── BINARY_README.md          (This document)
└── test_credentials.txt      (Test account credentials — if applicable)
```

Or for iOS:

```
Mobile_App_Binary.zip
├── app.ipa                   (iOS release binary)
├── BINARY_README.md          (This document)
└── test_credentials.txt      (Test account credentials — if applicable)
```

---

## 4. Test Configuration

### 4.1 Backend API
- **API Base URL:** `https://api.deresegn.com`
- **Protocol:** HTTPS (TLS 1.2+)
- The app is pre-configured to communicate with the production API endpoint.

### 4.2 Test Accounts
Test credentials must be provisioned separately by the application administrator. The assessment team will need:

1. **Company Owner Account:**
   - Phone number
   - Password
   - Company ID

2. **Branch Account:**
   - TIN number
   - Password

3. **MoR Credentials (auto-loaded from branch):**
   - Client ID
   - Client Secret
   - API Key
   - Private key file (`.key`)
   - Certificate file (`.pem`)

> **Note:** Contact the application administrator to provision test accounts. Do not use production accounts for security testing.

---

## 5. Version Correspondence

| Component | Version |
|---|---|
| Mobile Application | 1.0.3+4 |
| Backend API | Laravel 8 (production) |
| SRS Document | 1.0 |
| SDD Document | 1.0 |
| TDD Document | 1.0 |
| User Guide | 1.0 |

The submitted binary corresponds directly to the application version documented in all accompanying submission documents.

---

## 6. Security Attestation

The submitted binary:

- [x] Does NOT contain hardcoded production credentials in the final build
- [x] Development fallback values exist in `ConfigPreference` for MoR credentials but are overridden by values provisioned during branch setup
- [x] Does NOT contain private keys
- [x] Does NOT embed secrets in the APK/IPA bundle
- [ ] The following development defaults are present as fallbacks (documented in TDD Section 3.3):
  - Default Client ID: `127ae9ad-8de2-4856-ba88-4e6a49ad10d0`
  - Default Client Secret: `d3ddb848-9daa-44ab-8d96-374fcc8c9e6b`
  - Default API Key: `dc481579-a6e7-4594-abcf-5493e261685e`
  - Default TIN: `0000037187`

---

## 7. Minimum Device Requirements

### Android
- **OS:** Android 5.0 (API 21) or higher
- **RAM:** 2 GB minimum
- **Storage:** 100 MB free space
- **Permissions:** Internet access, file system access (for PDF export)

### iOS
- **OS:** iOS 12.0 or higher
- **RAM:** 2 GB minimum
- **Storage:** 100 MB free space
