import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistently tracks IRNs that have been cancelled on MoR servers.
/// This acts as a reliable client-side registry to safeguard against
/// backend API delays or cases where the backend server fails to update
/// the static `status` column in its local `mor_invoices` database table.
class CancelledInvoicesStorage {
  static const String _key = 'locally_cancelled_irns';
  static const String _reasonsKey = 'locally_cancelled_reasons';
  static Set<String> _cachedIrns = {};
  static Map<String, String> _cachedReasons = {};

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      _cachedIrns = list.toSet();

      final reasonsJson = prefs.getString(_reasonsKey);
      if (reasonsJson != null) {
        final decoded = jsonDecode(reasonsJson);
        if (decoded is Map) {
          _cachedReasons = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      }
    } catch (_) {}
  }

  static bool isCancelled(String? irn) {
    if (irn == null || irn.trim().isEmpty) return false;
    return _cachedIrns.contains(irn.trim());
  }

  static String? getReason(String? irn) {
    if (irn == null || irn.trim().isEmpty) return null;
    return _cachedReasons[irn.trim()];
  }

  static Future<void> markCancelled(String irn, {String? reasonCode}) async {
    final trimmed = irn.trim();
    if (trimmed.isEmpty) return;
    _cachedIrns.add(trimmed);
    if (reasonCode != null && reasonCode.trim().isNotEmpty) {
      _cachedReasons[trimmed] = reasonCode.trim();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _cachedIrns.toList());
      if (_cachedReasons.isNotEmpty) {
        await prefs.setString(_reasonsKey, jsonEncode(_cachedReasons));
      }
    } catch (_) {}
  }
}
