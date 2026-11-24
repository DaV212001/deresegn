import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'invoice_pdf_service.dart';

class InsaRequestFormData {
  final String fullName;
  final String address;
  final String telephone;
  final String email;
  final String organizationName;
  final String tin;
  final String branchName;
  final String systemId;
  final int branchId;

  const InsaRequestFormData({
    required this.fullName,
    required this.address,
    required this.telephone,
    required this.email,
    required this.organizationName,
    required this.tin,
    required this.branchName,
    required this.systemId,
    this.branchId = 0,
  });

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'address': address,
        'telephone': telephone,
        'email': email,
        'organizationName': organizationName,
        'tin': tin,
        'branchName': branchName,
        'systemId': systemId,
        'branchId': branchId,
      };
}

class InsaRequestFormService {
  /// Generates the plain text / markdown version matching INSA's official format
  static String generateText(InsaRequestFormData data) {
    return '''E-Invoice Digital Certificate Request Form
Contact Person Information
| ** Full Name:   | ${data.fullName.trim()}   |
| ** Address:   | ${data.address.trim()}   |
| ** Telephone No.:   | ${data.telephone.trim()}   |
| ** e-mail address:   | ${data.email.trim()}   |
Tax Payer / Organization Information
| ** Organization Name:    | ${data.organizationName.trim()}   |
| ** TIN:   | ${data.tin.trim()}   |
Invoice System Information
| No.   | Organization/Business/Branch Name   | System ID:   |
| 1   | ${data.branchName.trim()}   | ${data.systemId.trim()}   |
Note:
Fields marked with ** are required.
At least ONE (01) System ID is required in section 3 (Invoice System Information). If you have more System IDs, please add more rows in the table.
This form with the Certificate Signing Request (CSR) file shall be sent to ica@insa.gov.et as attachment.''';
  }

  /// Generates an official, publication-quality PDF matching INSA's table structure
  static Future<Uint8List> generatePdf(InsaRequestFormData data) async {
    pw.ThemeData? theme;
    try {
      theme = await InvoicePdfService.loadPdfTheme();
    } catch (_) {}

    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          const primaryBlue = PdfColor.fromInt(0xFF1E3A8A);
          const headerBg = PdfColor.fromInt(0xFFF1F5F9);
          const borderColor = PdfColor.fromInt(0xFFCBD5E1);

          pw.Widget buildSectionHeader(String title) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: borderColor, width: 0.8),
              ),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            );
          }

          pw.Widget buildTwoColumnRow(String label, String value) {
            return pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 0.5),
                  left: pw.BorderSide(color: borderColor, width: 0.5),
                  right: pw.BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 170,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFAFAFA),
                      border: pw.Border(
                        right: pw.BorderSide(color: borderColor, width: 0.5),
                      ),
                    ),
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: pw.Text(
                        value,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Document Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: primaryBlue,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Information Network Security Administration (INSA)',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'E-Invoice Digital Certificate Request Form',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Section 1: Contact Person Information
              buildSectionHeader('1. Contact Person Information'),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
                ),
                child: pw.Column(
                  children: [
                    buildTwoColumnRow('** Full Name:', data.fullName.trim()),
                    buildTwoColumnRow('** Address:', data.address.trim()),
                    buildTwoColumnRow('** Telephone No.:', data.telephone.trim()),
                    buildTwoColumnRow('** e-mail address:', data.email.trim()),
                  ],
                ),
              ),

              // Section 2: Tax Payer / Organization Information
              buildSectionHeader('2. Tax Payer / Organization Information'),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
                ),
                child: pw.Column(
                  children: [
                    buildTwoColumnRow('** Organization Name:', data.organizationName.trim()),
                    buildTwoColumnRow('** TIN:', data.tin.trim()),
                  ],
                ),
              ),

              // Section 3: Invoice System Information
              buildSectionHeader('3. Invoice System Information'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
                    children: [
                      pw.Container(
                        width: 40,
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('No.',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Organization/Business/Branch Name',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        width: 140,
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('System ID:',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('1', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(data.branchName.trim(),
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(data.systemId.trim(),
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),

              // Section 4: Notes
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF3C7),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFDE68A), width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Note:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF92400E),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '• Fields marked with ** are required.\n'
                      '• At least ONE (01) System ID is required in section 3 (Invoice System Information). If you have more System IDs, please add more rows in the table.\n'
                      '• This form with the Certificate Signing Request (CSR) file shall be sent to ica@insa.gov.et as attachment.',
                      style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Document Footer
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Branch #${data.branchId} • Generated by Deresegn E-Invoice System',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Recipient: ica@insa.gov.et',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Locates the user's public Downloads directory across Android, iOS, and Desktop.
  /// Never falls back to internal app cache/documents directory to prevent false positives.
  static Future<Directory?> getPublicDownloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidDownload = Directory('/storage/emulated/0/Download');
      if (await androidDownload.exists()) {
        return androidDownload;
      }
      final androidDownloads = Directory('/storage/emulated/0/Downloads');
      if (await androidDownloads.exists()) {
        return androidDownloads;
      }
      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty && await extDirs.first.exists()) {
          return extDirs.first;
        }
      } catch (_) {}
    }
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null && await dir.exists()) {
        return dir;
      }
    } catch (_) {}
    return null;
  }

  /// Saves a file into the user's public download directory
  static Future<File?> saveFileToPublicDirectory({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await getPublicDownloadDirectory();
      if (dir == null) return null;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Error saving to public directory: $e');
      return null;
    }
  }

  /// Saves a file into the application documents (in-app cache) directory
  static Future<File?> saveFileToAppCache({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Error saving to app cache: $e');
      return null;
    }
  }

  /// Checks if a valid, non-empty file exists in the public directory and returns its path.
  /// Guarantees that public directory is distinct from private app storage and validates file contents.
  static Future<String?> findInPublicDirectory(String fileName) async {
    try {
      final dir = await getPublicDownloadDirectory();
      if (dir == null) return null;

      // Ensure public directory does not point to internal application documents/cache
      try {
        final appCacheDir = await getApplicationDocumentsDirectory();
        if (dir.path == appCacheDir.path) return null;
      } catch (_) {}

      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        final len = await file.length();
        if (len == 0) return null;

        // Content integrity validation to prevent false positives from empty/corrupt files
        if (fileName.endsWith('.pem')) {
          final content = await file.readAsString();
          if (!content.contains('-----BEGIN CERTIFICATE REQUEST-----')) {
            return null;
          }
        } else if (fileName.endsWith('.pdf')) {
          if (len < 50) return null;
          final headerBytes = await file.openRead(0, 5).first;
          final header = utf8.decode(headerBytes, allowMalformed: true);
          if (!header.startsWith('%PDF')) return null;
        }

        return file.path;
      }
    } catch (_) {}
    return null;
  }

  /// Checks if a valid, non-empty file exists in the application documents cache and returns its path.
  /// Validates file length and content to avoid false positives.
  static Future<String?> findInAppCache(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        final len = await file.length();
        if (len == 0) return null;

        // Content integrity validation to prevent false positives
        if (fileName.endsWith('.pem')) {
          final content = await file.readAsString();
          if (!content.contains('-----BEGIN CERTIFICATE REQUEST-----')) {
            return null;
          }
        } else if (fileName.endsWith('.pdf')) {
          if (len < 50) return null;
          final headerBytes = await file.openRead(0, 5).first;
          final header = utf8.decode(headerBytes, allowMalformed: true);
          if (!header.startsWith('%PDF')) return null;
        }

        return file.path;
      }
    } catch (_) {}
    return null;
  }
}
