# Mobile Application Security Testing Requirements Document
**Application Version**: v1.0.6+7  
**Prepared By**: Information Network Security Administration (INSA) 2026  
**Submitted by**: Micro Sun and Solutions PLC (MSS)  
**Submitted to**: Information Network Security Administration (INSA)  
**Date**: September 2026  

---

## Table of Contents
1. Introduction
    1. Purpose
    2. Ownership
    3. Scope
    4. Objective of this certificate requested
2. Legal and Administrative Documents
3. Technical Documentation for Web Application Security Testing
    1. Business Architecture and Design
    2. Features of the Web Application
    3. Security Functionality Document
    4. Secure Coding Standard Documentation
    5. Threat Modeling & Risk Management
    6. Previous Security Testing Reports
    7. OS Supported by the Mobile Application
    8. Hybrid Framework Specifics
    9. Logging & Monitoring Setup
    10. Specific Functionalities for Detailed Testing
    11. Restrictions or Limitations on Testing Approach
    12. Compliance or Regulatory Requirements
    13. Known Vulnerabilities or Security Concerns Status
4. API Security Audit Requirements
    1. API Types
    2. Authentication Mechanism
    3. Third-Party Integrations
    4. Authorization and Access Control
    5. Full API Documentation
5. Contact Information and Communication Channel
6. Specific Scope Table
7. Threat Model Mapping
8. System Functionality
9. Conclusion

---

## Background of Organization

Micro Sun and Solutions PLC (MSS) is an IT company founded in January 1997, specializing in hardware and network solutions. We offer customized solutions tailored to various industries, including government, banking, and telecom. We focus on high-quality software development and implementation, providing comprehensive corporate solutions across multiple sectors. Our company emphasizes 100% customer satisfaction and aims to deliver quality products and services at an affordable cost.

---

## 1. Introduction

### 1.1 Purpose
This document provides an overview of the Web and Mobile Application Security Testing Requirements Document, compiled for the Information Network Security Administration (INSA). The application in scope is the **Deresegn Point of Sale (POS) and SaaS Application**, which integrates with the Ethiopian Ministry of Revenues (MoR) e-invoicing system.

### 1.2 Ownership
The owner of this document is the **Deresegn Engineering and Compliance Department**. 

### 1.3 Scope
The scope encompasses the security mechanisms, architectural layouts, and data flows of the Deresegn POS/SaaS application:
- The Flutter-based mobile client interfaces.
- The Laravel 8 (PHP) backend REST API.
- The local SharedPreferences storage handling offline queuing.
- The integration with the Ministry of Revenues (MoR) e-invoicing API.

### 1.4 Objective of this certificate requested
The objective of requesting this security certificate is to comply with the national cybersecurity mandates established by the Information Network Security Administration (INSA). Obtaining this certification ensures that the Deresegn Point of Sale (POS) and SaaS Application meets the rigorous security, integrity, and confidentiality standards required before public rollout and handling sensitive MoR fiscal data.

---

## 2. Legal and Administrative Documents (Mandatory)

The following legal prerequisites and administrative documents are mandatory prior to the finalization of the INSA audit:
1. **Updated Trade License**: [Placeholder for Trade License ID]
2. **TIN Number or National ID**: [Placeholder for TIN Number]
3. **System/Product Patent Certificate (if available)**: [Placeholder for Patent]

---

## 3. Technical Documentation for Web Application Security Testing

### 3.1 Business Architecture and Design

#### 3.1.1 Data Flow Diagram (DFD)
![Data Flow Diagram](dfd.png)

1. **Invoice Initialization**: The cashier (User) selects items and initiates an invoice on the Flutter POS Application.
2. **Local Validation**: The mobile app validates inventory and necessary fields locally.
3. **Network Check & Queuing**: 
   - Offline: The transaction is queued securely in local SharedPreferences.
   - Online: The request is transmitted via HTTPS to the Laravel backend.
