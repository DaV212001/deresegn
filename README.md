# Deresegn POS Mobile App

**Version:** 1.0.6+7  
**Framework:** Flutter (Dart >=3.0.0, SDK ^3.12.2)  
**Backend:** Laravel 8 REST API (`https://api.deresegn.com`)  
**Target Platform:** Android (API 21 to 35, compileSdk 35, Java 17) & iOS  

Deresegn POS is an enterprise-grade Point of Sale (POS) and SaaS mobile application built with Flutter. It seamlessly integrates with the Ethiopian Ministry of Revenues (MoR) e-invoicing system to facilitate secure, compliant fiscal transactions.

---

## Key Features

- **MoR Fiscal Integration:** Digitally signs and submits fiscal invoices, credit/debit notes, sales receipts, and withholding receipts compliant with Ministry of Revenues (MoR) specifications.
- **Offline Resilience:** Safely queues transactions locally using `shared_preferences` during internet outages, with automated synchronization upon connectivity restoration.
- **Multi-Tenant Architecture:** Strict JWT-based authentication for Company Owners and Branch-level users, preserving tenant data boundaries.
- **Supply & Item Catalog:** Fast item lookup, custom tax calculation (VAT 15%, TOT 2%/10%, Exempt, Zero-Rated, Excise Tax), and receipt generation.
- **PDF Generation & Printing:** Instant generation of styled PDF invoices and receipts with embedded MoR-verified QR codes.
- **Bilingual & Theming:** Complete localization (English & Amharic) and dynamic Light/Dark mode themes.

---

## Enterprise Security Controls

- **Device Integrity & Anti-Tampering (CWE-693):**
  - Continuous runtime root & jailbreak detection via `flutter_jailbreak_detection` (RootBeer).
  - Filesystem scans for `su` binaries and dangerous props.
  - Frida dynamic instrumentation detection (TCP socket probes on ports 27042/27043, memory map scanning `/proc/self/maps`).
  - Automated session wipe (`ConfigPreference.clearAll()`) and execution blocking via a non-dismissible `SecurityAlertScreen`.
- **Dual-Layer SSL/TLS Certificate Pinning (CWE-295):**
  - Native Android `network_security_config.xml` enforcing system-only trust anchors and SHA-256 pin-set.
  - Dio HTTP client adapter with SHA-256 fingerprint verification (`SslPinningService`), blocking proxy CAs (e.g. Burp Suite, Charles) and MITM attacks.
- **Account Lockout & Rate-Limit Protection (CWE-307):**
  - Automated parsing of backend lockout and cooldown durations from HTTP 403 / 429 responses.
  - Persistent lockout expiry tracking in secure storage.
  - Interactive UI countdown banner (`Locked: MM:SS`) disabling submit buttons during active cooldown periods.
  - Auth endpoint exemption from session logout interceptors, preserving user-entered credentials on invalid attempts.
- **Hardware-Backed Cryptography:**
  - AES-256 encrypted local credential storage via `flutter_secure_storage` (Android Keystore / iOS Keychain).

---

## Prerequisites & Environment

- **Flutter SDK:** ^3.12.2
- **Dart SDK:** >=3.0.0
- **Java:** JDK 17 (Java 17 bytecode target)
- **Android Gradle Plugin (AGP):** 8.x / 9.x compatible (`compileSdk = 35`, `minSdk = 21`)

---

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/DaV212001/deresegn.git
   cd deresegn
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

4. **Run unit & security tests:**
   ```bash
   flutter test
   ```

5. **Build a release APK:**
   ```bash
   flutter build apk --release
   ```
   *Output APK: `build/app/outputs/flutter-apk/app-release.apk`*

---

## Documentation

Comprehensive security documentation and INSA compliance specifications are available in:
- `Security_Assessment_Submission/` — Official INSA security submission index, SRS, SDD, TDD, user guides, data classification, and threat model.
- `INSA_Documentation_Combined.md` — Consolidated assessment documentation.
