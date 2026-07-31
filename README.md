# Deresegn POS Mobile App

Deresegn is an advanced, cross-platform Point of Sale (POS) and SaaS mobile application built with Flutter. It integrates seamlessly with the Ethiopian Ministry of Revenues (MoR) e-invoicing systems.

## Features
- **Offline-First Syncing:** Temporarily queues invoices locally during network outages and syncs when back online.
- **MoR Token Exchange:** Securely requests and manages temporary MoR tokens for fiscal receipt signing.
- **Multi-Tenant Architecture:** Robust JWT-based authentication ensuring data isolation across companies and branches.
- **Role-Based Access Control:** Secure handling of Branch TINs and passwords.

## Architecture
- **Framework:** Flutter SDK ^3.12.2
- **State Management:** GetX (`get` plugin)
- **Networking:** `dio` for HTTPS requests
- **Storage:** `flutter_secure_storage` and `shared_preferences`

For the INSA security audit, please review the provided test accounts and specific functionalities detailed in the documentation.
