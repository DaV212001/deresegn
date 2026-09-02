# Deresegn POS — Software Requirements Specification (SRS)

**Document Version:** 1.0  
**Application Version:** 1.0.3+4  
**Date:** August 5, 2026  
**Classification:** Confidential  
**Prepared by:** Micro Sun & Solution PLC  

---

## 1. Application Overview and Objectives

### 1.1 Purpose
Deresegn POS is a comprehensive mobile Point of Sale (POS) and SaaS application designed for Ethiopian businesses. The application enables merchants to create, register, and manage fiscal invoices and receipts in compliance with the Ethiopian Ministry of Revenues (MoR) e-invoicing system.

### 1.2 Objectives
- Provide a mobile-first POS solution for businesses operating within Ethiopia's fiscal framework.
- Automate secure authentication and token exchange with the MoR e-invoicing API for invoice registration, cancellation, verification, and receipt submission.
- Enable offline-capable invoice generation with automatic synchronization upon network restoration.
- Support multi-tenant architecture allowing multiple companies and branches to operate independently.
- Generate MoR-compliant PDF invoices and receipts with signed QR codes.
- Manage product/supply catalogs for streamlined invoicing.

---

## 2. Scope

### 2.1 In-Scope Features
- Company registration and authentication (owner-level)
- Branch creation with MoR credential provisioning (TIN, client certificates, API keys)
- Branch-level authentication with JWT token management
- MoR API authentication (login, token refresh)
- Invoice creation (B2B, B2C, Credit Note, Debit Note) with multi-line item support
- Invoice registration with the MoR e-invoicing gateway
- Invoice cancellation
- Invoice verification by IRN (Invoice Reference Number)
- Sales receipt registration
- Withholding receipt registration
- Offline invoice queuing and automatic synchronization
- Invoice history browsing with pagination and date filtering
- PDF generation for invoices and receipts
- Product/supply catalog management (CRUD)
- Multi-currency support (ETB default, foreign currency with exchange rate)
- Tax calculation: VAT (15%), TOT (2%, 10%), Exempt, Zero-rated
- Excise tax computation
- Light/Dark theme support
- Bilingual interface (English and Amharic)

### 2.2 Out-of-Scope
- Payment gateway integration (e.g., Chapa is not integrated in the current mobile build)
- Inventory management beyond product catalogs
- Customer relationship management (CRM)
- Web-based admin dashboard (handled separately)
- Bulk invoice registration from the mobile client

---

## 3. Stakeholders

| Stakeholder | Role | Description |
|---|---|---|
| Company Owner | Primary User | Registers companies, creates branches, manages organizational setup |
| Branch Operator / Cashier | End User | Generates invoices, registers receipts, manages daily transactions |
| System Administrator | IT Support | Manages backend services, certificates, and API credentials |
| Ethiopian Ministry of Revenues (MoR) | Regulatory Authority | Receives and validates all fiscal documents |
| Micro Sun & Solution PLC | Application Developer | Develops and maintains the Deresegn platform |

---

## 4. Functional Requirements

### 4.1 Authentication & Authorization

| ID | Requirement | Description |
|---|---|---|
| FR-AUTH-01 | Company Registration | Owners register a company with name, TIN, phone, email, and password. System returns a JWT access token. |
| FR-AUTH-02 | Company Login | Owners log in with phone, password, and company ID. System authenticates against the `company_users` table and returns a JWT. |
| FR-AUTH-03 | Branch Creation | Authenticated owners create branches by uploading MoR private keys and certificates, along with TIN, client ID, client secret, and API key. |
| FR-AUTH-04 | Branch Login | Branch operators log in with TIN and password. System matches against `company_branches` and returns a branch-scoped JWT. |
| FR-AUTH-05 | MoR Login | After branch authentication, the system automatically performs MoR API login using stored credentials, receiving an MoR access token and refresh token. |
| FR-AUTH-06 | Token Refresh | When the MoR token expires (detected via 401 responses), the system automatically refreshes the token using the stored refresh token. |
| FR-AUTH-07 | Session Expiry Handling | Expired branch tokens redirect users to the login screen. MoR token failures trigger automatic refresh with request retry. |

### 4.2 Invoice Management

