# Deresegn POS — Security Assessment Submission Index

**Submitted by:** Micro Sun & Solution PLC  
**Application:** Deresegn POS v1.0.3+4  
**Date:** August 5, 2026  
**Classification:** Confidential  

---

## Submission Contents

This package contains all required and optional documentation for the mobile application security assessment of **Deresegn POS**.

### Required Documents

| # | Document | Filename | Status |
|---|----------|----------|--------|
| 1 | Requirements Documentation (SRS) | `01_Requirements_Documentation_SRS.md` | ✅ Included |
| 2 | System & Architecture Design (SDD) | `02_System_Architecture_Design_SDD.md` | ✅ Included |
| 3 | Technical Specifications (TDD/LLD) | `03_Technical_Specifications_TDD.md` | ✅ Included |
| 4 | User Documentation (User Guide) | `04_User_Documentation_Guide.md` | ✅ Included |
| 5 | Application Binary Instructions | `05_Application_Binary_README.md` | ✅ Included |
| 8 | Mobile API User Documentation (API Guide) | `08_Mobile_API_User_Documentation_Guide.md` | ✅ Included |

### Mandatory Supplement

| # | Document | Filename | Status |
|---|----------|----------|--------|
| 6 | Data Classification | `06_Data_Classification.md` | ✅ Included |

### Optional Documents

| # | Document | Filename | Status |
|---|----------|----------|--------|
| 7 | Security Documentation | `07_Security_Documentation.md` | ✅ Included |

---

## Application Binary

The application binary (APK) must be built separately and included in the final submission ZIP. See `05_Application_Binary_README.md` for build instructions.

**Build command:**
```bash
cd c:\flutter_dev\deresegn
flutter build apk --release
```

**Output location:**
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Version Information

| Component | Version |
|---|---|
| Mobile Application | 1.0.3+4 |
| Flutter SDK | ^3.12.2 |
| Dart SDK | ^3.0.0 |
| Backend Framework | Laravel ^8.75 |
| PHP | ^7.3 / ^8.0 |
| All Documents | v1.0 |

---

## Regulatory & Specification References

All e-invoicing workflows, cryptographic signing procedures, and payload schemas implemented in Deresegn POS adhere to the official non-public technical specifications issued by the Ministry of Revenues (MoR) to registered vendors:

- **Reference Standard:** Ministry of Revenues (MoR) e-Invoicing System Technical & API Specification
- **Issuing Body:** Ministry of Revenues, Federal Democratic Republic of Ethiopia
- **Access / Classification:** Restricted Vendor Provision (Confidential)
- **Enclosure Path in Submission ZIP:** `/References/MoR_eInvoicing_API_Specification.pdf`

---

## Contact

**Developer:** Micro Sun & Solution PLC  
**Email:** amanuielt@mssethiopia.com  
**Phone:** +251 911 058 179  
