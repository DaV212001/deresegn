import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import '../controllers/invoice_history_controller.dart';
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status?.toUpperCase()) {
      case 'A':
        bgColor = const Color(0xFF00FFB3).withOpacity(0.2);
        textColor = const Color(0xFF00FFB3);
        text = 'Active';
        break;
      case 'C':
        bgColor = const Color(0xFFFF3366).withOpacity(0.2);
        textColor = const Color(0xFFFF3366);
        text = 'Cancelled';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.2);
        textColor = Colors.grey;
        text = status ?? 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Invoices',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: () => _controller.fetchInvoices(refresh: true),
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FFB3)),
          );
        }

        if (_controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: Color(0xFFFF3366),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _controller.errorMessage.value,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _controller.fetchInvoices(refresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
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
                const Text(
                  'No invoices found',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF00FFB3),
          backgroundColor: const Color(0xFF1F1F1F),
          onRefresh: () => _controller.fetchInvoices(refresh: true),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80, // Padding for FAB
            ),
            itemCount:
                _controller.invoices.length +
                (_controller.isLoadingMore.value ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == _controller.invoices.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FFB3)),
                  ),
                );
              }

              final invoice = _controller.invoices[index];
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
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(invoice.status),
                        ],
                      ),
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
                            style: const TextStyle(
                              color: Color(0xFF00FFB3),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          PersistentNavBarNavigator.pushNewScreen(
            context,
            screen: InvoiceGeneratorScreen(),
            withNavBar: false,
          );
        },
        backgroundColor: const Color(0xFF00FFB3),
        foregroundColor: Colors.black,
        icon: const Icon(CupertinoIcons.add),
        label: const Text(
          'New Invoice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
