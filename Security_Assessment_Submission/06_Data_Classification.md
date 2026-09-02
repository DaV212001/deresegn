# Deresegn POS — Data Classification

**Document Version:** 1.0  
**Application Version:** 1.0.3+4  
**Date:** August 5, 2026  
**Classification:** Confidential  
**Prepared by:** Micro Sun & Solution PLC  

---

## 1. Types of Data Handled

### 1.1 Personal Data

| Data Element | Location | Collected From | Example |
|---|---|---|---|
| Owner Name | Backend DB (company_users) | Company Registration | "Amanuel Teferi" |
| Phone Number | Backend DB (company_users, company_branches) | Registration/Login | "+251947990585" |
| Email Address | Backend DB (companies, company_branches) | Registration | "amanuielt@mssmea.com" |
| Buyer Name | Backend DB (mor_invoices), Mobile App (invoice form) | Invoice creation | "Abebe Kebede" |
| Buyer Phone | Backend DB (mor_invoices) | Invoice creation | "+251911234567" |
| Buyer Email | Backend DB (mor_invoices) | Invoice creation | "buyer@example.com" |

### 1.2 Financial Data

| Data Element | Location | Description | Example |
|---|---|---|---|
| Invoice Amounts | Backend DB (mor_invoices), Mobile App | Transaction totals, tax amounts, discounts | 5750.00 ETB |
| Receipt Amounts | Backend DB (mor_receipts), Mobile App | Payment amounts collected | 5750.00 ETB |
| Tax Information | Backend DB, Mobile App | VAT, TOT, Excise values | VAT 15%: 750.00 |
| TIN Numbers | Backend DB, Mobile App (secure storage) | Tax Identification Numbers | "0000037187" |
| VAT Registration Numbers | Mobile App (settings) | Seller VAT number | "VAT-12345" |

### 1.3 Authentication / Session Data

| Data Element | Location | Description | Sensitivity |
|---|---|---|---|
| Passwords (hashed) | Backend DB (company_users, company_branches) | Bcrypt-hashed passwords | High |
| JWT Tokens (Branch) | Mobile App (flutter_secure_storage) | Branch authentication tokens | High |
| JWT Tokens (Company) | Mobile App (flutter_secure_storage) | Company owner tokens | High |
| MoR Access Token | Mobile App (flutter_secure_storage) | Ministry of Revenues API token | High |
| MoR Refresh Token | Mobile App (flutter_secure_storage) | Token refresh credential | High |
| MoR Client ID | Mobile App (flutter_secure_storage), Backend DB (company_branches) | API credential | High |
| MoR Client Secret | Mobile App (flutter_secure_storage), Backend DB (encrypted) | API credential | Critical |
| MoR API Key | Mobile App (flutter_secure_storage), Backend DB (encrypted) | API credential | Critical |
| Private Keys (.key files) | Backend filesystem (storage/app/) | RSA private keys for payload signing | Critical |
| Certificates (.pem files) | Backend filesystem (storage/app/) | X.509 certificates | High |
| HTTP Cookies | Mobile App (file system) | Session cookies | Medium |

### 1.4 Business Data

| Data Element | Location | Description |
|---|---|---|
| Company Names | Backend DB | Legal business names |
| Branch Names / Locations | Backend DB | Branch identifiers and addresses |
| Product Catalog | Backend DB (supplies) | Item codes, descriptions, prices, tax codes |
| Invoice Payloads | Backend DB (mor_invoices, mor_invoice_audits) | Full request/response data |
| Signed QR Codes | Backend DB (mor_invoices) | MoR-generated signed QR data |
| IRN Numbers | Backend DB (mor_invoices) | Invoice Reference Numbers |

---

## 2. Sensitivity Levels