> **Regulatory MoR Specification Reference:**  
> All invoice and receipt registration formats, payload structures, and fiscal response expectations specified in Sections 4.2 and 4.3 strictly implement the non-public e-Invoicing API Specification provided by the Ministry of Revenues (MoR) to registered software vendors (*Enclosed: `/References/MoR_eInvoicing_API_Specification.pdf`*).

| ID | Requirement | Description |
|---|---|---|
| FR-INV-01 | Invoice Generation | Users create invoices by entering buyer details, adding line items (description, quantity, unit price, tax code, discounts), and selecting payment mode and document type. |
| FR-INV-02 | Invoice Registration | Invoices are submitted to the backend, which signs the payload with the branch's private key and certificate, then forwards it to the MoR API. A signed QR code and IRN are returned. |
| FR-INV-03 | Invoice Cancellation | Users can cancel registered invoices by providing the IRN and a reason code. |
| FR-INV-04 | Invoice Verification | Users can verify invoice status by querying the MoR using an IRN. |
| FR-INV-05 | Invoice History | Users view a paginated list of previously registered invoices with date range filtering. |
| FR-INV-06 | Offline Queuing | If a network error occurs during registration, the invoice is saved locally and automatically retried when connectivity is restored. |
| FR-INV-07 | Document Number Auto-Correction | If the MoR returns HTTP 406 with an expected document number, the app auto-retries with the corrected value (max 1 retry). |

### 4.3 Receipt Management

| ID | Requirement | Description |
|---|---|---|
| FR-REC-01 | Sales Receipt Registration | After successful invoice registration, a sales receipt is automatically generated and submitted to the MoR. |
| FR-REC-02 | Withholding Receipt | Users can submit withholding receipts with buyer TIN, invoice details, and withholding amounts. |
| FR-REC-03 | Receipt Retrieval | Receipts can be retrieved by RRN, MOR ID, or IRN. |

### 4.4 Product/Supply Catalog

| ID | Requirement | Description |
|---|---|---|
| FR-SUP-01 | View Supplies | Users view a list of saved product items with descriptions, prices, and tax codes. |
| FR-SUP-02 | Create Supply | Users add new products to the catalog with item code, description, unit price, tax code, and excise details. |
| FR-SUP-03 | Update Supply | Users edit existing product details. |
| FR-SUP-04 | Delete Supply | Users remove products from the catalog. |
| FR-SUP-05 | Quick Add from Invoice | Users can save invoice line items directly to the product catalog. |

### 4.5 PDF Generation

| ID | Requirement | Description |
|---|---|---|
| FR-PDF-01 | Invoice PDF | System generates a styled PDF invoice including seller/buyer details, line items, tax breakdown, and signed QR code. |
| FR-PDF-02 | Receipt PDF | System generates a styled PDF receipt with payment details. |
| FR-PDF-03 | Combined PDF | After invoice + receipt registration, a combined PDF document is generated and presented for preview/sharing. |

---

## 5. User Journeys

### 5.1 First-Time Setup
1. Owner opens the app → redirected to Company Auth screen.
2. Owner registers a new company (name, TIN, phone, email, password).
3. System creates the company and returns a JWT → owner is navigated to Branch Setup.
4. Owner creates a branch by entering branch details and uploading MoR private key and certificate files.
5. Branch is created → owner can now log in as a branch operator.

### 5.2 Daily Operations (Cashier)
1. Cashier opens the app → Login with branch TIN and password.
2. System authenticates branch → performs MoR login automatically.
3. Cashier navigates to the "Register" tab.
4. Cashier enters buyer name/TIN, adds line items (or selects from product catalog).
5. Cashier selects payment mode and document type, then taps "Register Invoice."
6. System submits the invoice to the backend → backend signs and forwards to MoR.
7. MoR returns IRN and signed QR → receipt is auto-registered.
8. Combined PDF preview is shown → cashier can print or share.

### 5.3 Offline Scenario
1. Cashier attempts to register an invoice while offline.
2. System detects network failure → invoice is saved to the offline queue.
3. Cashier is notified that the invoice will be submitted when connectivity restores.
4. When Wi-Fi/mobile data reconnects, the `OfflineQueueService` automatically submits queued invoices.

