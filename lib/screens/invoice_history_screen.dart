import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import '../controllers/invoice_history_controller.dart';
import '../services/invoice_history_export_service.dart';
import '../services/offline_queue_service.dart';
import 'invoice_detail_screen.dart';
import 'invoice_generator_screen.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  @override
  _InvoiceHistoryScreenState createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final _controller = Get.put(InvoiceHistoryController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.fetchInvoices();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange:
          _controller.startDate.value != null &&
              _controller.endDate.value != null
          ? DateTimeRange(
              start: _controller.startDate.value!,
              end: _controller.endDate.value!,
            )
          : null,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              surface: theme.cardColor,
              onSurface: theme.textTheme.bodyLarge?.color,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _controller.setDateRange(picked.start, picked.end);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  void _showExportOptions(BuildContext context) {
    if (_controller.invoices.isEmpty) {
      Get.snackbar(
        'export'.tr,
        'no_invoices_found'.tr,
        backgroundColor: Colors.amber.withOpacity(0.15),
        colorText: Colors.amber.shade900,
      );
      return;
    }

    final theme = Theme.of(context);
    final count = _controller.invoices.length;
    final isFiltered = _controller.startDate.value != null && _controller.endDate.value != null;
    final df = DateFormat('MMM dd, yyyy');
    final dateRangeLabel = isFiltered
        ? '${df.format(_controller.startDate.value!)} - ${df.format(_controller.endDate.value!)}'
        : 'all_invoices'.tr;

    Get.bottomSheet(
      Material(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.file_download_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'export_history'.tr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count invoices ($dateRangeLabel)',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                ),
                title: Text(
                  'export_as_pdf'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Summary report with letterhead, print & share',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Get.back();
                  InvoiceHistoryExportService.previewHistoryReport(
                    _controller.invoices,
                    startDate: _controller.startDate.value,
                    endDate: _controller.endDate.value,
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 22),
                ),
                title: Text(
                  'export_as_csv'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Full details spreadsheet file for Microsoft Excel',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Get.back();
                  try {
                    Get.snackbar(
                      'export'.tr,
                      'exporting'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 1),
                    );
                    await InvoiceHistoryExportService.exportAndShareCsv(_controller.invoices);
                  } catch (e) {
                    Get.snackbar('Error', '${'export_failed'.tr}: $e');
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTypeBadge(
    String rawType,
    String displayType,
    ThemeData theme,
  ) {
    Color textColor;
    Color bgColor;

    switch (rawType.toUpperCase()) {
      case 'CREDIT_SALE':
        textColor = const Color(0xFF1E88E5);
        bgColor = const Color(0xFF1E88E5).withOpacity(0.18);
        break;
      case 'CREDIT_NOTE':
        textColor = const Color(0xFFFB8C00);
        bgColor = const Color(0xFFFB8C00).withOpacity(0.18);
        break;
      case 'DEBIT_NOTE':
        textColor = const Color(0xFF8E24AA);
        bgColor = const Color(0xFF8E24AA).withOpacity(0.18);
        break;
      case 'WITHHOLDING':
        textColor = const Color(0xFF00ACC1);
        bgColor = const Color(0xFF00ACC1).withOpacity(0.18);
        break;
      case 'CASH_SALE':
      default:
        textColor = const Color(0xFF43A047);
        bgColor = const Color(0xFF43A047).withOpacity(0.18);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        displayType,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String? status,
    ThemeData theme, {
    bool isCancelled = false,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    String text;
    IconData icon;

    final effectiveCancelled = isCancelled ||
        status?.toUpperCase() == 'C' ||
        status?.toUpperCase() == 'CANCELLED';

    if (effectiveCancelled) {
      bgColor = const Color(0xFFD32F2F).withOpacity(0.12);
      textColor = const Color(0xFFD32F2F);
      borderColor = const Color(0xFFD32F2F).withOpacity(0.3);
      text = 'cancelled'.tr;
      icon = Icons.cancel_outlined;
    } else if (status?.toUpperCase() == 'A' || status?.toUpperCase() == 'ACTIVE') {
      bgColor = const Color(0xFF2E7D32).withOpacity(0.12);
      textColor = const Color(0xFF2E7D32);
      borderColor = const Color(0xFF2E7D32).withOpacity(0.3);
      text = 'active'.tr;
      icon = Icons.check_circle_outline;
    } else {
      bgColor = Colors.grey.withOpacity(0.12);
      textColor = Colors.grey;
      borderColor = Colors.grey.withOpacity(0.3);
      text = status ?? 'unknown'.tr;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'invoices'.tr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  theme.appBarTheme.foregroundColor ??
                  theme.colorScheme.onSurface,
            ),
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                Icons.file_download_outlined,
                color: theme.appBarTheme.foregroundColor,
              ),
              tooltip: 'export'.tr,
              onPressed: () => _showExportOptions(context),
            ),
            IconButton(
              icon: Icon(
                CupertinoIcons.calendar,
                color: theme.appBarTheme.foregroundColor,
              ),
              onPressed: () => _selectDateRange(context),
            ),
            IconButton(
              icon: Icon(
                CupertinoIcons.refresh,
                color: theme.appBarTheme.foregroundColor,
              ),
              onPressed: () {
                _controller.fetchInvoices(refresh: true);
                if (Get.isRegistered<OfflineQueueService>()) {
                   Get.find<OfflineQueueService>().syncQueue();
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'History'),
              Tab(text: 'Unsynced'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHistoryView(theme),
            _buildUnsyncedView(theme),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            PersistentNavBarNavigator.pushNewScreen(
              context,
              screen: InvoiceGeneratorScreen(),
              withNavBar: false,
            );
          },
          icon: const Icon(CupertinoIcons.add),
          label: Text(
            'new_invoice'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView(ThemeData theme) {
    return Column(
      children: [
        Obx(() {
          if (_controller.startDate.value == null ||
              _controller.endDate.value == null) {
            return const SizedBox.shrink();
          }
          final df = DateFormat('MMM dd, yyyy');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.calendar,
                  size: 16,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${df.format(_controller.startDate.value!)} - ${df.format(_controller.endDate.value!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _controller.setDateRange(null, null),
                  child: Icon(
                    CupertinoIcons.clear_circled_solid,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }),
        Obx(() {
          if (!_controller.isOfflineMode.value) return const SizedBox.shrink();
          final dfTime = DateFormat('MMM dd, HH:mm');
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade700.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.amber.shade700.withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 20,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'offline_cached_banner'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      if (_controller.lastCachedTime.value != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${'last_updated'.tr}: ${dfTime.format(_controller.lastCachedTime.value!.toLocal())}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade900.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 20, color: Colors.amber.shade900),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'retry'.tr,
                  onPressed: () => _controller.fetchInvoices(refresh: true),
                ),
              ],
            ),
          );
        }),
        Expanded(
          child: Obx(() {
            if (_controller.isLoading.value) {
              return Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              );
            }

            if (_controller.hasError.value) {
              final isMorError = _controller.errorMessage.value.toLowerCase().contains('mor') ||
                  _controller.errorMessage.value.toLowerCase().contains('support');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isMorError ? Colors.amber : theme.colorScheme.secondary).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMorError ? Icons.support_agent_rounded : CupertinoIcons.exclamationmark_triangle,
                          color: isMorError ? Colors.amber.shade800 : theme.colorScheme.secondary,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isMorError ? 'MoR Setup Required' : 'Error Loading History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _controller.errorMessage.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _controller.fetchInvoices(refresh: true),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text('retry'.tr),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_controller.invoices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.doc_text,
                      color: Colors.grey.withOpacity(0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'no_invoices_found'.tr,
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: theme.primaryColor,
              backgroundColor: theme.cardColor,
              onRefresh: () => _controller.fetchInvoices(refresh: true),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 80, // Padding for FAB
                ),
                itemCount: _controller.invoices.length +
                    (_controller.isLoadingMore.value ? 1 : 0),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _controller.invoices.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      ),
                    );
                  }

                  final invoice = _controller.invoices[index];
                  final isCancelled = invoice.isCancelled;
                  final reason = invoice.cancellationReasonDescription;
                  final buyerName = invoice.buyer.legalName ?? 'Unknown Buyer';
                  final totalValue = invoice.totals.totalValue ?? '0.00';
                  final currency = invoice.totals.currency ?? 'ETB';

                  return GestureDetector(
                    onTap: () {
                      PersistentNavBarNavigator.pushNewScreen(
                        context,
                        screen: InvoiceDetailScreen(invoice: invoice),
                        withNavBar: false,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCancelled
                              ? const Color(0xFFD32F2F).withOpacity(0.55)
                              : theme.dividerColor,
                          width: isCancelled ? 1.2 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  buyerName,
                                  style: TextStyle(
                                    color: isCancelled
                                        ? theme.textTheme.bodyLarge?.color?.withOpacity(0.7)
                                        : theme.textTheme.bodyLarge?.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildDocumentTypeBadge(
                                invoice.rawDocumentType,
                                invoice.documentType,
                                theme,
                              ),
                              const SizedBox(width: 6),
                              _buildStatusBadge(
                                invoice.status,
                                theme,
                                isCancelled: isCancelled,
                              ),
                            ],
                          ),
                          if (isCancelled && reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: Color(0xFFD32F2F),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${'cancellation_reason'.tr}: $reason',
                                    style: const TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'IRN: ${invoice.irn ?? 'N/A'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(invoice.createdAt),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$totalValue $currency',
                                style: TextStyle(
                                  color: isCancelled
                                      ? const Color(0xFFD32F2F)
                                      : theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildUnsyncedView(ThemeData theme) {
    if (!Get.isRegistered<OfflineQueueService>()) {
      return const Center(child: Text('Offline service unavailable'));
    }
    final queueService = Get.find<OfflineQueueService>();
    
    return Obx(() {
      final queue = queueService.queue;
      
      if (queue.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_done,
                color: Colors.green.withOpacity(0.5),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'All invoices synced!',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            ],
          ),
        );
      }
      
      return ListView.separated(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80,
        ),
        itemCount: queue.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = queue[index];
          final request = item.request;
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.buyerName.isNotEmpty ? item.buyerName : 'Unknown Buyer',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDocumentTypeBadge(
                      request.documentDetails['Type']?.toString().toUpperCase() == 'CRE'
                          ? 'CREDIT_NOTE'
                          : (request.paymentDetails['PaymentTerm']?.toString().toUpperCase() == 'CREDIT'
                              ? 'CREDIT_SALE'
                              : 'CASH_SALE'),
                      request.documentDetails['Type']?.toString().toUpperCase() == 'CRE'
                          ? 'credit_note'.tr
                          : (request.paymentDetails['PaymentTerm']?.toString().toUpperCase() == 'CREDIT'
                              ? 'credit_sale'.tr
                              : 'cash_sale'.tr),
                      theme,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'PENDING',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Queued at: ${DateFormat('MMM dd, yyyy HH:mm').format(item.queuedAt.toLocal())}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.grandTotal} ${request.valueDetails['InvoiceCurrency'] ?? 'ETB'}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.sync, color: theme.primaryColor),
                      onPressed: () {
                        queueService.syncQueue();
                        Get.snackbar('Sync', 'Attempting to sync pending invoices...', snackPosition: SnackPosition.BOTTOM);
                      },
                      tooltip: 'Sync Now',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