4. **Backend Processing & Authentication**: The Laravel API authenticates the user via a JWT token. It checks the specific Branch TIN and fetches the Branch Password to request a temporary MoR token.
5. **Fiscal Registration**: The backend submits the payload to the MoR API. The MoR returns a fiscal receipt number.
6. **Finalization**: The backend updates the database and returns a success response.

#### 3.1.2 System Architecture Diagram
![System Architecture Diagram](sys_arch.png)

- **Presentation Layer (Frontend)**: Flutter (Dart). Employs GetX for state management and routing, and SharedPreferences for offline queuing.
- **Application Layer (Backend)**: Built with the Laravel 8 framework.
- **Data Layer (Backend)**: Relational MySQL database. Storage for receipts is offloaded to the local server storage.
- **Integration Layer**: Connects securely with the Ministry of Revenues (MoR) API.

#### 3.1.3 Entity Relationship Diagram (ERD)
![Entity Relationship Diagram](erd.png)

**Key Entities and Definitions**:
- **COMPANY & COMPANY_USERS**: `COMPANY` represents the master tenant. `COMPANY_USERS` contains `name`, `phone`, `password`, and `role`. 
- **COMPANY_BRANCHES**: Represent the physical stores tied to a company. They contain the critical `tin_number`, `client_id`, and `client_secret` (encrypted via model casts).
- **MOR_INVOICES**: The central fiscal transactional record. Holds `irn`, `document_number`, `status`, and the `full_response` (JSON). Tied to both a Branch and a Company.
- **MOR_RECEIPTS**: Represents actual payments synced with the MoR. 
- **SUPPLIES**: Represents inventory items, holding `item_code`, `unit_price`, and `tax_code`.

### 3.2 Features of the Web Application
- **Development Frameworks**: Flutter (SDK ^3.12.2) and Dart (>=3.0.0) for Frontend; Laravel 8 (PHP) for Backend.
- **Offline Reliability**: Invoices generated during internet outages are converted to JSON and queued locally in SharedPreferences.
- **Actor Types**: 
  - *Super Admin / Owner*: Global oversight, company registration.
  - *Branch Users*: Restricted to specific branch checkout functions.

### 3.3 Security Functionality Document

#### 3.3.1 Authentication and Access Control
1. **Access Allocation**: Users are assigned roles (e.g., owner) upon creation.
2. **API Authentication**: Executed via JSON Web Tokens (JWT). The payload is signed with an HS256 cryptographic secret.

#### 3.3.2 User ID Authentication
Authentication utilizes unique Phone Numbers and Passwords tied to specific Company IDs.

#### 3.3.3 Change Password
The application relies on users to set their password during registration or account creation. There is currently no mechanism that forces a user to change their password upon their first login. 

#### 3.3.4 User ID / Password Management
Each user registers with a unique Phone Number. The system relies on administrative procedures to discourage the sharing of accounts between cashiers.

#### 3.3.5 Sharing Information
Users are expected to keep their credentials confidential.

#### 3.3.6 Complexity of Password
The backend API enforces a minimum password length of six (6) characters during registration and login. Passwords are mathematically hashed exclusively using Laravel's native Bcrypt implementation (`Hash::make`). There are no programmatic requirements for special characters, numbers, or mixed casing.

#### 3.3.7 Password Expiry
The application does not currently enforce password expiration or rotation. Passwords remain valid indefinitely unless manually changed by the user or an administrator.

#### 3.3.8 Password History
Password history is not tracked in the database. Users are permitted to reuse old passwords if they choose to change them.

#### 3.3.9 Invalid Login Attempt (CWE-307 Mitigation)
If a user submits an incorrect password, the API returns a standard `401 Unauthorized` response. The mobile app's `AuthInterceptor._isAuthOrPublicEndpoint()` exempts the following paths from auto-logout token clearing routines: `/api/company/login`, `/api/branch/login`, `/api/company/register`, `/api/login`, `/api/companies`, any path containing `/verify`, and any path containing `/resend-otp`. This ensures that user-entered credentials in input fields are preserved for convenient correction rather than forcefully flushed.

