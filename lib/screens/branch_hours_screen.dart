import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/branch_hours_controller.dart';
import '../models/working_hours_model.dart';

class BranchHoursScreen extends StatelessWidget {
  const BranchHoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hoursController = Get.isRegistered<BranchHoursController>()
        ? Get.find<BranchHoursController>()
        : Get.put(BranchHoursController());

    final currentBackendDay = DateTime.now().weekday % 7;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Operating Hours'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Hours',
            onPressed: () => hoursController.fetchHours(force: true),
          ),
        ],
      ),
      body: Obx(() {
        final hoursData = hoursController.workingHours.value;
        final status = hoursController.currentStatus.value;
        final isLoading = hoursController.isLoading.value;

        if (isLoading && hoursData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (hoursData == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Operating Hours Configured',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Operating hours have not been configured for this branch yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => hoursController.fetchHours(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => hoursController.fetchHours(force: true),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Current Status Card
              Card(
                elevation: 0,
                color: status.isOpen
                    ? Colors.green.shade900.withValues(alpha: 0.12)
                    : Colors.amber.shade900.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: status.isOpen
                        ? Colors.green.shade700.withValues(alpha: 0.4)
                        : Colors.amber.shade700.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: status.isOpen
                              ? Colors.green.shade800
                              : Colors.amber.shade800,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          status.isOpen
                              ? Icons.check_circle_outline
                              : Icons.schedule_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.isOpen ? 'Branch is OPEN' : 'Branch is CLOSED',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: status.isOpen
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Branch Info Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hoursData.branchName.isNotEmpty
                          ? hoursData.branchName
                          : 'Branch Schedule',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Branch #${hoursData.branchId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 7-day schedule card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: hoursData.hours.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final day = hoursData.hours[index];
                    final isToday = day.dayOfWeek == currentBackendDay;

                    return Container(
                      color: isToday
                          ? theme.colorScheme.primary.withValues(alpha: 0.06)
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          child: Text(
                            day.dayName.isNotEmpty ? day.dayName[0] : '?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              day.dayName,
                              style: TextStyle(
                                fontWeight:
                                    isToday ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          day.isClosed
                              ? 'Closed'
                              : '${day.openingTime ?? '--:--'} - ${day.closingTime ?? '--:--'}',
                          style: TextStyle(
                            fontWeight:
                                day.isClosed ? FontWeight.normal : FontWeight.w600,
                            color: day.isClosed
                                ? Colors.red.shade700
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              // Note regarding enforcement
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Invoice creation is strictly restricted to active operating hours in compliance with branch fiscal rules.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
