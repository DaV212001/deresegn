# Deresegn — Release Automation Tools

Release automation suite for **Deresegn** (`com.eims.deresegn`):
- **Android**: Automated build, version bump, and upload to Google Play Console via the Android Publisher API.

---

## 1. Google Play Release Automation

Native Dart release tool (`tool/release.dart`) that increments version numbers, builds the signed `.aab`, and uploads to Google Play Console.

### Service Account Key
Google Cloud Service Account JSON key is located at:
```text
android/play-service-account.json
```
*(Protected by `.gitignore`).*

### Common Commands
| Goal | Command |
|---|---|
| **Standard build bump to Internal track** | `dart run tool/release.dart` |
| **Patch release to Production track** | `dart run tool/release.dart --bump=patch --track=production` |
| **Explicit version to Internal track** | `dart run tool/release.dart --version=1.0.7+8 --track=internal` |
| **Release current version to Production** | `dart run tool/release.dart --bump=none --track=production --notes="Bug fixes and optimizations"` |
| **Dry run** (preview without building/uploading) | `dart run tool/release.dart --dry-run` |
| **Skip build** (upload existing `.aab`) | `dart run tool/release.dart --skip-build` |