#### 3.3.10 Lockout Duration & Live Countdown Timer (CWE-307 Mitigation)
When consecutive invalid authentication attempts trigger server-side rate limits (returning HTTP 403 Forbidden or HTTP 429 Too Many Requests with messages such as `"Too many login attempts. Please try again in 29 minutes."`), the mobile application's `AuthController.handleLockoutIfPresent()` dynamically parses the remaining cooldown duration.
1. **Duration Parsing**: Uses regular expression `(\d+)\s*(minute|min|second|sec|hour|hr)s?` (case-insensitive) to extract the cooldown value. Accepts hours, minutes, and seconds (including short forms `hr`, `min`, `sec`) and plural forms. If no match is found, defaults to 1800 seconds (30 minutes).
2. **Timestamp Persistence**: Persists the exact cooldown expiry epoch (milliseconds) in secure storage via `ConfigPreference.saveLockout()` under keys `auth_lockout_expiry` and `auth_lockout_message`. The countdown is **restored across app restarts** via `AuthController._restoreLockoutIfActive()` called during `onInit()`.
3. **Interactive UI Countdown**: A prominent red security alert banner displays a real-time countdown timer (`Locked: MM:SS` for durations under 1 hour; `HH:MM:SS` for longer durations).
4. **Submission Lock**: The login submit button is programmatically disabled until the countdown finishes, systematically mitigating automated brute-force and credential-stuffing attacks.

#### 3.3.11 Session Idle Time
The JWT Time-To-Live (TTL) is configured to expire after 60 minutes. Once the 60 minutes elapse, the token is invalidated and the user must re-authenticate.

#### 3.3.12 Dual-Layer SSL/TLS Certificate Pinning (CWE-295 Mitigation)
- **Data in Transit**: All API communications occur exclusively over HTTPS (TLS 1.2+). The application enforces dual-layer SSL/TLS certificate pinning against `api.deresegn.com`:
  1. **Native Android Layer**: Configured via `network_security_config.xml` with system-only trust anchors (blocking user-installed CAs such as Burp Suite or Charles Proxy) and SHA-256 pin-sets.
  2. **Application Network Layer**: The Flutter Dio HTTP client utilizes `IOHttpClientAdapter` and `SslPinningService` to validate the SHA-256 fingerprints of certificates presented during TLS handshakes, dropping any tampered connections immediately.
- **Data at Rest**: Passwords are never stored in plaintext (hashed using Bcrypt). Sensitive MoR credentials (`client_secret`, `api_key`) in the `company_branches` table are encrypted at rest using Laravel's model casting mechanism (`encrypted`). On the mobile client, all tokens and keys are encrypted via `flutter_secure_storage` (AES-256 backed by Android Keystore).

#### 3.3.13 Device Integrity & Anti-Tampering (CWE-693 Mitigation)
The mobile application embeds a proactive multi-tier security inspection engine via `SecurityService`:
1. **Root & Jailbreak Detection**: Integrates `flutter_jailbreak_detection` (leveraging native RootBeer checks on Android for su binaries, test-keys, Magisk, Superuser.apk, and busybox; and sandbox integrity on iOS) combined with direct filesystem scans (`/system/bin/su`, `/system/xbin/su`, `/sbin/su`, etc.).
2. **Dynamic Instrumentation (Frida) Detection**: Probes default Frida server TCP ports (27042 and 27043) and scans `/proc/self/maps` for injected hook agents (`frida-agent`, `xposed`, `substrate`).
3. **Automated Incident Response**: Upon compromise detection, the app immediately purges all secure storage items (`ConfigPreference.clearAll()`), resets HTTP clients (`DioConfig.resetDio()`), and locks execution with a non-dismissible `SecurityAlertScreen` (`PopScope(canPop: false)`).
4. **Lifecycle Re-validation**: Integrity checks re-trigger whenever the application resumes from the background (`AppLifecycleState.resumed`).

### 3.4 Secure Coding Standard Documentation

