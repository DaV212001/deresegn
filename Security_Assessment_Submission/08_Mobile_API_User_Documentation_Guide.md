# Deresegn POS — Mobile API User Documentation (API Guide)

**Document Version:** 1.0  
**Application Version:** 1.0.3+4  
**Date:** August 5, 2026  
**Classification:** Confidential  
**Prepared by:** Micro Sun & Solution PLC  

---

## 1. Introduction & API Overview

### 1.1 Purpose
This document serves as the official API User Documentation (API Guide) for the Deresegn POS platform. It specifies how mobile client applications and external API consumers interact with the Deresegn Backend API (`https://api.deresegn.com`).

The API acts as a secure, authenticated gateway and fiscal proxy between the mobile application and the Ethiopian Ministry of Revenues (MoR) e-invoicing platform.

### 1.2 Regulatory & Technical Specification References
The API endpoints, encryption parameters, payload schemas, and fiscal verification workflows documented herein are built in strict compliance with the non-public technical specifications issued directly by the Ministry of Revenues (MoR) to registered e-invoicing solution providers:

- **Reference Standard:** Ministry of Revenues (MoR) Electronic Invoicing System Integration & API Specification
- **Issuing Authority:** Ministry of Revenues, Federal Democratic Republic of Ethiopia
- **Classification:** Restricted / Vendor Provisioned (Confidential)
- **Compliance Status:** Fully compliant with MoR RSA-SHA512 digital signature, e-Invoice IRN schema, sales receipt, and withholding tax registration protocols.
- **Attachment:** Copies of the official MoR Specification documents are available upon request and included under the `/References` folder in the vendor submission archive.

### 1.3 Base URL & Environment
- **Production Base URL:** `https://api.deresegn.com`
- **Protocol:** HTTPS (TLS 1.2+ mandatory)
- **Data Format:** `application/json` (except certificate/key upload endpoints which use `multipart/form-data`)

### 1.4 Common HTTP Headers

| Header Name | Requirement | Description |
|---|---|---|
| `Content-Type` | Mandatory | `application/json` |
| `Accept` | Mandatory | `application/json` |
| `Authorization` | Conditional | `Bearer <JWT_TOKEN>` (Company or Branch token) |
| `Branch-Id` | Conditional | Numeric ID of the authenticated branch |
| `Mor-Token` | Conditional | `Bearer <MOR_ACCESS_TOKEN>` for MoR passthrough routes |

---

## 2. Authentication & Authorization Flow

The API utilizes a dual-tier JWT authentication model:
1. **Company Owner Auth:** Access company setup and branch creation endpoints.
2. **Branch Auth:** Access daily point-of-sale operational endpoints (invoicing, receipts, catalog).

```
[Mobile App] --(1. Branch Login)--> [Backend API] (Returns Branch JWT)
[Mobile App] --(2. MoR Login with Branch JWT)--> [Backend API] (Signs RSA & calls MoR) --> (Returns MoR Access Token)
[Mobile App] --(3. Invoicing / Receipts with Branch JWT + Mor-Token)--> [Backend API] --> [MoR Gateway]
```

---

## 3. API Endpoints & Complete Payload Specifications

### 3.1 Authentication Endpoints

