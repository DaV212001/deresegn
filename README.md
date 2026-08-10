# Deresegn POS Mobile App

Deresegn POS is a comprehensive Point of Sale and SaaS mobile application built with Flutter. It seamlessly integrates with the Ethiopian Ministry of Revenues (MoR) e-invoicing system to facilitate secure, compliant fiscal transactions.

## Features

- **Offline Reliability:** Generates and queues invoices locally using `shared_preferences` during network outages, synchronizing automatically when connectivity is restored.
- **Multi-Tenant Authentication:** Strict JWT-based authentication for Company Owners and Branch-level users, isolating organizational data.
- **MoR Integration:** Automatically handles secure authentication and token exchange with the Ethiopian Ministry of Revenues to register invoices, cancel invoices, and submit sales/withholding receipts.
- **Robust Architecture:** Powered by GetX for state management and Dio for secure networking.

## Prerequisites

- **Flutter SDK:** ^3.12.2 (or compatible version)
- **Dart SDK:** >=3.0.0
- **Android Studio / Xcode:** For building native packages.

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

4. **Build a release APK:**
   ```bash
   flutter build apk --release
   ```

## Architecture

- **Frontend:** Flutter & Dart
- **State Management:** GetX
- **Backend:** Laravel 8 REST API (`https://api.deresegn.com`)