#### 3.4.1 Secure Coding Requirements
- **Input Validation**: API endpoints utilize Laravel Validator logic (e.g., `Validator::make`) to ensure required fields and correct data types are passed.
- **Database Safety**: The Eloquent ORM is utilized to interact with the MySQL database, which utilizes PDO parameterization to mitigate SQL Injection (SQLi) vulnerabilities.
- **Secrets Management**: Database credentials and JWT secrets are injected via environment variables (`.env`).

### 3.5 Threat Modeling & Risk Management

#### 3.5.1 Asset Identification
1. **Critical (High Risk)**: MoR fiscal tokens, Branch TIN passwords, user password hashes.
2. **Important (Medium Risk)**: Invoice historical data.
3. **Public (Low Risk)**: Item catalogs.

#### 3.5.2 Risk Assessment and Management
- **Spoofing**: Mitigated by stateless JWT validation ensuring requests originate from authenticated users.
- **Information Disclosure**: Prevented by hiding sensitive data (like the `client_secret` and `api_key`) from API JSON responses using Laravel's `$hidden` array on Eloquent models.

### 3.6 Previous Security Testing Reports
The application relies on standard Laravel and Flutter linting alongside standard functional testing. Any comprehensive penetration testing is performed prior to major production releases locally.

### 3.7 OS Supported by the Mobile Application
The application supports the Android operating system (with iOS architecture ready). 
* **Minimum Supported OS:** Android 5.0 (Lollipop) - API Level 21 (`minSdkVersion 21`).
* **Maximum / Target OS:** Android 15 - API Level 35 (`compileSdkVersion 35`, `targetSdkVersion 35`).
* **Build System & Runtime:** Gradle 8.x / 9.x compatible Kotlin DSL (`build.gradle.kts`), Java 17 bytecode target (`JavaVersion.VERSION_17`, `jvmTarget = JVM_17`), Application ID `com.eims.deresegn`.
*(Note: iOS is currently out of scope for this specific audit, but the Flutter framework is cross-platform capable).*

### 3.8 Hybrid Framework Specifics
The Deresegn mobile application is a high-performance cross-platform application developed using the **Flutter framework (SDK ^3.12.2)** and Dart language (>=3.0.0). 
* **State Management & Routing:** Handled by the `get` plugin (GetX ^4.7.3).
* **Network & API Communication:** Managed via `dio` (^5.10.0) configured with `SslPinningService` for certificate validation.
* **Storage & Native Keystore:** Uses `flutter_secure_storage` (^10.3.1) for hardware-backed AES-256 encryption via Android Keystore, and `shared_preferences` (^2.5.5) for managing the local offline invoice queue.
* **Device Integrity & Hardening:** Uses `flutter_jailbreak_detection` (^1.10.0) with native RootBeer integration, and `crypto` (^3.0.6) for SHA-256 fingerprint verification.
* **Compilation:** Compiles directly to native ARM AOT binary code, ensuring high performance without relying on web-views for business logic.

### 3.9 Logging & Monitoring Setup
The application utilizes the `logger` package to track user activity, network state changes, and security events. 
* **Client-Side Logging:** Important application state changes (e.g., `Network restored, attempting to sync offline queue`, `Company authentication required`) and HTTP request failures are logged to the console for debugging. 
* **Production Alerting:** In production, standard HTTP 4xx and 5xx errors are captured by backend server logs.

### 3.10 Specific Functionalities for Detailed Testing
We request that the INSA audit specifically focuses on the following security-critical workflows:
1. **Invoice Generation:** The core flow of generating, validating, and submitting fiscal invoices securely to the MoR.
2. **The Offline-to-Online Sync Mechanism:** Validating the security of invoices temporarily queued in `shared_preferences` during network outages.
3. **MoR Token Exchange:** The backend process of reading the Branch TIN and Password, requesting a temporary MoR token, and signing the fiscal receipt.
4. **Multi-Tenant Authentication:** The JWT-based login flows (`/api/company/login`, `/api/branch/login`) ensuring strict data isolation between companies and branches.
5. **Security Controls & Device Hardening:** Verifying root/jailbreak blocking, Frida hooking prevention (CWE-693), SSL certificate pinning (CWE-295), and rate-limit lockout timer countdown enforcement (CWE-307).

