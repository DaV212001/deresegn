import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice_models.dart';
import 'api_service.dart';

class OfflineQueueService extends GetxService {
  static const String _queueKey = 'offline_invoice_queue';
  final RxList<QueuedInvoice> queue = <QueuedInvoice>[].obs;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isSyncing = false;

  Future<OfflineQueueService> init() async {
    await _loadQueue();
    
    // Listen to network changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        Logger().i('Network restored, attempting to sync offline queue.');
        syncQueue();
      }
    });

    return this;
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final String? queueString = prefs.getString(_queueKey);
    if (queueString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(queueString);
        queue.value = decoded.map((e) => QueuedInvoice.fromJson(e)).toList();
      } catch (e) {
        Logger().e('Failed to load offline queue: $e');
        queue.value = [];
      }
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(queue.map((e) => e.toJson()).toList());
    await prefs.setString(_queueKey, encoded);
  }

  Future<void> addInvoiceToQueue(InvoiceRegisterRequest request, String buyerName, String grandTotal) async {
    final queuedInvoice = QueuedInvoice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      request: request,
      buyerName: buyerName,
      grandTotal: grandTotal,
      queuedAt: DateTime.now(),
    );
    queue.add(queuedInvoice);
    await _saveQueue();
    Logger().i('Invoice added to offline queue. Total queued: ${queue.length}');
  }

  Future<void> removeInvoiceFromQueue(String id) async {
    queue.removeWhere((element) => element.id == id);
    await _saveQueue();
  }

  Future<void> syncQueue() async {
    if (_isSyncing || queue.isEmpty) return;
    _isSyncing = true;
    
    Logger().i('Starting sync for ${queue.length} offline invoices.');
    
    // Create a copy of the list to iterate over, as we'll be removing items on success
    final pendingInvoices = List<QueuedInvoice>.from(queue);
    
    for (var pending in pendingInvoices) {
      bool success = false;
      await ApiService.registerInvoice(
        pending.request,
        onSuccess: (response) async {
          Logger().i('Successfully synced offline invoice ${pending.id}');
          success = true;
        },
        onFailure: (error, response) {
          Logger().e('Failed to sync offline invoice ${pending.id}: $error');
          // We keep it in the queue to retry later unless it's a validation error.
          // For simplicity, we just leave it in the queue for now.
        },
      );
      
      if (success) {
        await removeInvoiceFromQueue(pending.id);
      }
    }
    
    _isSyncing = false;
  }
}