#### 3.1.1 Company Owner Registration
- **Endpoint:** `POST /api/company/register`
- **Auth:** Public
- **Request Body:**
```json
{
  "name": "Acme Trading PLC",
  "tin": "0000037187",
  "phone": "+251911058179",
  "email": "owner@acmetrading.et",
  "password": "SecurePassword123!"
}
```
- **Response (201 Created):**
```json
{
  "status": "success",
  "message": "Company registered successfully",
  "access_token": "eyJhbGciOiJIUzI1Ni...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

#### 3.1.2 Company Owner Login
- **Endpoint:** `POST /api/company/login`
- **Auth:** Public
- **Request Body:**
```json
{
  "phone": "+251911058179",
  "password": "SecurePassword123!",
  "company_id": 1
}
```

#### 3.1.3 Branch Operator Login
- **Endpoint:** `POST /api/branch/login`
- **Auth:** Public
- **Request Body:**
```json
{
  "tin": "0000037187",
  "password": "BranchPassword123"
}
```

---

### 3.2 Fiscal Invoice Registration (`POST /api/invoice/register`)

> **Regulatory MoR Specification Reference:**  
> The `InvoiceRegisterRequest` JSON payload schema below strictly adheres to the restricted, non-public **Ministry of Revenues (MoR) e-Invoicing Technical Specification** provided to registered vendors. All 10 root nodes (`DocumentDetails`, `TransactionType`, `SourceSystem`, `SellerDetails`, `BuyerDetails`, `ItemList`, `ValueDetails`, `PaymentDetails`, `ReferenceDetails`, `Version`) match the exact structure and field names mandated by the MoR e-invoicing gateway.

- **Endpoint:** `POST /api/invoice/register`
- **Auth:** Required (`Authorization: Bearer <Branch_JWT>`, `Branch-Id: <id>`, `Mor-Token: Bearer <MoR_Token>`)
- **Full Production Request Payload:**

```json
{
  "DocumentDetails": {
    "DocumentNumber": "10042",
    "Type": "INV",
    "Reason": "Sales Invoice",
    "Date": "05-08-2026T14:00:00"
  },
  "TransactionType": "B2C",
  "SourceSystem": {
    "SystemType": "POS",
    "CashierName": "Kidist A.",
    "SystemNumber": "POS-01",
    "InvoiceCounter": 10042,
    "SalesPersonName": "Kidist A."
  },
  "SellerDetails": {
    "Tin": "0000037187",
    "LegalName": "Micro Sun & Solution PLC",
    "City": "Addis Ababa",
    "Wereda": "13",
    "Region": "1",
    "Email": "amanuielt@mssethiopia.com",
    "Phone": "+251911058179",
    "Country": "1",
    "TradeName": "Deresegn POS",
    "VatNumber": "VAT-0000037187"
  },
  "BuyerDetails": {
    "LegalName": "Selamawit Bekele",
    "IdType": "KID",
    "HouseNumber": "",
    "IdNumber": "",
    "Tin": "0011223344",
    "Email": "",
    "Phone": "",
    "City": "Addis Ababa",
    "Region": "",
    "Country": "",
    "Kebele": "",
    "Wereda": "",
    "VatNumber": ""
  },
  "ItemList": [
    {
      "LineNumber": 1,
      "NatureOfSupplies": "goods",
      "UnitPrice": "150.00",
      "TotalLineAmount": "172.50",
      "PreTaxValue": "150.00",
      "Unit": "PCS",
      "TaxCode": "VAT15",
      "TaxAmount": "22.50",
      "Quantity": "1.00",
      "Discount": "0.00",
      "ExciseTaxValue": "0.00",
      "ProductDescription": "Wireless Optical Mouse",
      "ItemCode": "ITEM-1"
    }
  ],
  "ValueDetails": {
    "TotalValue": "172.50",
    "TaxValue": "22.50",
    "Discount": "0.00",
    "ExciseValue": "0.00",
    "InvoiceCurrency": "ETB",
    "IncomeWithholdValue": "0.00",
    "TransactionWithholdValue": "0.00"
  },
  "PaymentDetails": {
    "PaymentTerm": "CASH",
    "Mode": "CASH"
  },
  "ReferenceDetails": {
    "RelatedDocument": null,
    "PreviousIrn": "null"
  },
  "Version": "1"
}
```

- **Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "irn": "IRN-2026-0805-00142",
    "documentNumber": "10042",
    "signedQrCode": "https://mor.gov.et/verify/qr?data=...",
    "registrationTime": "2026-08-05T14:00:00Z"
  }
}
```

#### 3.2.1 Cancel Fiscal Invoice (`POST /api/cancel/invoice`)
- **Endpoint:** `POST /api/cancel/invoice`
- **Auth:** Required (`Authorization: Bearer <Branch_JWT>`)
- **Full Payload:**
```json
{
  "Irn": "IRN-2026-0805-00142",
  "ReasonCode": "CUSTOMER_CANCEL"
}
```

#### 3.2.2 Verify Fiscal Invoice (`POST /api/irn/verfiy`)
- **Endpoint:** `POST /api/irn/verfiy`
- **Auth:** Required (`Authorization: Bearer <Branch_JWT>`)
- **Full Payload:**
```json
{
  "Irn": "IRN-2026-0805-00142"
}
```

---

### 3.3 Sales Receipt Registration (`POST /api/receipt/sales`)

> **Regulatory MoR Specification Reference:**  
> The `ReceiptRegisterRequest` JSON payload schema below strictly adheres to the non-public **Ministry of Revenues (MoR) Sales Receipt Registration Specification**. Key structures including `Invoices` array mapping to IRN and `TransactionDetails` conform to official fiscal collection compliance.

- **Endpoint:** `POST /api/receipt/sales`
- **Auth:** Required (`Authorization: Bearer <Branch_JWT>`, `Mor-Token: Bearer <MoR_Token>`)
- **Full Production Request Payload:**

