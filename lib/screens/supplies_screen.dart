import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/invoice_controller.dart';
import '../models/invoice_models.dart';

class SuppliesScreen extends StatefulWidget {
  const SuppliesScreen({super.key});

  @override
  State<SuppliesScreen> createState() => _SuppliesScreenState();
}

class _SuppliesScreenState extends State<SuppliesScreen> {
  final _controller = Get.find<InvoiceController>();
  final _searchController = TextEditingController();
  final _searchQuery = ''.obs;
  final _selectedFilter = 'All'.obs;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSupplyDialog({SupplyItem? existingItem}) {
    final descController = TextEditingController(
      text: existingItem?.productDescription,
    );
    final priceController = TextEditingController(
      text: existingItem?.unitPrice.toString(),
    );
    final itemCodeController = TextEditingController(
      text: existingItem?.itemCode,
    );
    String selectedNature = existingItem?.natureOfSupplies ?? 'goods';
    String selectedUnit = existingItem?.unit ?? 'PCS';
    var selectedTax =
        (existingItem != null
                ? taxCategories.firstWhere(
                    (cat) => cat.code == existingItem.taxCode,
                    orElse: () => taxCategories.first,
                  )
                : taxCategories.first)
            .obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        title: Text(
          existingItem == null ? 'Add New Supply' : 'Edit Supply',
          style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField('Description', descController),
              const SizedBox(height: 12),
              _buildDialogField('Unit Price', priceController, isNumber: true),
              const SizedBox(height: 12),
              _buildDialogField('Item Code (Optional)', itemCodeController),
              const SizedBox(height: 12),
              Obx(
                () => DropdownButtonFormField<TaxCategory>(
                  value: selectedTax.value,
                  dropdownColor: Get.theme.cardColor,
                  style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
                  decoration: _dialogInputDecoration('Tax Category'),
                  items: taxCategories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.description),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => selectedTax.value = val!,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                dropdownColor: Get.theme.cardColor,
                style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
                decoration: _dialogInputDecoration('Unit'),
                items: ['PCS', 'KG', 'LTR', 'MTR', 'DAY', 'HR']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (val) => selectedUnit = val!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedNature,
                dropdownColor: Get.theme.cardColor,
                style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
                decoration: _dialogInputDecoration('Nature'),
                items: ['goods', 'service', 'other']
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (val) => selectedNature = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFB3),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (descController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                final newItem = InvoiceItem(
                  description: descController.text,
                  unitPrice: double.tryParse(priceController.text) ?? 0,
                  quantity: 1,
                  taxCategory: selectedTax.value,
                  natureOfSupplies: selectedNature,
                  unit: selectedUnit,
                  itemCode: itemCodeController.text,
                );

                if (existingItem == null) {
                  _controller.saveItemToCatalog(newItem);
                } else {
                  _controller.updateSupply(existingItem.id!, newItem);
                }
                Get.back();
              }
            },
            child: Text(existingItem == null ? 'Save Supply' : 'Update Supply'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        title: Text(
          'Delete Supply',
          style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
        ),
        content: const Text(
          'Are you sure you want to delete this item from the catalog?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _controller.deleteSupply(id);
              Get.back();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Get.theme.inputDecorationTheme.fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
      decoration: _dialogInputDecoration(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Catalog',
          style: TextStyle(
            color:
                theme.appBarTheme.foregroundColor ??
                theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () => _controller.fetchSupplies(),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              tooltip: 'Refresh catalog',
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _searchQuery.value = val,
              style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search items or codes...',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.3),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'goods', 'service'].map((filter) {
                  final isSelected = _selectedFilter.value == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => _selectedFilter.value = filter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.primaryColor
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filter.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (_controller.isLoadingSupplies.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00FFB3)),
                );
              }

              var filteredList = _controller.availableSupplies.where((item) {
                final matchesSearch =
                    item.productDescription.toLowerCase().contains(
                      _searchQuery.value.toLowerCase(),
                    ) ||
                    item.itemCode.toLowerCase().contains(
                      _searchQuery.value.toLowerCase(),
                    );
                final matchesFilter =
                    _selectedFilter.value == 'All' ||
                    item.natureOfSupplies == _selectedFilter.value;
                return matchesSearch && matchesFilter;
              }).toList();

              if (filteredList.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _controller.fetchSupplies(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No supplies found',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try adjusting your filters or search query',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _controller.fetchSupplies(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Catalog'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FFB3),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => _controller.fetchSupplies(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return _buildSupplyCard(item);
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSupplyDialog,
        backgroundColor: theme.primaryColor,
        child: Icon(Icons.add, color: theme.scaffoldBackgroundColor),
      ),
    );
  }

  Widget _buildSupplyCard(SupplyItem item) {
    final bool isService = item.natureOfSupplies.toLowerCase() == 'service';
    final Color accentColor = isService
        ? const Color(0xFF448AFF)
        : const Color(0xFF00FFB3);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddSupplyDialog(existingItem: item),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isService
                              ? Icons.auto_awesome_rounded
                              : Icons.inventory_2_rounded,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.productDescription,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Spacer(),
                                _buildPopupMenu(item),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildBadge(
                                  item.itemCode.isNotEmpty
                                      ? item.itemCode
                                      : 'NO CODE',
                                  Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                _buildBadge(item.taxCode, Colors.orangeAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.straighten_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.color?.withOpacity(0.3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unit: ${item.unit}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color?.withOpacity(0.3),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ETB',
                            style: TextStyle(
                              color: accentColor.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            item.unitPrice.toStringAsFixed(2),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPopupMenu(SupplyItem item) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'edit') {
          _showAddSupplyDialog(existingItem: item);
        } else if (value == 'delete') {
          if (item.id != null) {
            _confirmDelete(item.id!);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Edit Item',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