---

## 6. Acceptance Criteria

| ID | Criteria | Expected Outcome |
|---|---|---|
| AC-01 | Company registration with valid inputs | Company created, JWT returned, user navigated to Branch Setup. |
| AC-02 | Branch login with valid TIN/password | Branch JWT issued, MoR login performed automatically, user navigated to Dashboard. |
| AC-03 | Invoice registration with valid items | MoR returns IRN and signed QR code, invoice saved to history, receipt auto-registered. |
| AC-04 | Invoice registration while offline | Invoice queued locally, synced when network is restored. |
| AC-05 | Token expiry during operation | MoR token refreshed automatically, original request retried. |
| AC-06 | Invoice cancellation with valid IRN | MoR acknowledges cancellation, audit record created. |
| AC-07 | PDF generation after registration | Combined invoice + receipt PDF displayed for preview/sharing. |

---

## 7. Non-Functional Requirements

### 7.1 Performance Requirements
| Requirement | Target |
|---|---|
| App cold start time | < 3 seconds on mid-range Android devices |
| Invoice submission latency | < 10 seconds (network dependent, with 60s connect timeout and 120s receive timeout) |
| Offline queue sync | Automatic within 5 seconds of network restoration |
| PDF generation time | < 2 seconds for combined invoice + receipt |
| Minimum supported Android version | Android 5.0 (API 21) |

### 7.2 Security Requirements
| Requirement | Description |
|---|---|
| Token Storage | JWT tokens and MoR credentials stored via `flutter_secure_storage` (AES-256 encrypted on Android Keystore / iOS Keychain). |
| TLS Communication | All API calls over HTTPS (TLS 1.2+) to `https://api.deresegn.com`. |
| Digital Signing | Invoice payloads signed with branch-specific RSA private keys using SHA-512 before submission to MoR. |
| Certificate Validation | Branch certificates uploaded during setup, stored with restricted permissions (0600). |
| Password Hashing | Passwords hashed using bcrypt on the backend. |
| Credential Encryption | `client_secret` and `api_key` encrypted at rest in the database using Laravel's `encrypted` cast. |
| Audit Logging | All MoR interactions (login, registration, cancellation) audited with request/response payloads (sensitive data masked). |
| Session Management | Automatic session expiry detection with redirect to login. |

---

## 8. User Personas

### 8.1 Selam — Small Business Owner
- **Demographics:** 35-year-old owner of a small retail shop in Addis Ababa.
- **Tech Comfort:** Moderate; uses smartphone daily for messaging and social media.
- **Goal:** Easily register sales invoices compliant with MoR regulations without manual paperwork.
- **Pain Points:** Limited internet connectivity, unfamiliar with tax compliance software.

### 8.2 Kidus — Branch Cashier
- **Demographics:** 24-year-old cashier at a multi-branch retail chain.
- **Tech Comfort:** High; uses POS systems regularly.
- **Goal:** Quickly generate invoices during busy sales periods with minimal steps.
- **Pain Points:** Needs offline capability for areas with unreliable connectivity.

---

## 9. Workflow Diagrams

### 9.1 Invoice Registration Flow
```
[Cashier] → Enter Buyer Details → Add Line Items → Select Payment Mode
    → Tap "Register Invoice"
    → [Mobile App] → Build Invoice Payload → POST /api/invoice/register
    → [Backend API] → Sign Payload (SHA-512) → Attach Certificate
    → POST to MoR Gateway
    → [MoR] → Validate → Return IRN + Signed QR
    → [Backend] → Save Invoice + Audit → Return Response
    → [Mobile App] → Auto-register Receipt → Generate PDF → Preview
```

### 9.2 Authentication Flow
```
[User] → Enter Branch TIN + Password
    → [Mobile App] → POST /api/branch/login
    → [Backend] → Validate → Issue Branch JWT
    → [Mobile App] → Store Branch Token → POST /api/login (MoR credentials)
    → [Backend] → Load Branch cert/key → Sign MoR login payload
    → Forward to MoR Login URL
    → [MoR] → Return accessToken + refreshToken
    → [Backend] → Return tokens
    → [Mobile App] → Store MoR Tokens → Navigate to Dashboard
```
