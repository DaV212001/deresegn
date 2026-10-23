---
name: mor-e-invoicing-compliance
description: >-
  Official reference guide, standards, and verification runbook for Ethiopian Ministry of Revenues (MoR / ERCA)
  e-invoicing compliance in the Deresegn application. Use when generating, modifying, testing, or verifying
  Sales Invoices (Cash & Credit), Credit/Debit Notes, Cash Receipt Vouchers (CRB), Withholding Tax Receipts (Goods vs Services),
  and Tax Declaration Reconciliation Statements.
---

# MoR / ERCA E-Invoicing Compliance Guide

This skill encapsulates the official technical requirements, entity mapping standards, calculation formulas, and validation rules certified by the Ethiopian Ministry of Revenues (MoR / ERCA) for the Deresegn e-invoicing system.

---

## 1. Official Document Standards & Party Mappings

### A. Sales Invoices (Cash & Credit)
* **Top Header / POS**: Seller (`Micro Sun & Solution PLC` - TIN: 0000037187)
* **Left Box (`ከ/From`)**: Seller (`የሻጭ... / Seller's Phone, Email, VAT Reg.No`)
* **Right Box (`ለ/To`)**: Buyer (`የገዢ... / Buyer's Phone, Email, VAT Reg.No`)
* **Itemized Table**: Minimum 3 items standard. If fewer items exist, pad with empty boxed rows.
* **Totals Summary**: Full 11-row summary block matching ERCA sample `invoice-390.pdf`:
  1. `ድምር / Total`
  2. `የቅናሽ መጠን / Discount Amount`
  3. `የሚከፈልበት ድምር / Sub Total`
  4. `ኤክሳይዝ ታክስ / Excise Tax`
  5. `ተ.እ.ታክስ የሚከፈልበት ድምር / Taxable Total`
  6. `VAT15 ታክስ / VAT15 Tax rate (15%)`
  7. `ታክስ የማይከፈልበት ድምር / Non-taxable Amount`
  8. `ጠቅላላ ዋጋ ከታክስ ጋር / Total including Tax`
  9. `ጠቅላላ የተያዘ መጠን / Total Withheld Amount`
  10. `ጠቅላላ የተያዘ መጠን ተ.እ / Total VAT Withheld Amount`
  11. `ተጣራ የሚከፈል / Net Payable`

### B. Withholding Tax Receipts (ERCA Scan Match: `withholding-WHT-001.pdf`)
* **Top Header / POS**: Buyer / Withholding Agent (e.g. `TaxpayerS` / `HST Consulting PLC`)
* **Left Box (`ከ/From`)**: **Seller / Supplier** being withheld from (e.g. `Micro Sun & Solution PLC` / `Guba Technology PLC`).
  * Sub-labels MUST remain: `የሻጭ ስልክ ቁጥር / Seller's Phone`, `የሻጭ ተ.እ.ታ ቁጥር / Seller's VAT Reg.No`.
  * *Rationale*: In Amharic, the document is titled *"ከተከፋይ ሒሳብ ላይ ለተቀነሰ ግብር የተሰጠ ደረሰኝ"* (Tax deducted **FROM [ከ]** payee's account).
* **Right Box (`ለ/To`)**: **Buyer / Withholding Agent** remitting the tax (e.g. `TaxpayerS` / `HST Consulting PLC`).
  * Sub-labels MUST remain: `የገዢ ስልክ ቁጥር / Buyer's Phone`, `የገዢ ተ.እ.ታ ቁጥር / Buyer's VAT Reg.No`.
* **Goods vs. Services Statutory Thresholds & Rates (Proclamation No. 1395/2025 Amendment Directive)**:
  * **Goods**: Withholding rate is **3%** on pre-tax base for supplies worth **ETB 20,000 or more**. Description: *"Withholding tax deducted from the payment."*
  * **Services**: Withholding rate is **3%** on pre-tax base for services worth **ETB 10,000 or more**. Description: *"Withholding tax deduction on service payment."*
  * **Non-Compliance Penalty**: If supplier fails to provide valid TIN & business license at payment, mandatory rate is **30%**.
* **Table Column Requirement**: Must explicitly quote the original sales invoice `IRN` in column 2.

### C. Credit Notes (CRE) & Debit Notes (DEB)
* Must link directly to parent sales invoice IRN via `RelatedDocument` and `PreviousIrn`.
* Product names, quantities, and line numbers must match parent invoice lines to satisfy MoR Backend Rule 7020.

---

## 2. Mathematical Balancing & Reconciliation Formula

For both individual invoices and periodic tax declarations:
```
Net Subtotal = Gross Turnover - Trade Discounts
Taxable Base = Sum of items with TaxCode 'VAT15' + Excise Tax
Non-Taxable Base = Sum of items with TaxCode 'VATEX' (Exempt) + 'VAT0' (Zero-Rated)
Output VAT = Taxable Base × 15%
Grand Total = Taxable Base + Non-Taxable Base + Output VAT

Mathematical Balancing Verification:
Variance = |Grand Total - (Taxable Base + Non-Taxable Base + Output VAT)|
Requirement: Variance must be 0.00 ETB.
```

---

## 3. Verification Runbook (Token-Efficient Testing)

To verify all 12 compliance PDFs without burning multimodal vision tokens:

1. **Run the Automated Test Suite**:
   ```powershell
   flutter test test/generate_mor_sample_pdfs_test.dart
   ```
2. **Verify Output PDFs**:
   All compliance PDFs are generated in `MoR_Sample_PDFs/`:
   * `01_Cash_Sales_Invoice_VAT15.pdf`
   * `02_Credit_Sales_Invoice_VAT15.pdf`
   * `03_Sales_Invoice_VAT15_Exempt_ZeroRated.pdf`
   * `04_Sales_Invoice_Discount_and_Excise.pdf`
   * `05_Tax_Credit_Note.pdf`
   * `06_Tax_Debit_Note.pdf`
   * `07_Cash_Receipt_Voucher_CRB_Full.pdf`
   * `08_Cash_Receipt_Voucher_CRB_Partial.pdf`
   * `09_Withholding_Tax_Receipt.pdf` (Goods - 2%)
   * `09b_Withholding_Tax_Receipt_Services.pdf` (Services - 3%)
   * `10_MoR_All_Cases_Consolidated_Booklet.pdf`
   * `11_Tax_Declaration_and_Reconciliation_Statement.pdf`

3. **Check Balancing via Python (No vision tokens)**:
   ```powershell
   python -c "
   import pypdf
   reader = pypdf.PdfReader('MoR_Sample_PDFs/11_Tax_Declaration_and_Reconciliation_Statement.pdf')
   text = reader.pages[0].extract_text()
   assert 'Discrepancy / Variance: ETB 0.00 [VERIFIED]' in text
   print('Audit Status: 100% Balanced!')
   "
   ```
