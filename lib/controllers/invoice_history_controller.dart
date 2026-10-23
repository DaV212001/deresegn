import 'package:dio/dio.dart' as dio_lib;
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/dio_config.dart';
import '../models/invoice_history_model.dart';
import '../services/api_service.dart';
import '../services/invoice_cache_service.dart';
import 'auth_controller.dart';

class InvoiceHistoryController extends GetxController {
  var invoices = <InvoiceSummary>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasError = false.obs;
  var errorMessage = ''.obs;
  var isOfflineMode = false.obs;
  var lastCachedTime = Rxn<DateTime>();

  var startDate = Rxn<DateTime>();
  var endDate = Rxn<DateTime>();

  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void onInit() {
    super.onInit();
    _loadCachedInvoices();
    fetchInvoices(refresh: true);
  }

  Future<void> _loadCachedInvoices() async {
    try {
      final cached = await InvoiceCacheService.loadInvoices();
      final cachedTime = await InvoiceCacheService.getLastCachedTime();
      if (cached.isNotEmpty && invoices.isEmpty) {
        invoices.assignAll(cached);
        lastCachedTime.value = cachedTime;
      }
    } catch (e) {
      Logger().e('Error loading cached invoices: $e');
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    startDate.value = start;
    endDate.value = end;
    fetchInvoices(refresh: true);
  }

  void markInvoiceCancelledLocally(String irn, {String? reasonCode}) {
    final idx = invoices.indexWhere((inv) => inv.irn == irn);
    if (idx != -1) {
      final existing = invoices[idx];
      invoices[idx] = existing.copyWith(
        status: 'C',
        cancellationReason: reasonCode ?? existing.cancellationReason,
      );
      invoices.refresh();
      InvoiceCacheService.saveInvoices(invoices);
    }
  }

  Future<void> fetchInvoices({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      // Optimistic refresh: keep existing invoices visible on screen while refreshing
      if (invoices.isEmpty) {
        isLoading.value = true;
      }
    } else {
      if (_currentPage >= _lastPage || isLoadingMore.value) return;
      _currentPage++;
      isLoadingMore.value = true;
    }

    hasError.value = false;

    // Trigger MoR auto-login in the background without blocking history load
    // or displaying contact support errors prematurely.
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put(AuthController());
    authController.ensureMorAuth().catchError((e) {
      Logger().w('Background MoR auth in history page: $e');
      return false;
    });

    String? startStr = startDate.value != null
        ? startDate.value!.toIso8601String().split('T')[0]
        : null;
    String? endStr = endDate.value != null
        ? endDate.value!.toIso8601String().split('T')[0]
        : null;

    await ApiService.fetchInvoices(
      page: _currentPage,
      startDate: startStr,
      endDate: endStr,
      onSuccess: (response) {
        isOfflineMode.value = false;
        hasError.value = false;

        if (refresh) {
          invoices.assignAll(response.data);
          InvoiceCacheService.saveInvoices(response.data);
        } else {
          invoices.addAll(response.data);
          InvoiceCacheService.saveInvoices(invoices.toList());
        }
        lastCachedTime.value = DateTime.now();
        _lastPage = response.pagination.lastPage;
        isLoading.value = false;
        isLoadingMore.value = false;
      },
      onFailure: (error, response) async {
        Logger().e('Failed to fetch invoices: $error');

        if (DioConfig.isSessionExpiredError(error)) {
          hasError.value = true;
          errorMessage.value = 'Session expired. Please log in again.';
          isLoading.value = false;
          isLoadingMore.value = false;
          return;
        }

        final dynamic errorData = (error is dio_lib.DioException)
            ? error.response?.data
            : response.data;

        final isMorCredentialError = (errorData is Map &&
            (errorData['code'] == '4503' ||
             '${errorData['message']}'.toLowerCase().contains('credential')));

        if (isMorCredentialError) {
          hasError.value = true;
          errorMessage.value = 'Please contact support to set up your MoR credentials.';
          isLoading.value = false;
          isLoadingMore.value = false;
          return;
        }

        // If we don't have invoices in memory yet, try loading from local cache
        if (invoices.isEmpty) {
          final cached = await InvoiceCacheService.loadInvoices();
          if (cached.isNotEmpty) {
            invoices.assignAll(cached);
            lastCachedTime.value = await InvoiceCacheService.getLastCachedTime();
          }
        }

        if (invoices.isNotEmpty) {
          // Graceful offline fallback: keep cached items visible and show offline banner
          isOfflineMode.value = true;
          hasError.value = false;
        } else {
          hasError.value = true;
          errorMessage.value = 'Failed to load invoices. Please try again.';
        }

        isLoading.value = false;
        isLoadingMore.value = false;
      },
    );
  }
}