### 3.11 Restrictions or Limitations on Testing Approach
* **No Denial-of-Service (DoS) or DDoS:** Please refrain from conducting volumetric attacks against the production API (`https://api.deresegn.com`).
* **Safe Testing Environment:** All dynamic testing should be conducted using the provided Test Accounts. Testers must not tamper with or attempt to modify live financial data belonging to other companies in the multi-tenant database.

### 3.12 Compliance or Regulatory Requirements
The application strictly adheres to the fiscal and invoicing regulations mandated by the **Ethiopian Ministry of Revenues (MoR)**. This requires exact formatting of JSON payloads, strict transmission of tax codes, and secure handling of Branch TINs and passwords.

### 3.13 Known Vulnerabilities or Security Concerns Status
* **Password Rotation:** The system currently does not enforce a mandatory password rotation policy or require users to change their passwords upon first login.
* **Brute-Force & Rate Limiting (Resolved):** Successfully mitigated via backend rate-limiting paired with client-side lockout duration parsing, persistent timestamp storage, live countdown timer banners (`Locked: MM:SS`), and submit button disabling (CWE-307).
* **Root & Jailbreak Detection (Resolved):** Successfully mitigated via `flutter_jailbreak_detection` (RootBeer), filesystem su scans, Frida port/map probing, automated session wipe, and non-dismissible blocking UI (CWE-693).
* **SSL Pinning (Resolved):** Successfully mitigated via dual-layer pinning (`network_security_config.xml` + Dio `IOHttpClientAdapter` with SHA-256 fingerprint verification) preventing MITM and untrusted CA injection (CWE-295).

---

## 4. API Security Audit Requirements

### 4.1 API Types
The backend exposes RESTful APIs utilizing HTTP methods and JSON formats.

### 4.2 Authentication Mechanism
1. **Client to Backend**: Authenticated using **JWT (JSON Web Tokens)** passed in the `Authorization: Bearer <token>` header.
2. **Backend to MoR**: The Laravel server reads the branch's specific TIN and Password from the database, exchanges them for a temporary MoR token, and injects this temporary token into the headers of fiscal requests.

### 4.3 Third-Party Integrations
The primary integration is the **Ethiopian Ministry of Revenues (MoR) e-invoicing API**. 

### 4.4 Authorization and Access Control
Endpoints are protected by JWT middleware to ensure that only authenticated companies and their respective users can access their financial records.

### 4.5 Full API Documentation
The mobile client interacts with the backend over HTTPS (`https://api.deresegn.com`). 

#### Core Authentication & Organization Endpoints
* **`GET /api/companies`** 
  * **Description:** Retrieves a public list of active companies for the pre-login picker.
  * **Response:** Array of objects `[{ "id": integer, "company_name": string }]`

* **`POST /api/company/register`** 
  * **Description:** Registers a new parent company and owner user.
  * **Request Body:** `{ "company_name": string (required), "tin_number": string (required), "owner_name": string (required), "phone": string (required), "password": string (required, min: 6), "email": string (optional), "website": string (optional) }`
  * **Response:** `{ "user": object, "token": JWT }` (201 Created)

* **`POST /api/company/login`** 
  * **Description:** Authenticates the parent company/owner user.
  * **Note:** `company_id` is **not** sent in the request body — the server resolves company context from the JWT.
  * **Request Body:** `{ "phone": string (required), "password": string (required) }`
  * **Response:** `{ "user": object, "token": JWT }`

* **`POST /api/branch/login`** 
  * **Description:** Authenticates a specific branch using its registered phone number and branch password.
  * **Note:** The JSON key is `phone_number`.
  * **Request Body:** `{ "phone_number": "0949384998", "password": "Maru@123" }`
  * **Response:** `{ "token": "<branch_jwt>", "branch": { "id", "company_id", "branch_name", "tin_number", "client_id", "status", ... } }`

