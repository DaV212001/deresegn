# Deresegn POS — User Guide

**Document Version:** 1.0  
**Application Version:** 1.0.3+4  
**Date:** August 5, 2026  
**Classification:** Confidential  
**Prepared by:** Micro Sun & Solution PLC  

---

## 1. Application Overview

Deresegn POS is a mobile Point of Sale application designed for Ethiopian businesses. It enables merchants to create fiscal invoices, register them with the Ethiopian Ministry of Revenues (MoR) e-invoicing system, generate sales receipts, and maintain a product catalog — all from a smartphone.

### Key Capabilities
- **Invoice Registration:** Create and submit compliant invoices to the MoR.
- **Receipt Management:** Automatically generate sales and withholding receipts.
- **Offline Mode:** Create invoices without internet; they sync automatically when connectivity returns.
- **Product Catalog:** Save frequently used items for quick invoicing.
- **PDF Export:** Generate and share professional PDF invoices and receipts.
- **Multi-Language:** Switch between English and Amharic.
- **Dark/Light Theme:** Choose your preferred visual mode.

---

## 2. Basic Usage Instructions

### 2.1 Getting Started

#### Prerequisites
- Android 5.0+ or iOS device
- Internet connection for initial setup
- Company owner account credentials (for first-time setup)
- MoR-issued private key and certificate files (for branch registration)

#### First Launch
1. Install the Deresegn POS APK on your Android device (or IPA on iOS).
2. Open the app — you will be directed to the **Company Authentication** screen.

### 2.2 Company Registration (Owner Only)
1. On the Company Auth screen, tap **"Register"**.
2. Fill in:
   - **Company Name** — Your business legal name
   - **TIN Number** — Tax Identification Number
   - **Owner Name** — Full name of the company owner
   - **Phone** — Phone number for the owner account
   - **Email** — Business email
   - **Website** — Company website (optional)
   - **Password** — Secure password (minimum 6 characters)
3. Tap **"Register Company"**.
4. On success, you'll be navigated to the **Branch Setup** screen.

### 2.3 Company Login (Owner Only)
1. On the Company Auth screen, tap **"Login"**.
2. Select your company from the dropdown list.
3. Enter your phone number and password.
4. Tap **"Login"**.
5. On success, you'll be navigated to the **Branch Setup** screen.

### 2.4 Branch Setup (Owner Only)
1. On the Branch Setup screen, fill in:
   - **Branch Name** — A unique name for this branch location
   - **Location** — Physical address
   - **Phone Number** — Branch contact number
   - **Email** — Branch email
   - **TIN Number** — Branch TIN (may be the same as the company TIN)
   - **Client ID** — MoR-issued client identifier
   - **Client Secret** — MoR-issued client secret
   - **API Key** — MoR-issued API key
   - **Password** — Branch login password (minimum 6 characters)
2. Upload the **Private Key** file (`.key` format) — tap the file picker button.
3. Upload the **Certificate** file (`.pem` format) — tap the file picker button.
4. Tap **"Create Branch"**.
5. On success, the branch is created and can now be used for daily operations.

### 2.5 Branch Login (Daily Operation)
1. Open the app.
2. Enter your **TIN Number** and **Branch Password**.
3. Tap **"Login"**.
4. The app will automatically authenticate with the MoR system.
5. On success, you'll be navigated to the **Dashboard**.

---

## 3. Key Feature Explanations

### 3.1 Dashboard
The main screen has four tabs accessible via the bottom navigation bar:

| Tab | Icon | Purpose |
|---|---|---|
| **Register** | ➕ | Create and submit new invoices |
| **History** | 📋 | View past registered invoices |
| **Products** | 📦 | Manage your product/supply catalog |
| **Settings** | ⚙️ | Configure app preferences |

### 3.2 Invoice Registration (Register Tab)
This is the primary screen for creating and submitting invoices.

#### Invoice Header
- **Buyer Name** (required) — Name of the buyer/customer
- **Buyer TIN** (optional) — Buyer's tax identification number
- **Transaction Type** — B2B (Business-to-Business) or B2C (Business-to-Consumer)
- **Document Type** — Cash Sale, Credit Sale, Credit Note, or Debit Note
- **Payment Mode** — CASH, CARD, TRANSFER, CHECK, or CREDIT
- **Currency** — ETB (default) or foreign currency with exchange rate

#### Adding Line Items
1. Tap the **"Add Item"** button.
2. Fill in:
   - **Description** — Item name/description
   - **Unit Price** — Price per unit
   - **Quantity** — Number of units
   - **Tax Category** — VAT 15%, TOT 2%, TOT 10%, Exempt, or Zero Rated
   - **Discount** — Discount amount (optional)
   - **Excise Tax** — If applicable, enable and set rate
   - **Item Code** — Product code (optional)
   - **Unit** — PCS, KG, LTR, etc.
3. Alternatively, select an item from your **Product Catalog** to auto-fill details.

#### Invoice Summary
The bottom of the screen shows:
- **Subtotal** — Sum of all line items before tax
- **Total Discount** — Sum of all discounts
- **Excise Tax** — Sum of all excise amounts
- **VAT** — Sum of all VAT amounts
- **Grand Total** — Final invoice amount

#### Submitting the Invoice
1. Review all details.
2. Tap **"Register Invoice"**.
3. The app submits the invoice to the MoR system.
4. On success:
   - A sales receipt is automatically generated.
   - A combined PDF (invoice + receipt) is displayed for preview.
   - You can share or print the PDF.

