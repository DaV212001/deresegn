import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/config_preference.dart';
import '../controllers/invoice_controller.dart';
import '../models/invoice_models.dart';

class InvoiceGeneratorScreen extends StatefulWidget {
  const InvoiceGeneratorScreen({super.key});

  @override
  _InvoiceGeneratorScreenState createState() => _InvoiceGeneratorScreenState();
}

class _InvoiceGeneratorScreenState extends State<InvoiceGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _controller = Get.put(InvoiceController());

  // Input Controllers
  final _tinController = TextEditingController();
  final _nameController = TextEditingController();

  final _itemDescController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _itemQtyController = TextEditingController();
  final _itemDiscountController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _incomeWithholdController = TextEditingController(text: '0.00');
  final _txnWithholdController = TextEditingController(text: '0.00');

  final List<String> _natureOfSuppliesOptions = ['goods', 'service', 'other'];
  final List<String> _unitOptions = ['PCS', 'KG', 'LTR', 'MTR', 'DAY', 'HR'];

  String _selectedNature = 'goods';
  String _selectedUnit = 'PCS';
  double _itemExciseRate = 0.0;
  bool _isExciseTaxable = false;
  bool _saveToCatalog = false;
  bool _isWalkIn = false;
  bool _isFromCatalog = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tinController.addListener(
      () => _controller.buyerTin.value = _tinController.text,
    );
    _nameController.addListener(
      () => _controller.buyerName.value = _nameController.text,
    );
    _itemDescController.addListener(() {
      setState(() {});
    });
    _incomeWithholdController.addListener(
      () => _controller.incomeWithholdValue.value = _incomeWithholdController.text,
    );
    _txnWithholdController.addListener(
      () => _controller.txnWithholdValue.value = _txnWithholdController.text,
    );

    // Clear UI controllers when the controller's state is cleared
    ever(_controller.generatedQrCode, (String qr) {
      if (qr.isNotEmpty) {
        // This is a sign that an invoice was just registered and then the form was cleared
        // Note: generatedQrCode is cleared in _controller.clearForm()
      }
    });

    // Listen to items clearing to reset local UI state
    ever(_controller.items, (list) {
      if (list.isEmpty && _controller.buyerTin.value.isEmpty) {
        _tinController.clear();
        _nameController.clear();
        _itemDescController.clear();
        _itemPriceController.clear();
        _itemQtyController.clear();
        _itemDiscountController.clear();
        _itemCodeController.clear();
        setState(() {
          _isWalkIn = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'New Invoice',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 4.0, color: theme.primaryColor),
            insets: const EdgeInsets.symmetric(horizontal: 48.0),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1,
          ),
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey.withOpacity(0.6),
          tabs: const [
            Tab(text: 'BUYER'),
            Tab(text: 'ITEMS'),
            Tab(text: 'SUMMARY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBuyerTab(), _buildItemsTab(), _buildSummaryTab()],
      ),
    );
  }

  Widget _buildBuyerTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_search_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Customer Info',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  'Buyer TIN',
                  _tinController,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Buyer Legal Name',
                  _nameController,
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isWalkIn = !_isWalkIn;
                      if (_isWalkIn) {
                        _tinController.text = '0000000000';
                        _nameController.text = 'Walking';
                      } else {
                        _tinController.text = '';
                        _nameController.text = '';
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        _isWalkIn
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: _isWalkIn
                            ? const Color(0xFF00FFB3)
                            : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Walk-in Customer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.cardColor,
              foregroundColor: theme.primaryColor,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Items',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Autocomplete<SupplyItem>(
                displayStringForOption: (option) => option.productDescription,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<SupplyItem>.empty();
                  }
                  return _controller.availableSupplies.where((option) {
                    return option.productDescription.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (SupplyItem selection) {
                  _itemDescController.text = selection.productDescription;
                  _itemPriceController.text = selection.unitPrice.toString();
                  _itemCodeController.text = selection.itemCode;
                  setState(() {
                    _selectedNature = selection.natureOfSupplies;
                    _selectedUnit = selection.unit;
                    _itemExciseRate = selection.exciseTaxRate;
                    _isExciseTaxable = selection.isExciseTaxable;
                    _isFromCatalog = true;
                    _controller.selectedTaxCategory.value = taxCategories
                        .firstWhere(
                          (c) => c.code == selection.taxCode,
                          orElse: () => taxCategories.first,
                        );
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      controller.addListener(() {
                        if (_itemDescController.text != controller.text) {
                          _itemDescController.text = controller.text;
                          if (_isFromCatalog && focusNode.hasFocus) {
                            setState(() {
                              _isFromCatalog = false;
                              _itemCodeController.clear();
                            });
                          }
                        }
                      });
                      return _buildTextFieldCustom(
                        'Item Name / Search',
                        controller,
                        focusNode: focusNode,
                        icon: Icons.search_rounded,
                      );
                    },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      'Price',
                      _itemPriceController,
                      isNumber: true,
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      'Qty',
                      _itemQtyController,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      'Discount',
                      _itemDiscountController,
                      isNumber: true,
                      icon: Icons.percent_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => _buildDropdownField<TaxCategory>(
                        'Tax',
                        _controller.selectedTaxCategory.value,
                        taxCategories,
                        (val) => _controller.selectedTaxCategory.value = val!,
                        itemBuilder: (cat) => cat.description,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdownField<String>(
                      'Unit',
                      _selectedUnit,
                      _unitOptions,
                      _isFromCatalog
                          ? null
                          : (val) => setState(() => _selectedUnit = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_itemDescController.text.isNotEmpty &&
                      !_controller.availableSupplies.any(
                        (s) =>
                            s.productDescription.toLowerCase() ==
                            _itemDescController.text.toLowerCase(),
                      )) ...[
                    GestureDetector(
                      onTap: () =>
                          setState(() => _saveToCatalog = !_saveToCatalog),
                      child: Row(
                        children: [
                          Icon(
                            _saveToCatalog
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: _saveToCatalog
                                ? const Color(0xFF00FFB3)
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Save to Catalog',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      final desc = _itemDescController.text;
                      final price =
                          double.tryParse(_itemPriceController.text) ?? 0;
                      final qty = double.tryParse(_itemQtyController.text) ?? 0;
                      final discount = double.tryParse(_itemDiscountController.text) ?? 0;
                      if (desc.isNotEmpty && price > 0 && qty > 0) {
                        final item = InvoiceItem(
                          description: desc,
                          unitPrice: price,
                          quantity: qty,
                          discount: discount,
                          taxCategory: _controller.selectedTaxCategory.value,
                          natureOfSupplies: _selectedNature,
                          unit: _selectedUnit,
                          itemCode: _itemCodeController.text,
                          exciseRate: _itemExciseRate,
                          isExciseTaxable: _isExciseTaxable,
                        );
                        _controller.items.add(item);
                        if (_saveToCatalog) _controller.saveItemToCatalog(item);

                        _itemDescController.clear();
                        _itemPriceController.clear();
                        _itemQtyController.clear();
                        _itemDiscountController.clear();
                        _itemCodeController.clear();
                        setState(() {
                          _isFromCatalog = false;
                          _saveToCatalog = false;
                          _itemExciseRate = 0.0;
                          _isExciseTaxable = false;
                        });
                        FocusScope.of(context).unfocus();
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFB3),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: Obx(
            () => ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _controller.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _controller.items[index];
                return _buildInvoiceItemCard(item, index);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () => _tabController.animateTo(2),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F1F1F),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Review Summary',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceItemCard(InvoiceItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: const Color(0xFF00FFB3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (item.isExciseTaxable)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'VAT + EXC',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _controller.removeItem(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.quantity.toStringAsFixed(0)} ${item.unit} x ${item.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${item.totalLineAmount.toStringAsFixed(2)} ETB',
                            style: const TextStyle(
                              color: Color(0xFF00FFB3),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFB3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF00FFB3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Invoice Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryRow(
                    'Subtotal',
                    '${_controller.totalPreTax.toStringAsFixed(2)} ETB',
                  ),
                  _buildSummaryRow(
                    'Tax Amount',
                    '${_controller.totalVat.toStringAsFixed(2)} ETB',
                    highlight: true,
                  ),
                  if (_controller.totalExcise > 0)
                    _buildSummaryRow(
                      'Excise Tax',
                      '${_controller.totalExcise.toStringAsFixed(2)} ETB',
                    ),
                  if (_controller.totalDiscount > 0)
                    _buildSummaryRow(
                      'Discount',
                      '${_controller.totalDiscount.toStringAsFixed(2)} ETB',
                      highlight: true,
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_controller.grandTotal.toStringAsFixed(2)} ETB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Additional Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildDropdownField<String>(
                    'Transaction Type',
                    _controller.transactionType.value,
                    ['B2C', 'B2B', 'B2G', 'B2E'],
                    (val) => _controller.transactionType.value = val!,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Income Withholding',
                    _incomeWithholdController,
                    isNumber: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Transaction Withholding',
                    _txnWithholdController,
                    isNumber: true,
                  ),
                  const SizedBox(height: 32),
                  if (_controller.generatedQrCode.value.isNotEmpty)
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: QrImageView(
                              data: _controller.generatedQrCode.value,
                              size: 140,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            'IRN: ${_controller.generatedQrCode.value}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _controller.isSubmitting.value
                        ? null
                        : () => _controller.registerFormInvoice(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFB3),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF00FFB3).withOpacity(0.4),
                    ),
                    child: _controller.isSubmitting.value
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Submit Invoice',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _controller.isSubmitting.value
                        ? null
                        : () => _controller.registerSampleInvoice(),
                    child: Text(
                      'Post Test Transaction',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    IconData? icon,
  }) {
    return _buildTextFieldCustom(
      label,
      controller,
      isNumber: isNumber,
      icon: icon,
    );
  }

  Widget _buildTextFieldCustom(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    FocusNode? focusNode,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 14,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF00FFB3), size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFF181818),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FFB3), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    T value,
    List<T> items,
    void Function(T?)? onChanged, {
    String Function(T)? itemBuilder,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: const Color(0xFF1F1F1F),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFF181818),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FFB3), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemBuilder != null ? itemBuilder(item) : item.toString(),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool highlight = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFFF3366) : Colors.white,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

class CopyAccessTokenWidget extends StatelessWidget {
  final Widget? child;

  const CopyAccessTokenWidget({super.key, this.child});

  void _copyToken(BuildContext context) async {
    final token = ConfigPreference.getAccessToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No access token found')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: token));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Access token copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _copyToken(context),
      child:
          child ??
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Copy Access Token',
              style: TextStyle(color: Colors.white),
            ),
          ),
    );
  }
}

class CopyRefreshTokenWidget extends StatelessWidget {
  final Widget? child;

  const CopyRefreshTokenWidget({super.key, this.child});

  void _copyToken(BuildContext context) async {
    final token = ConfigPreference.getRefreshToken();

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No access token found')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: token));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Access token copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _copyToken(context),
      child:
          child ??
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Copy Refresh Token',
              style: TextStyle(color: Colors.white),
            ),
          ),
    );
  }
}