* **`POST /api/branches`** (Requires Bearer Token)
  * **Description:** Creates a new branch under the authenticated company.
  * **Request Body (Multipart Form):** `branch_name`, `location`, `phone_number`, `email`, `tin_number`, `client_id`, `client_secret`, `api_key`, `password`, `private_key` (file), `certificate` (file).
  * **Response:** The created branch object (201 Created)

#### Supply Catalog Endpoints
* **`GET /api/branches/{branch_id}/supplies`**
  * **Description:** Retrieves the list of supplies/items in the catalog for the active branch (e.g., `https://api.deresegn.com/api/branches/29/supplies`).
* **`POST /api/branches/{branch_id}/supplies`**
  * **Description:** Adds a new item to the branch supply catalog.

#### Ministry of Revenues (MoR) Integration Endpoints
*All routes below (except `/api/refresh/token`) require a `Branch-Id` header to resolve the specific branch's MoR credentials.*

* **`POST /api/login`**
  * **Description:** Automates the MoR authentication flow using the branch's securely stored `client_secret` and `api_key`.
  * **Headers:** `Branch-Id: <branch_id>`
  * **Response:** Forwards the MoR authorization token.

* **`POST /api/invoice/register`**
  * **Description:** Registers a new fiscal invoice with the MoR.
  * **Headers:** `Branch-Id: <branch_id>`, `Mor-Token: <token>`
  * **Request Body:** Follows exact MoR JSON specification for invoice payload.
  * **Response:** Forwards MoR response (e.g., success, validation errors).

* **`POST /api/cancel/invoice`**
  * **Description:** Cancels a previously registered MoR invoice.
  * **Headers:** `Branch-Id: <branch_id>`, `Mor-Token: <token>`

* **`POST /api/irn/verfiy`**
  * **Description:** Verifies an Invoice Reference Number (IRN) with the MoR.
  * **Headers:** `Branch-Id: <branch_id>`, `Mor-Token: <token>`

* **`POST /api/receipt/sales`** & **`POST /api/receipt/withholding`**
  * **Description:** Submits standard sales and withholding receipts to MoR.
  * **Headers:** `Branch-Id: <branch_id>`, `Mor-Token: <token>`

* **`POST /api/refresh/token`**
  * **Description:** Refreshes an existing MoR authorization token.

#### Invoice Retrieval Endpoints (Read-Only)
* **`GET /api/invoices`** & **`GET /api/invoices/{id}`**
  * **Description:** Retrieves historical invoices registered by the application.
* **`GET /api/receipts/{type}/{value}`** 
  * **Description:** Retrieval endpoint supporting multiple identifier types (e.g., `rrn`, `mor`, `irn`).

---

## 5. Contact Information and Communication Channel
| Name | Role | Address (Email and Mobile) |
| :--- | :--- | :--- |
| Amanuiel Tilahun | CIO | Email: tilahunamanuiel0@gmail.com <br> Mobile: +251911058179 |

---