```json
{
  "ReceiptNumber": "1785927533938",
  "ReceiptType": "Sales Receipts",
  "Reason": "Payment for goods purchased",
  "ReceiptDate": "2026-08-05T14:00:00.000Z",
  "ReceiptCounter": "1",
  "ManualReceiptNumber": null,
  "SourceSystemType": "POS",
  "SourceSystemNumber": "POS-01",
  "ReceiptCurrency": "ETB",
  "ExchangeRate": null,
  "CollectedAmount": "172.50",
  "SellerTIN": "0000037187",
  "Invoices": [
    {
      "InvoiceIRN": "IRN-2026-0805-00142",
      "PaymentCoverage": "FULL",
      "InvoicePaidAmount": "172.50",
      "TotalAmount": "172.50"
    }
  ],
  "TransactionDetails": {
    "ModeOfPayment": "CASH",
    "DocumentNumber": 10042,
    "CollectorName": "Kidist A.",
    "TransactionNumber": "TXN-998877",
    "PaymentServiceProvider": "Telebirr"
  }
}
```

- **Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "id": 842,
    "mor_id": "MOR-REC-99120",
    "status": "REGISTERED",
    "rrn": "RRN-2026-0805-99881",
    "invoice_irn": "IRN-2026-0805-00142",
    "receipt_number": "1785927533938",
    "qr": "https://mor.gov.et/receipt/qr?data=...",
    "is_success": true
  }
}
```

---

### 3.4 Withholding Receipt Registration (`POST /api/receipt/withholding`)

> **Regulatory MoR Specification Reference:**  
> The `WithholdingReceiptRequest` JSON payload schema below strictly complies with the non-public **Ministry of Revenues (MoR) Transaction Withholding Tax (TWHT) Specification**, embedding `InvoiceDetail` and `WithholdDetail` nodes.

- **Endpoint:** `POST /api/receipt/withholding`
- **Auth:** Required (`Authorization: Bearer <Branch_JWT>`, `Mor-Token: Bearer <MoR_Token>`)
- **Full Production Request Payload:**

```json
{
  "ReceiptNumber": "WHT-1785927533938",
  "Reason": "Withhold for goods purchased",
  "ReceiptCounter": "1",
  "ManualReceiptNumber": "92753",
  "SourceSystemType": "POS",
  "SourceSystemNumber": "POS-01",
  "BuyerTIN": "0011223344",
  "InvoiceDetail": {
    "InvoiceIRN": "IRN-2026-0805-00142",
    "Currency": "ETB"
  },
  "WithholdDetail": {
    "Type": "TWHT",
    "PreTaxAmount": 150.00,
    "WithholdingAmount": 3.00
  }
}
```

- **Response (200 OK):**
```json
{
  "status": "success",
  "message": "Withholding receipt registered successfully"
}
```

---

### 3.5 Supply / Product Catalog Management (`/api/supplies`)

- **Add Supply (`POST /api/supplies`):**
```json
{
  "item_code": "ITEM-101",
  "product_description": "Barcoded Scanner Unit",
  "nature_of_supplies": "goods",
  "unit_price": 2500.00,
  "unit": "PCS",
  "tax_code": "VAT15",
  "discount": 0.00,
  "excise_tax_rate": 0.00,
  "is_excise_taxable": false
}
```

---

## 4. Error Handling & HTTP Status Codes

### 4.1 Status Code Index

| Code | Description | Handling Recommendation |
|---|---|---|
| `200 OK` | Success | Process returned payload |
| `201 Created` | Resource created | Store newly created resource data |
| `400 Bad Request` | Invalid payload or missing parameters | Check request body format |
| `401 Unauthorized` | Expired/invalid JWT or MoR token | If MoR error: refresh token; if Branch error: redirect to login |
| `403 Forbidden` | Access denied for requested branch | Verify branch ownership |
| `406 Not Acceptable` | Document number mismatch | Auto-retry with expected document number returned by MoR |
| `422 Unprocessable` | Validation rules failed | Display error messages to user |
| `500 Server Error` | Backend or MoR Gateway error | Queue request locally (if offline-capable) and retry |

---

## 5. Document Number Auto-Correction (406 Protocol)

When registering invoices, if out-of-sync document sequence numbers occur:
1. MoR Gateway returns `HTTP 406 Not Acceptable` with payload containing `expectedDocumentNumber`.
2. Mobile API Client intercepts response.
3. Client automatically updates payload with `expectedDocumentNumber` and retries submission (max 1 retry attempt).