### 3.3 Invoice History (History Tab)
- View a paginated list of all registered invoices.
- Each entry shows: document number, buyer name, total amount, status, and date.
- **Filter by date range** using the date picker controls.
- **Tap an invoice** to view full details including:
  - Seller and buyer information
  - Line item breakdown
  - Tax summary
  - MoR-assigned IRN
  - QR code
- From the detail view, you can:
  - **Generate PDF** — Create and preview the invoice PDF
  - **Cancel Invoice** — Submit a cancellation request to the MoR
  - **Register Receipt** — Manually register a sales or withholding receipt

### 3.4 Product Catalog (Products Tab)
Manage your frequently used items:
- **View Products** — See all saved products with descriptions, prices, and tax codes.
- **Add Product** — Tap the ➕ button to add a new product.
- **Edit Product** — Tap an existing product to modify its details.
- **Delete Product** — Swipe or tap to remove a product.
- **Quick Add from Invoice** — When creating an invoice, you can save a line item directly to the catalog.

### 3.5 Settings (Settings Tab)
Configure application preferences:
- **Cashier Name** — Name displayed on invoices
- **System Number** — POS system identifier
- **Trade Name** — Business trade name
- **VAT Number** — VAT registration number
- **Default City** — City for address fields
- **Theme** — Toggle between Light and Dark mode
- **Language** — Switch between English (🇺🇸) and Amharic (🇪🇹)
- **Logout** — Sign out and return to the login screen

---

## 4. Step-by-Step User Flows

### 4.1 Creating a Cash Sale Invoice
1. Navigate to the **Register** tab.
2. Set **Document Type** to "Cash Sale".
3. Set **Transaction Type** (B2B or B2C).
4. Enter the **Buyer Name** (e.g., "Abebe Kebede").
5. Optionally enter the **Buyer TIN**.
6. Tap **"Add Item"**.
7. Enter item description: "Office Chair", Unit Price: 2500.00, Quantity: 2.
8. Select **Tax Category**: VAT 15%.
9. Confirm the item.
10. Review the summary: Subtotal 5000.00, VAT 750.00, Total 5750.00.
11. Tap **"Register Invoice"**.
12. Wait for MoR confirmation.
13. Preview the combined PDF.
14. Share or print as needed.

### 4.2 Creating a Credit Note
1. Navigate to the **Register** tab.
2. Set **Document Type** to "Credit Note".
3. Enter the **Reference IRN** of the original invoice being corrected.
4. Enter an **Adjustment Reason** (e.g., "Item returned by customer").
5. Add the corrected line items.
6. Tap **"Register Invoice"**.

### 4.3 Working Offline
1. When you have no internet connection, create an invoice as normal.
2. Tap **"Register Invoice"**.
3. A message will appear: "The invoice has been saved offline and will be registered automatically when connection is restored."
4. Continue creating more invoices if needed.
5. When internet is restored, invoices will automatically sync in the background.
6. You can verify by checking the **History** tab.

### 4.4 Cancelling an Invoice
1. Navigate to the **History** tab.
2. Tap on the invoice you wish to cancel.
3. In the detail view, tap **"Cancel Invoice"**.
4. Enter a **Reason Code** for the cancellation.
5. Confirm the cancellation.
6. The invoice status will be updated.

---

## 5. Troubleshooting Guide

### Common Issues

| Issue | Possible Cause | Solution |
|---|---|---|
| "Connection timeout" error | Slow or no internet connection | Check Wi-Fi/mobile data and retry. |
| "Session expired" redirect | JWT token has expired | Log in again with your branch credentials. |
| "MoR Login Failed" | Invalid MoR credentials | Verify client ID, secret, API key, and TIN. Contact admin to re-provision. |
| Invoice registration fails with 406 | Document number out of sequence | The app auto-retries with the correct number. If persistent, contact support. |
| "Bad certificate" error | Certificate mismatch or corruption | Re-upload the MoR certificate during branch setup. |
| Offline invoices not syncing | Connectivity not detected | Restart the app while connected to trigger sync. |
| PDF generation fails | Font loading error | Ensure the app is updated to the latest version. |
| Login screen keeps appearing | Tokens cleared or expired | Log in again. If persistent, clear app data and re-setup. |

---

## 6. FAQs

**Q: Can multiple branches share the same TIN?**  
A: Yes. Branches under the same company can share a TIN. Each branch maintains its own credentials and certificates.

**Q: What happens if I lose internet during invoice submission?**  
A: The invoice is automatically saved offline and will be submitted when connectivity is restored.

**Q: Can I edit an invoice after submission?**  
A: No. Once registered with the MoR, invoices cannot be edited. You can issue a Credit Note to make corrections.

**Q: How do I switch languages?**  
A: Go to Settings → Language and select English or Amharic.

**Q: What currencies are supported?**  
A: ETB (Ethiopian Birr) is the default. Foreign currencies can be selected with an exchange rate.

**Q: How is my data protected?**  
A: All credentials are stored in encrypted device storage (Android Keystore / iOS Keychain). All network communication uses HTTPS encryption.

---

## 7. Contact Information

**Developer:** Micro Sun & Solution PLC  
**Email:** amanuielt@mssethiopia.com  
**Phone:** +251 911 058 179 
**Application:** Deresegn POS v1.0.3+4
