import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../models/invoice_history_model.dart';
import '../services/api_service.dart';

class InvoiceHistoryController extends GetxController {
  var invoices = <InvoiceSummary>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasError = false.obs;
  var errorMessage = ''.obs;

  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void onInit() {
    super.onInit();
    fetchInvoices(refresh: true);
  }

  Future<void> fetchInvoices({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      invoices.clear();
      isLoading.value = true;
    } else {
      if (_currentPage >= _lastPage || isLoadingMore.value) return;
      _currentPage++;
      isLoadingMore.value = true;
    }

    hasError.value = false;

    await ApiService.fetchInvoices(
      page: _currentPage,
      onSuccess: (response) {
        if (refresh) {
          invoices.assignAll(response.data);
        } else {
          invoices.addAll(response.data);
        }
        _lastPage = response.pagination.lastPage;
        isLoading.value = false;
        isLoadingMore.value = false;
      },
      onFailure: (error, response) {
        Logger().e('Failed to fetch invoices: $error');
        hasError.value = true;
        errorMessage.value = 'Failed to load invoices. Please try again.';
        isLoading.value = false;
        isLoadingMore.value = false;
      },
    );
  }
}