## 6. Specific Scope Table
| Name of the Assets to be Audited | APK/official link | Test Account | Static Analysis | Dynamic Analysis | Automated Source Code Analysis |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Deresegn POS Mobile App (v1.0.6+7) | **Binary Release:** `app-release.apk` (enclosed in submission archive) <br><br> **Source Code (Static Analysis):** [GitHub Repository](https://github.com/DaV212001/deresegn) | **Company login:** <br> Phone: 251911234567 <br> Password: password123 <br> Company ID: 9 <br><br> **Branch login:** <br> Phone Number: 0949384998 <br> Password: Maru@123 | Yes | Yes | Yes |
| Deresegn Backend API | https://api.deresegn.com | *(Tested via mobile app accounts above)* | No | Yes | No |

---

## 7. Threat Model Mapping

The following threat model mapping identifies possible attack vectors against the Deresegn POS/SaaS application and outlines the applied security controls and risk mitigation measures:

| Attack Vector | Description | Applied Security Controls & Mitigation |
| :--- | :--- | :--- |
| **Device Integrity / Root / Frida (CWE-693)** | Device rooted or running dynamic hooking (Frida, Xposed) to extract in-memory tokens or bypass validation. | **Mitigated:** `SecurityService` utilizes `flutter_jailbreak_detection` (RootBeer), filesystem su scans, and Frida port/map probing. Detection immediately flushes all secure storage (`ConfigPreference.clearAll()`) and terminates app flow with a non-dismissible `SecurityAlertScreen`. |
| **Man-in-the-Middle / Proxy Interception (CWE-295)** | Intercepting API traffic with user-installed proxy CAs (e.g. Burp Suite, Charles Proxy). | **Mitigated:** Dual-layer SSL certificate pinning. Android `network_security_config.xml` rejects non-system CAs, and Dio `IOHttpClientAdapter` with `SslPinningService` validates SHA-256 fingerprints of certificates presented during TLS handshakes. |
| **Broken Authentication & Brute Force (CWE-307)** | Automated credential guessing / brute-force attacks against login endpoints. | **Mitigated:** Backend rate limiting returns cooldown durations (403/429), and the mobile app parses cooldown time, persists `auth_lockout_expiry`, displays a real-time countdown banner (`Locked: MM:SS`), and disables the submit button. Form fields are retained without clearing state. |
| **Injection (SQLi / XSS)** | Malicious data inputs targeting the database or frontend views to execute arbitrary commands. | The Laravel backend exclusively uses the Eloquent ORM, which utilizes PDO parameterization by default, effectively mitigating SQL injection. The Flutter frontend uses type-safe Dart models and does not execute dynamic HTML, mitigating Cross-Site Scripting (XSS). |
| **Insecure Storage** | Exposure of sensitive credentials or offline data on the physical mobile device. | Critical data, such as JWT session tokens and MoR credentials, are stored securely using `flutter_secure_storage` (AES-256 backed by the Android Keystore / iOS Keychain). Offline invoices are queued locally and do not contain user passwords or administrative credentials. |
| **Sensitive Data Exposure** | Interception of MoR API credentials or fiscal data in transit between the client, backend, and the MoR. | All communications between the mobile app, backend, and MoR occur over encrypted HTTPS (TLS 1.2+). Database-level MoR credentials (`client_secret`, `api_key`) are encrypted at rest using Laravel's native model casting (`encrypted`). |

---

## 8. System Functionality

The Deresegn POS/SaaS mobile application provides a comprehensive suite of functionalities tailored for point-of-sale operations and fiscal compliance. 

### Key Functionalities
- **Authentication**: The application utilizes a JWT-based login mechanism via `/api/company/login` and `/api/branch/login`. The mobile application securely stores the JWT within the native Android Keystore for secure session management.
- **Financial Transactions & Invoicing (Security-Critical)**: This is the most security-critical feature. The app captures sales items, strictly calculates tax structures (including excise, TOT, and VAT), and queues the invoice. The backend dynamically fetches branch-specific encrypted MoR credentials, generates a temporary authorization token, cryptographically signs the fiscal payload, and syncs it with the Ministry of Revenues via `/api/invoice/register`.
- **Sensitive Data Handling (Offline Queue Management)**: During network outages, signed invoices are serialized and stored locally on the device to prevent data loss. Upon network restoration, a background service securely synchronizes these pending financial transactions with the backend.
- **Third-Party Integrations**: The application relies exclusively on the Ethiopian Ministry of Revenues (MoR) e-invoicing API. All payloads are strictly formatted to MoR specifications and transmitted over mTLS/HTTPS.
- **Notifications & UI Modals**: The application uses local UI dialogs and GetX snackbars to immediately notify cashiers of transaction success, network outages, or MoR validation failures.

---

## 9. Conclusion
Micro Sun and Solutions PLC is fully committed to maintaining a robust security posture for the Deresegn POS/SaaS application. Through the implementation of strict JWT authentication, secure local storage, local offline queuing, and encrypted MoR token management, we have designed the application to protect sensitive fiscal data at rest and in transit. We welcome INSA's comprehensive security audit to validate our compliance, strengthen our service delivery, and reduce our exposure to cyber threats.
