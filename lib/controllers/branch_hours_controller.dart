import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../models/working_hours_model.dart';
import '../services/api_service.dart';

class BranchHoursController extends GetxController {
  final Rxn<BranchWorkingHours> workingHours = Rxn<BranchWorkingHours>();
  final Rx<WorkingHoursStatus> currentStatus = Rx<WorkingHoursStatus>(
    WorkingHoursStatus(isOpen: true, message: ''),
  );
  final RxBool isLoading = false.obs;

  Timer? _statusTicker;

  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
    // Refresh status every 30 seconds to catch opening/closing time transitions
    _statusTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshStatus();
    });
    fetchHours();
  }

  @override
  void onClose() {
    _statusTicker?.cancel();
    super.onClose();
  }

  void _loadFromCache() {
    final cached = ConfigPreference.getBranchWorkingHours();
    if (cached != null) {
      workingHours.value = cached;
      currentStatus.value = cached.checkStatus();
      Logger().i(
        'Loaded cached working hours for branch ${cached.branchId}. Open now: ${currentStatus.value.isOpen}',
      );
    }
  }

  void refreshStatus() {
    if (workingHours.value != null) {
      final updated = workingHours.value!.checkStatus();
      if (updated.isOpen != currentStatus.value.isOpen ||
          updated.message != currentStatus.value.message) {
        currentStatus.value = updated;
      }
    }
  }

  Future<void> fetchHours({bool force = false}) async {
    final branchId = ConfigPreference.getBranchId();
    if (branchId == null || branchId.isEmpty) {
      return;
    }

    isLoading.value = true;
    await ApiService.getBranchHours(
      branchId: branchId,
      onSuccess: (hoursData) async {
        isLoading.value = false;
        workingHours.value = hoursData;
        currentStatus.value = hoursData.checkStatus();
        await ConfigPreference.saveBranchWorkingHours(
          jsonEncode(hoursData.toJson()),
        );
        Logger().i(
          'Updated working hours for branch $branchId. Status: ${currentStatus.value.message}',
        );
      },
      onFailure: (error, response) {
        isLoading.value = false;
        Logger().w('Failed to fetch working hours for branch $branchId: $error');
      },
    );
  }

  /// Evaluates whether the branch is currently open.
  /// If working hours are configured and the current time is outside open hours, returns false.
  bool isCurrentlyOpen([DateTime? now]) {
    final hours = workingHours.value ?? ConfigPreference.getBranchWorkingHours();
    if (hours == null) {
      // If hours are not configured or available, do not block operation
      return true;
    }
    final status = hours.checkStatus(now);
    currentStatus.value = status;
    return status.isOpen;
  }

  /// Displays an informative dialog when a user attempts to invoice outside open hours.
  void showClosedDialog(BuildContext context) {
    final status = currentStatus.value;
    final todayHour = status.todayHour;
    final scheduleText = todayHour == null
        ? 'Schedule not configured'
        : (todayHour.isClosed
            ? 'Closed today'
            : '${todayHour.openingTime} - ${todayHour.closingTime}');

    final theme = Theme.of(context);

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.access_time_filled_rounded,
                  color: Colors.amber.shade800,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Outside Operating Hours',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Invoices cannot be registered outside branch operating hours.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today (${todayHour?.dayName ?? 'Today'}):',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          scheduleText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: todayHour?.isClosed == true
                                ? Colors.red.shade700
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Understand'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showClosedSnackbar() {
    final status = currentStatus.value;
    Get.snackbar(
      'Outside Operating Hours',
      status.message.isNotEmpty
          ? status.message
          : 'Branch is currently closed. Invoicing is disabled.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.amber.shade900,
      colorText: Colors.white,
      icon: const Icon(Icons.access_time_rounded, color: Colors.white),
      duration: const Duration(seconds: 4),
    );
  }
}