| Data Category | Sensitivity Level | Justification |
|---|---|---|
| MoR Private Keys & Certificates | **Critical** | Compromise allows forging of fiscal documents |
| MoR Client Secret & API Key | **Critical** | Enables unauthorized API access to government systems |
| Passwords (hashed) | **High** | Authentication credentials |
| JWT Tokens | **High** | Active session tokens |
| MoR Access/Refresh Tokens | **High** | Active government API session |
| TIN Numbers | **High** | Tax identification — regulated PII |
| Personal Names, Phones, Emails | **Medium** | Standard personally identifiable information |
| Financial Amounts & Tax Data | **Medium** | Business-sensitive financial information |
| Invoice Payloads & Audit Logs | **Medium** | Contain mixed personal and financial data |
| Product Catalog Data | **Low** | Non-sensitive business data |
| Theme Preferences | **Low** | User preference, no security impact |
| Company/Branch Names | **Low** | Publicly associated with TINs |

---

## 3. Applicable Regulations

| Regulation / Standard | Applicability | Description |
|---|---|---|
| Ethiopian Revenue Proclamation | **Mandatory** | Governs e-invoicing compliance, fiscal document integrity, and digital signature requirements |
| Ethiopian Data Protection Proclamation (1249/2021) | **Applicable** | Governs collection, processing, and storage of personal data |
| Information Network Security Agency (INSA) Guidelines | **Applicable** | Cybersecurity standards for information systems operating in Ethiopia |
| PCI DSS | **Not Applicable** | No direct credit card processing or storage |
| GDPR | **Not Directly Applicable** | No EU citizen data processing (may apply if EU buyers are served) |

---

## 4. Data Storage Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                        MOBILE DEVICE                           │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │  flutter_secure_storage (ENCRYPTED)  │                     │
│  │  ──────────────────────────────────  │                     │
│  │  • JWT Tokens (Branch, Company)      │  ← AES-256         │
│  │  • MoR Tokens (Access, Refresh)      │    Android Keystore │
│  │  • MoR Credentials (ID, Secret, Key) │    iOS Keychain     │
│  │  • TIN Number                        │                     │
│  │  • Branch/Company IDs                │                     │
│  └──────────────────────────────────────┘                     │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │  shared_preferences (UNENCRYPTED)    │                     │
│  │  ──────────────────────────────────  │                     │
│  │  • Offline Invoice Queue (JSON)      │  ← Contains buyer  │
│  │                                      │    names, amounts   │
│  └──────────────────────────────────────┘                     │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │  File System (UNENCRYPTED)           │                     │
│  │  ──────────────────────────────────  │                     │
│  │  • HTTP Cookies (.cookies/)          │                     │
│  └──────────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND SERVER                             │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │  MySQL Database (yegna_erp)          │                     │
│  │  ──────────────────────────────────  │                     │
│  │  • Companies (names, TINs, emails)   │                     │
│  │  • Users (names, phones, passwords)  │  ← bcrypt hashed   │
│  │  • Branches (credentials, status)    │  ← secret/key       │
│  │  •    client_secret → encrypted cast │    encrypted (AES)  │
│  │  •    api_key → encrypted cast       │                     │
│  │  • Invoices (full payloads, QR)      │                     │
│  │  • Receipts (payment data)           │                     │
│  │  • Audit Logs (masked responses)     │                     │
│  │  • Supplies (product catalog)        │                     │
│  └──────────────────────────────────────┘                     │
│                                                                │
│  ┌──────────────────────────────────────┐                     │
│  │  File System (storage/app/)          │                     │
│  │  ──────────────────────────────────  │                     │
│  │  mor-credentials/                    │                     │
│  │    {company_id}/{branch_slug}/       │                     │
│  │      • private_key.key (0600)        │  ← RSA Private Key │
│  │      • certificate.pem (0600)        │  ← X.509 Cert      │
│  └──────────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Data Retention

| Data Type | Retention Policy |
|---|---|
| Invoices & Receipts | Retained indefinitely (regulatory requirement) |
| Audit Logs | Retained indefinitely |
| JWT Tokens | Cleared on logout or session expiry |
| MoR Tokens | Cleared on logout or refresh failure |
| Offline Queue | Cleared after successful sync |
| Product Catalog | Retained until explicitly deleted by user |
