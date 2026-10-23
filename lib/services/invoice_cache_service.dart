import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_history_model.dart';

class InvoiceCacheService {
  static const String _cacheKey = 'cached_invoices_history_v1';
  static const String _updatedAtKey = 'cached_invoices_updated_at_v1';
  static const int _maxCachedInvoices = 150;

  /// Saves or merges a list of invoices into local SharedPreferences cache.
  static Future<void> saveInvoices(List<InvoiceSummary> newInvoices) async {
    if (newInvoices.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load existing cached items to merge
      final existing = await loadInvoices();
      final Map<String, InvoiceSummary> invoiceMap = {};

      // Insert existing first
      for (final inv in existing) {
        final key = _makeKey(inv);
        invoiceMap[key] = inv;
      }

      // Overwrite/insert new items (fresher data)
      for (final inv in newInvoices) {
        final key = _makeKey(inv);
        invoiceMap[key] = inv;
      }

      // Sort descending (latest created_at or highest ID first)
      final mergedList = invoiceMap.values.toList()
        ..sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            final cmp = b.createdAt!.compareTo(a.createdAt!);
            if (cmp != 0) return cmp;
          }
          return b.id.compareTo(a.id);
        });

      // Trim to maximum cache size
      final trimmedList = mergedList.take(_maxCachedInvoices).toList();

      final jsonList = trimmedList.map((e) => e.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
      await prefs.setString(_updatedAtKey, DateTime.now().toIso8601String());
      Logger().d('Cached ${trimmedList.length} past invoices locally.');
    } catch (e) {
      Logger().e('Failed to save invoices to cache: $e');
    }
  }

  /// Loads cached invoices from SharedPreferences. Returns empty list if none cached.
  static Future<List<InvoiceSummary>> loadInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => InvoiceSummary.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      Logger().e('Failed to load cached invoices: $e');
    }
    return [];
  }

  /// Returns the DateTime when the cache was last written.
  static Future<DateTime?> getLastCachedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_updatedAtKey);
      if (raw != null) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  /// Clears the cached invoices.
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_updatedAtKey);
    } catch (_) {}
  }

  static String _makeKey(InvoiceSummary inv) {
    if (inv.irn != null && inv.irn!.isNotEmpty) return inv.irn!;
    if (inv.documentNumber != null && inv.documentNumber!.isNotEmpty) {
      return 'doc_${inv.documentNumber}';
    }
    return 'id_${inv.id}';
  }
}
