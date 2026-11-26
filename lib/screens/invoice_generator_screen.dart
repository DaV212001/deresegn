import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/config_preference.dart';
import '../controllers/auth_controller.dart';
import '../controllers/branch_hours_controller.dart';
import '../controllers/invoice_controller.dart';
import '../controllers/invoice_history_controller.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';

class InvoiceGeneratorScreen extends StatefulWidget {
  final String? initialDocumentType;
  final String? initialReferenceIrn;
  final InvoiceSummary? referenceInvoice;

  const InvoiceGeneratorScreen({
    super.key,
    this.initialDocumentType,
    this.initialReferenceIrn,
    this.referenceInvoice,
  });

  @override
  _InvoiceGeneratorScreenState createState() => _InvoiceGeneratorScreenState();
}

class _InvoiceGeneratorScreenState extends State<InvoiceGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _controller = Get.put(InvoiceController());
  final _hoursController = Get.isRegistered<BranchHoursController>()
      ? Get.find<BranchHoursController>()
      : Get.put(BranchHoursController());

  // Input Controllers
  final _tinController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _itemDescController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _itemQtyController = TextEditingController();
  final _itemDiscountController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _incomeWithholdController = TextEditingController(text: '0.00');
  final _txnWithholdController = TextEditingController(text: '0.00');
  final _referenceIrnController = TextEditingController();
  final _reasonController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1.00');
  final _customPaymentTermController = TextEditingController();

  final List<String> _unitOptions = [
    'PCS',
    'PKG',
    'KLG',
    'LTR',
    'MTR',
    'SET',
    'ROL',
    'MTS',
    '101',
  ];

  String _unitLabel(String unit) {
    switch (unit.toUpperCase()) {
      case 'PCS':
        return 'PCS (Pieces)';
      case 'PKG':
        return 'PKG (Package / Box)';
      case 'KLG':
        return 'KLG (Kilograms)';
      case 'LTR':
        return 'LTR (Liters)';
      case 'MTR':
        return 'MTR (Meters)';
      case 'SET':
        return 'SET (Sets)';
      case 'ROL':
        return 'ROL (Rolls)';
      case 'MTS':
        return 'MTS (Metric Tons)';
      case '101':
        return '101 (Standard Unit)';
      default:
        return unit;
    }
  }

  final String _selectedNature = 'goods';
  final String _selectedUnit = 'PCS';
  bool _isWalkIn = false;
  bool _applyWithholding = false;
  bool _customWithholdingOverride = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.referenceInvoice != null ? 2 : 0,
    );
    _tinController.addListener(
      () => _controller.buyerTin.value = _tinController.text == '0000000000'
          ? ''
          : _tinController.text,
    );
    _nameController.addListener(
      () => _controller.buyerName.value = _nameController.text,
    );
    _phoneController.addListener(
      () => _controller.buyerPhone.value = _phoneController.text,
    );
    _emailController.addListener(
      () => _controller.buyerEmail.value = _emailController.text,
    );
    _incomeWithholdController.addListener(
      () => _controller.incomeWithholdValue.value =
          _incomeWithholdController.text,
    );
    _txnWithholdController.addListener(
      () => _controller.txnWithholdValue.value = _txnWithholdController.text,
    );
    _referenceIrnController.addListener(
      () => _controller.referenceIrn.value = _referenceIrnController.text,
    );
    _reasonController.addListener(
      () => _controller.adjustmentReason.value = _reasonController.text,
    );
    _exchangeRateController.addListener(
      () => _controller.exchangeRate.value = _exchangeRateController.text,
    );
    _customPaymentTermController.addListener(
      () => _controller.customPaymentTerm.value = _customPaymentTermController.text,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialDocumentType != null) {
        _controller.documentType.value = widget.initialDocumentType!;
      }
      if (widget.referenceInvoice != null) {
        _controller.setReferenceInvoice(widget.referenceInvoice!);
        _referenceIrnController.text = widget.referenceInvoice!.irn ?? '';
        _tinController.text = _controller.buyerTin.value;
        _nameController.text = _controller.buyerName.value;
        _phoneController.text = _controller.buyerPhone.value;
        _emailController.text = _controller.buyerEmail.value;
      } else if (widget.initialReferenceIrn != null) {
        _referenceIrnController.text = widget.initialReferenceIrn!;
        _controller.referenceIrn.value = widget.initialReferenceIrn!;
      }
    });

    // Reset local UI controllers ONLY when clearForm() is triggered after invoice submission
    ever(_controller.formResetSignal, (_) {
      if (!mounted) return;
      _tinController.clear();
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _itemDescController.clear();
      _itemPriceController.clear();
      _itemQtyController.clear();
      _itemDiscountController.clear();
      _itemCodeController.clear();
      _referenceIrnController.clear();
      _reasonController.clear();
      _exchangeRateController.text = '1.00';
      _customPaymentTermController.clear();
      _incomeWithholdController.text = '0.00';
      _txnWithholdController.text = '0.00';
      setState(() {
        _isWalkIn = false;
        _tabController.animateTo(0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'new_invoice'.tr,
          style: TextStyle(
            color:
                theme.appBarTheme.foregroundColor ??
                theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            letterSpacing: 1,
          ),
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey.withOpacity(0.6),
          tabs: [
            Tab(text: 'buyer_tab'.tr),
            Tab(text: 'items_tab'.tr),
            Tab(text: 'summary_tab'.tr),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuyerTab(),
          _buildItemsTab(),
          _buildSummaryTab(context),
        ],
      ),
    );
  }

  Widget _buildBuyerTab() {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CopyAccessTokenWidget(),
          Obx(() {
            final isRefLocked = _controller.selectedReferenceInvoice.value != null;
            final refInv = _controller.selectedReferenceInvoice.value;

            return Container(
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
                          isRefLocked ? Icons.lock_outline_rounded : Icons.person_search_rounded,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'customer_info'.tr,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    ],
                  ),
                  if (isRefLocked && refInv != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Buyer details are locked to original invoice #${refInv.documentNumber ?? refInv.id}.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildTextField(
                    'buyer_tin'.tr,
                    _tinController,
                    icon: Icons.badge_outlined,
                    readOnly: isRefLocked,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'buyer_legal_name'.tr,
                    _nameController,
                    icon: Icons.business_outlined,
                    readOnly: isRefLocked,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'buyer_phone'.tr,
                    _phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    readOnly: isRefLocked,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'buyer_email'.tr,
                    _emailController,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: isRefLocked,
                  ),
                  if (!isRefLocked) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isWalkIn = !_isWalkIn;
                          if (_isWalkIn) {
                            _tinController.text = '0000000000';
                            _nameController.text = 'Walking';
                            _phoneController.clear();
                            _emailController.clear();
                          } else {
                            _tinController.text = '';
                            _nameController.text = '';
                            _phoneController.clear();
                            _emailController.clear();
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
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'walk_in_customer'.tr,
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
          Obx(() {
            final isRef = _controller.selectedReferenceInvoice.value != null;
            if (isRef) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _tabController.animateTo(2),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'review_summary'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Adjust Line Items (Optional)'),
                  ),
                ],
              );
            }
            return ElevatedButton(
              onPressed: () {
                final txnType = _controller.transactionType.value;
                if ((txnType == 'B2B' || txnType == 'B2G') && !_isWalkIn) {
                  if (_tinController.text.trim().length != 10) {
                    Get.snackbar(
                      'Validation Error',
                      'B2B/B2G transactions require a valid 10-digit Buyer TIN.',
                      backgroundColor: Colors.red.withOpacity(0.2),
                      colorText: Colors.red,
                    );
                    return;
                  }
                }
                _tabController.animateTo(1);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'continue_to_items'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}

  Widget _buildItemsTab() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Action Header Bar: Title, Count Badge, and "+ Add Item" CTA
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'line_items'.tr,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_controller.items.length}',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showItemBottomSheet(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'add_item'.tr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: theme.dividerColor, height: 1),

        // Main Items Area: Full-screen list or empty state
        Expanded(
          child: Obx(() {
            if (_controller.items.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 56,
                          color: theme.primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Items Added Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to add products or services to this invoice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showItemBottomSheet(),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text('add_item'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: _controller.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _controller.items[index];
                return _buildInvoiceItemCard(item, index);
              },
            );
          }),
        ),

        // Docked Bottom Summary Bar
        Obx(() {
          final hasItems = _controller.items.isNotEmpty;
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, -3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_controller.items.length} ${_controller.items.length == 1 ? "Item" : "Items"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_controller.grandTotal.toStringAsFixed(2)} ETB',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: hasItems
                      ? () => _tabController.animateTo(2)
                      : () {
                          Get.snackbar(
                            'Items Required',
                            'Please add at least one item before proceeding.',
                            backgroundColor: Colors.orange.withValues(alpha: 0.2),
                            colorText: Colors.orange.shade900,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: hasItems ? null : Colors.grey.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'review_summary'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInvoiceItemCard(InvoiceItem item, int index) {
    final theme = Theme.of(context);
    final isService = item.natureOfSupplies.toLowerCase().contains('serv') || item.natureOfSupplies.toLowerCase() == 's';

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _showItemBottomSheet(itemToEdit: item, editIndex: index),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left Primary Accent Strip
                Container(width: 4.5, color: theme.primaryColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Description, Item Code, Edit & Delete buttons
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.itemCode.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Code: ${item.itemCode}',
                                        style: TextStyle(
                                          color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Edit Action Icon
                            InkWell(
                              onTap: () => _showItemBottomSheet(itemToEdit: item, editIndex: index),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: theme.primaryColor,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Delete Action Icon
                            InkWell(
                              onTap: () {
                                final removedItem = item;
                                _controller.removeItem(index);
                                Get.snackbar(
                                  'Item Removed',
                                  '${removedItem.description} was removed.',
                                  mainButton: TextButton(
                                    onPressed: () {
                                      _controller.items.insert(index, removedItem);
                                      if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
                                    },
                                    child: const Text('UNDO', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  duration: const Duration(seconds: 4),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.red,
                                  size: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Badges Row: Nature, Tax, Excise, Discount
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Nature Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isService
                                    ? Colors.purple.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isService ? 'አገልግሎት / Service' : 'ዕቃዎች / Goods',
                                style: TextStyle(
                                  color: isService ? Colors.purple.shade700 : Colors.blue.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Tax Category Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.taxCategory.description,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Excise Tax Pill (if applicable)
                            if (item.isExciseTaxable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'VAT + EXC ${(item.exciseRate * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            // Discount Pill (if applicable)
                            if (item.discount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Disc: -${item.discount.toStringAsFixed(2)} ETB',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bottom Actions: Quantity Stepper (- 1 +), Unit Price, and Line Total
                        Row(
                          children: [
                            // Quantity Stepper
                            Container(
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Decrement button
                                  InkWell(
                                    onTap: () {
                                      if (item.quantity > 1) {
                                        setState(() {
                                          item.quantity -= 1;
                                        });
                                        _controller.items[index] = item;
                                      } else {
                                        _controller.removeItem(index);
                                      }
                                    },
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.remove_rounded, size: 16),
                                    ),
                                  ),
                                  // Quantity Text
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Text(
                                      '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(1)} ${item.unit}',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  // Increment button
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        item.quantity += 1;
                                      });
                                      _controller.items[index] = item;
                                    },
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.add_rounded, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Unit Price & Total Amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '@ ${item.unitPrice.toStringAsFixed(2)} ETB',
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.totalLineAmount.toStringAsFixed(2)} ETB',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showItemBottomSheet({InvoiceItem? itemToEdit, int? editIndex}) {
    final theme = Theme.of(context);
    final isEditing = itemToEdit != null;

    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final priceCtrl = TextEditingController(
      text: itemToEdit != null ? itemToEdit.unitPrice.toString() : '',
    );
    final qtyCtrl = TextEditingController(
      text: itemToEdit != null
          ? (itemToEdit.quantity % 1 == 0
              ? itemToEdit.quantity.toInt().toString()
              : itemToEdit.quantity.toString())
          : '1',
    );
    final discountCtrl = TextEditingController(
      text: itemToEdit != null && itemToEdit.discount > 0
          ? itemToEdit.discount.toString()
          : '',
    );
    String selectedNature = itemToEdit != null
        ? InvoiceController.sanitizeNatureOfSupplies(itemToEdit.natureOfSupplies)
        : InvoiceController.sanitizeNatureOfSupplies(_selectedNature);
    String selectedUnit = itemToEdit != null
        ? InvoiceController.sanitizeUnit(itemToEdit.unit)
        : InvoiceController.sanitizeUnit(_selectedUnit);
    TaxCategory selectedTax = itemToEdit != null
        ? itemToEdit.taxCategory
        : _controller.selectedTaxCategory.value;
    String itemCode = itemToEdit?.itemCode ?? '';
    double exciseRate = itemToEdit?.exciseRate ?? 0.0;
    bool isExciseTaxable = itemToEdit?.isExciseTaxable ?? false;
    bool saveToCatalog = false;
    bool isFromCatalog = itemToEdit != null && itemToEdit.itemCode.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Live line calculation
            final currentPrice = double.tryParse(priceCtrl.text) ?? 0.0;
            final currentQty = double.tryParse(qtyCtrl.text) ?? 0.0;
            final currentDiscount = double.tryParse(discountCtrl.text) ?? 0.0;
            final net = currentPrice * currentQty;
            final afterDisc = (net - currentDiscount).clamp(0.0, double.infinity);
            final excise = isExciseTaxable ? afterDisc * exciseRate : 0.0;
            final vatBase = afterDisc + excise;
            final vat = vatBase * selectedTax.rate;
            final liveTotal = vatBase + vat;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle & Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Edit Line Item' : 'Add Line Item',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(color: theme.dividerColor, height: 1),

                  // Scrollable Form Fields
                  Flexible(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Autocomplete Search Field
                          Autocomplete<SupplyItem>(
                            initialValue: TextEditingValue(text: descCtrl.text),
                            displayStringForOption: (option) => option.productDescription,
                            optionsBuilder: (TextEditingValue textVal) {
                              if (textVal.text.trim().isEmpty) {
                                return const Iterable<SupplyItem>.empty();
                              }
                              return _controller.availableSupplies.where((option) {
                                return option.productDescription.toLowerCase().contains(
                                      textVal.text.toLowerCase(),
                                    );
                              });
                            },
                            onSelected: (SupplyItem selection) {
                              setSheetState(() {
                                descCtrl.text = selection.productDescription;
                                priceCtrl.text = selection.unitPrice.toString();
                                itemCode = selection.itemCode;
                                selectedNature = InvoiceController.sanitizeNatureOfSupplies(selection.natureOfSupplies);
                                selectedUnit = InvoiceController.sanitizeUnit(selection.unit);
                                exciseRate = selection.exciseTaxRate;
                                isExciseTaxable = selection.isExciseTaxable;
                                isFromCatalog = true;
                                selectedTax = taxCategories.firstWhere(
                                  (c) => c.code == selection.taxCode,
                                  orElse: () => taxCategories.first,
                                );
                              });
                            },
                            fieldViewBuilder: (ctx, autocompleteCtrl, focusNode, onSubmit) {
                              autocompleteCtrl.addListener(() {
                                if (descCtrl.text != autocompleteCtrl.text) {
                                  descCtrl.text = autocompleteCtrl.text;
                                  if (isFromCatalog && focusNode.hasFocus) {
                                    setSheetState(() {
                                      isFromCatalog = false;
                                      itemCode = '';
                                    });
                                  }
                                }
                              });
                              return _buildTextFieldCustom(
                                'item_name_search'.tr,
                                autocompleteCtrl,
                                focusNode: focusNode,
                                icon: Icons.search_rounded,
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // Price & Quantity Row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildTextField(
                                  'price'.tr,
                                  priceCtrl,
                                  isNumber: true,
                                  icon: Icons.payments_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  'qty'.tr,
                                  qtyCtrl,
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Discount & Unit Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  'discount'.tr,
                                  discountCtrl,
                                  isNumber: true,
                                  icon: Icons.percent_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDropdownField<String>(
                                  'unit'.tr,
                                  InvoiceController.sanitizeUnit(selectedUnit),
                                  _unitOptions,
                                  (val) => setSheetState(() => selectedUnit = InvoiceController.sanitizeUnit(val)),
                                  itemBuilder: _unitLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Nature of Supplies (Goods vs Services)
                          Text(
                            'nature'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('ዕቃዎች / Goods')),
                                  selected: selectedNature == 'goods',
                                  onSelected: (val) {
                                    if (val) setSheetState(() => selectedNature = 'goods');
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('አገልግሎት / Service')),
                                  selected: selectedNature == 'service',
                                  onSelected: (val) {
                                    if (val) setSheetState(() => selectedNature = 'service');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Tax Category Dropdown
                          _buildDropdownField<TaxCategory>(
                            'tax'.tr,
                            selectedTax,
                            taxCategories,
                            (val) {
                              if (val != null) {
                                setSheetState(() => selectedTax = val);
                              }
                            },
                            itemBuilder: (cat) => cat.description,
                          ),

                          // Excise Tax Indicator (if applicable)
                          if (isExciseTaxable) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Excise Taxable: ${(exciseRate * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Save to Catalog Option (if new item)
                          if (!isEditing &&
                              descCtrl.text.isNotEmpty &&
                              !_controller.availableSupplies.any(
                                (s) => s.productDescription.toLowerCase() == descCtrl.text.toLowerCase(),
                              )) ...[
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () => setSheetState(() => saveToCatalog = !saveToCatalog),
                              child: Row(
                                children: [
                                  Icon(
                                    saveToCatalog ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    color: saveToCatalog ? theme.primaryColor : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'save_to_catalog'.tr,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Real-time Line Total Calculation Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Line Total Preview',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currentQty.toStringAsFixed(0)} × ${currentPrice.toStringAsFixed(2)} ETB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${liveTotal.toStringAsFixed(2)} ETB',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Save / Update Button
                          ElevatedButton(
                            onPressed: () {
                              final desc = descCtrl.text.trim();
                              final price = double.tryParse(priceCtrl.text) ?? 0.0;
                              final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                              final discount = double.tryParse(discountCtrl.text) ?? 0.0;

                              if (desc.isEmpty) {
                                Get.snackbar(
                                  'Validation Error',
                                  'Item description is required.',
                                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                                  colorText: Colors.red,
                                );
                                return;
                              }
                              if (price <= 0) {
                                Get.snackbar(
                                  'Validation Error',
                                  'Price must be greater than zero.',
                                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                                  colorText: Colors.red,
                                );
                                return;
                              }
                              if (qty <= 0) {
                                Get.snackbar(
                                  'Validation Error',
                                  'Quantity must be greater than zero.',
                                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                                  colorText: Colors.red,
                                );
                                return;
                              }

                              final newItem = InvoiceItem(
                                description: desc,
                                unitPrice: price,
                                quantity: qty,
                                discount: discount,
                                taxCategory: selectedTax,
                                natureOfSupplies: selectedNature,
                                unit: selectedUnit,
                                itemCode: itemCode,
                                exciseRate: exciseRate,
                                isExciseTaxable: isExciseTaxable,
                              );

                              if (isEditing) {
                                _controller.items[editIndex!] = newItem;
                              } else {
                                _controller.items.add(newItem);
                                if (saveToCatalog) {
                                  _controller.saveItemToCatalog(newItem);
                                }
                              }

                              Navigator.pop(sheetContext);
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              isEditing ? 'Update Line Item' : 'add_item'.tr,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
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
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'invoice_summary'.tr,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryRow(
                    'subtotal'.tr,
                    '${_controller.totalPreTax.toStringAsFixed(2)} ETB',
                  ),
                  _buildSummaryRow(
                    'tax_amount'.tr,
                    '${_controller.totalVat.toStringAsFixed(2)} ETB',
                    highlight: true,
                  ),
                  if (_controller.totalExcise > 0)
                    _buildSummaryRow(
                      'excise_tax'.tr,
                      '${_controller.totalExcise.toStringAsFixed(2)} ETB',
                    ),
                  if (_controller.totalDiscount > 0)
                    _buildSummaryRow(
                      'discount'.tr,
                      '${_controller.totalDiscount.toStringAsFixed(2)} ETB',
                      highlight: true,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                      height: 1,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'total_payable'.tr,
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_controller.grandTotal.toStringAsFixed(2)} ETB',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'additional_details'.tr,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField<String>(
                    'transaction_type'.tr,
                    _controller.transactionType.value,
                    ['B2C', 'B2B', 'B2G', 'B2E'],
                    (val) => _controller.transactionType.value = val!,
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => _buildDropdownField<String>(
                      'Document Type',
                      _controller.documentType.value,
                      [
                        'CASH_SALE',
                        'CREDIT_SALE',
                        'CREDIT_NOTE',
                        'DEBIT_NOTE',
                        'WITHHOLDING_RECEIPT',
                      ],
                      (val) {
                        _controller.documentType.value = val!;
                        if (val == 'CASH_SALE') {
                          _controller.paymentMode.value = 'CASH';
                          _controller.paymentTerm.value = 'IMMEDIATE';
                        } else if (val == 'CREDIT_SALE') {
                          _controller.paymentMode.value = 'CREDIT';
                          _controller.paymentTerm.value = 'Net 30';
                        }
                      },
                      itemBuilder: (type) {
                        switch (type) {
                          case 'CASH_SALE':
                            return 'cash_sale'.tr;
                          case 'CREDIT_SALE':
                            return 'credit_sale'.tr;
                          case 'CREDIT_NOTE':
                            return 'credit_note'.tr;
                          case 'DEBIT_NOTE':
                            return 'debit_note'.tr;
                          case 'WITHHOLDING_RECEIPT':
                            return 'withholding_receipt'.tr;
                          default:
                            return type;
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    if (_controller.documentType.value == 'CREDIT_NOTE' ||
                        _controller.documentType.value == 'DEBIT_NOTE' ||
                        _controller.documentType.value == 'WITHHOLDING_RECEIPT') {
                      final selectedInv = _controller.selectedReferenceInvoice.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _referenceIrnController,
                              readOnly: selectedInv != null,
                              style: TextStyle(
                                color: selectedInv != null
                                    ? Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6)
                                    : Theme.of(context).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Reference Invoice IRN',
                                labelStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: selectedInv != null
                                    ? Theme.of(context).disabledColor.withValues(alpha: 0.05)
                                    : Theme.of(context).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.link_rounded),
                                suffixIcon: selectedInv != null
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 12),
                                        child: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.content_paste_rounded, size: 20),
                                            tooltip: 'Paste IRN from clipboard',
                                            onPressed: () async {
                                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                                              if (data?.text != null && data!.text!.trim().isNotEmpty) {
                                                _referenceIrnController.text = data.text!.trim();
                                                _controller.referenceIrn.value = data.text!.trim();
                                                Get.snackbar(
                                                  'Pasted',
                                                  'IRN pasted from clipboard',
                                                  snackPosition: SnackPosition.BOTTOM,
                                                  duration: const Duration(seconds: 2),
                                                );
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.history_rounded, size: 20),
                                            tooltip: 'Select from previous invoices',
                                            onPressed: () => _showInvoiceSelectionModal(context),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showInvoiceSelectionModal(context),
                              icon: const Icon(Icons.receipt_long_rounded, size: 18),
                              label: const Text('Select from Previous Invoices'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                            if (selectedInv != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Referencing: Doc #${selectedInv.documentNumber ?? selectedInv.id}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                          Text(
                                            '${selectedInv.buyer.legalName ?? 'Buyer'} • ${selectedInv.totals.totalValue ?? '0.00'} ETB',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      tooltip: 'Clear Reference',
                                      onPressed: () {
                                        _controller.clearReferenceInvoice();
                                        _referenceIrnController.clear();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _buildTextField(
                              _controller.documentType.value == 'WITHHOLDING_RECEIPT'
                                  ? 'Withholding Reason / Description'
                                  : 'adjustment_reason'.tr,
                              _reasonController,
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField<String>(
                            'currency'.tr,
                            _controller.invoiceCurrency.value,
                            ['ETB', 'USD', 'EUR', 'GBP'],
                            (val) => _controller.invoiceCurrency.value = val!,
                          ),
                        ),
                        if (_controller.invoiceCurrency.value != 'ETB') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'exchange_rate'.tr,
                              _exchangeRateController,
                              isNumber: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildPaymentDetailsCard(context),
                  Obx(() {
                    final theme = Theme.of(context);
                    double goodsTotal = 0.0;
                    double servicesTotal = 0.0;
                    for (final item in _controller.items) {
                      final preTax = item.afterDiscount;
                      if (item.natureOfSupplies.toLowerCase().contains('serv')) {
                        servicesTotal += preTax;
                      } else {
                        goodsTotal += preTax;
                      }
                    }

                    final bool qualifiesGoods = goodsTotal >= 20000.0;
                    final bool qualifiesServices = servicesTotal >= 10000.0;
                    final bool qualifiesForWithholding =
                        (qualifiesGoods || qualifiesServices) && !_isWalkIn;

                    double qualifyingBase = 0.0;
                    if (qualifiesGoods) qualifyingBase += goodsTotal;
                    if (qualifiesServices) qualifyingBase += servicesTotal;

                    final double auto3Percent =
                        double.parse((qualifyingBase * 0.03).toStringAsFixed(2));

                    if (!qualifiesForWithholding) {
                      if (_incomeWithholdController.text != '0.00' &&
                          !_customWithholdingOverride) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _incomeWithholdController.text = '0.00';
                            _txnWithholdController.text = '0.00';
                          }
                        });
                      }
                      return const SizedBox.shrink();
                    }

                    // Auto-sync 3% amount if withholding is active and not overridden
                    if (_applyWithholding && !_customWithholdingOverride) {
                      final currentText = _incomeWithholdController.text;
                      final expectedText = auto3Percent.toStringAsFixed(2);
                      if (currentText != expectedText) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _applyWithholding && !_customWithholdingOverride) {
                            _incomeWithholdController.text = expectedText;
                          }
                        });
                      }
                    }

                    final String thresholdReason = qualifiesGoods && qualifiesServices
                        ? 'Goods (≥ 20,000 ETB) and Services (≥ 10,000 ETB) qualify for 3% withholding'
                        : (qualifiesGoods
                            ? 'Goods total (${goodsTotal.toStringAsFixed(2)} ETB) qualifies for 3% withholding (threshold ≥ 20,000 ETB)'
                            : 'Services total (${servicesTotal.toStringAsFixed(2)} ETB) qualifies for 3% withholding (threshold ≥ 10,000 ETB)');

                    return Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _applyWithholding
                              ? theme.primaryColor.withOpacity(0.5)
                              : theme.dividerColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.percent,
                                            size: 18, color: theme.primaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Statutory Withholding (3%)',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.textTheme.bodyLarge?.color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      thresholdReason,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _applyWithholding,
                                activeColor: theme.primaryColor,
                                onChanged: (val) {
                                  setState(() {
                                    _applyWithholding = val;
                                    if (val) {
                                      _incomeWithholdController.text =
                                          auto3Percent.toStringAsFixed(2);
                                    } else {
                                      _incomeWithholdController.text = '0.00';
                                      _txnWithholdController.text = '0.00';
                                      _customWithholdingOverride = false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_applyWithholding) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Taxable Base for Withholding:',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${qualifyingBase.toStringAsFixed(2)} ETB',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Withheld Tax (3% MoR Rate):',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_incomeWithholdController.text} ETB',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _customWithholdingOverride =
                                          !_customWithholdingOverride;
                                    });
                                  },
                                  child: Text(
                                    _customWithholdingOverride
                                        ? 'Use Auto 3% Calculation'
                                        : 'Custom Withholding / VAT Withholding',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_customWithholdingOverride) ...[
                              const SizedBox(height: 6),
                              _buildTextField(
                                'income_withholding'.tr,
                                _incomeWithholdController,
                                isNumber: true,
                              ),
                              const SizedBox(height: 10),
                              _buildTextField(
                                'transaction_withholding'.tr,
                                _txnWithholdController,
                                isNumber: true,
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                  if (_controller.generatedQrCode.value.isNotEmpty)
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
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
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color?.withOpacity(0.3),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Obx(() {
                    final status = _hoursController.currentStatus.value;
                    if (status.isOpen) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade800.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: Colors.amber.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outside Operating Hours',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  status.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Obx(() {
                    final bool isSubmitting = _controller.isSubmitting.value;
                    final bool isMorAuth = Get.isRegistered<AuthController>() &&
                        Get.find<AuthController>().isMorAuthenticating.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  if (!_hoursController.isCurrentlyOpen()) {
                                    _hoursController.showClosedDialog(context);
                                    return;
                                  }
                                  if (!_controller.checkActiveSubscriptionOrPromptPayment()) {
                                    return;
                                  }
                                  _controller.registerFormInvoice(context);
                                },
                          child: isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      isMorAuth
                                          ? 'Connecting to MoR...'
                                          : 'Submitting...',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _controller.documentType.value == 'WITHHOLDING_RECEIPT'
                                      ? 'Issue Withholding Receipt'
                                      : (_controller.documentType.value == 'CREDIT_NOTE'
                                          ? 'Issue Credit Note (CRE)'
                                          : (_controller.documentType.value == 'DEBIT_NOTE'
                                              ? 'Issue Debit Note (DEB)'
                                              : 'submit_invoice'.tr)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  if (!_hoursController.isCurrentlyOpen()) {
                                    _hoursController.showClosedDialog(context);
                                    return;
                                  }
                                  if (!_controller.checkActiveSubscriptionOrPromptPayment()) {
                                    return;
                                  }
                                  _controller.registerSampleInvoice(context);
                                },
                          child: Text(
                            'Post Test Transaction',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color?.withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceSelectionModal(BuildContext context) {
    final historyController = Get.isRegistered<InvoiceHistoryController>()
        ? Get.find<InvoiceHistoryController>()
        : Get.put(InvoiceHistoryController());

    if (historyController.invoices.isEmpty && !historyController.isLoading.value) {
      historyController.fetchInvoices(refresh: true);
    }

    final searchController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchController.text.trim().toLowerCase();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Obx(() {
                  final allInvoices = historyController.invoices.where((inv) {
                    return inv.irn != null && inv.irn!.isNotEmpty;
                  }).toList();

                  final filtered = query.isEmpty
                      ? allInvoices
                      : allInvoices.where((inv) {
                          final docMatch = (inv.documentNumber ?? '').toLowerCase().contains(query);
                          final nameMatch = (inv.buyer.legalName ?? '').toLowerCase().contains(query);
                          final irnMatch = (inv.irn ?? '').toLowerCase().contains(query);
                          return docMatch || nameMatch || irnMatch;
                        }).toList();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Reference Invoice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        Text(
                          'Choose an existing sales invoice to reference for this adjustment note',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search by Doc #, Buyer Name, or IRN...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      searchController.clear();
                                      setSheetState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (historyController.isLoading.value)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (filtered.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    query.isEmpty ? 'No previous invoices available.' : 'No invoices match "$query"',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final inv = filtered[index];
                                final isSelected = _controller.referenceIrn.value == inv.irn;

                                return InkWell(
                                  onTap: () {
                                    _controller.setReferenceInvoice(inv);
                                    _referenceIrnController.text = inv.irn ?? '';
                                    _tinController.text = _controller.buyerTin.value;
                                    _nameController.text = _controller.buyerName.value;
                                    _phoneController.text = _controller.buyerPhone.value;
                                    _emailController.text = _controller.buyerEmail.value;
                                    Navigator.pop(ctx);
                                    Get.snackbar(
                                      'Invoice Referenced',
                                      'Referenced Doc #${inv.documentNumber ?? inv.id}. Buyer, items, and payment terms synchronized.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: theme.primaryColor.withOpacity(0.15),
                                      colorText: theme.primaryColor,
                                      duration: const Duration(seconds: 3),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.primaryColor.withOpacity(0.08)
                                          : theme.scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? theme.primaryColor : theme.dividerColor,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: theme.primaryColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Invoice #${inv.documentNumber ?? inv.id}',
                                                    style: TextStyle(
                                                      color: theme.primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  inv.transactionType ?? 'B2B',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${inv.totals.totalValue ?? '0.00'} ETB',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: theme.textTheme.bodyLarge?.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          inv.buyer.legalName ?? 'Walking Customer',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.fingerprint_rounded, size: 12, color: Colors.blue.shade700),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'IRN: ${inv.irn ?? 'N/A'}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                          ),
                      ],
                    ),
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    IconData? icon,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return _buildTextFieldCustom(
      label,
      controller,
      isNumber: isNumber,
      icon: icon,
      readOnly: readOnly,
      keyboardType: keyboardType,
    );
  }

  Widget _buildTextFieldCustom(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    FocusNode? focusNode,
    IconData? icon,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      scrollPadding: const EdgeInsets.only(bottom: 120, top: 20),
      keyboardType: keyboardType ??
          (isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text),
      style: TextStyle(
        color: readOnly
            ? Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6)
            : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
          fontSize: 14,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: Theme.of(context).primaryColor, size: 20)
            : null,
        suffixIcon: readOnly
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
              )
            : null,
        filled: true,
        fillColor: readOnly
            ? Theme.of(context).disabledColor.withValues(alpha: 0.05)
            : Theme.of(context).inputDecorationTheme.fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1,
          ),
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
    final effectiveItems = items.contains(value) ? items : [value, ...items];
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: Theme.of(context).cardColor,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: effectiveItems.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            itemBuilder != null ? itemBuilder(item) : item.toString(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
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
              color: highlight
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _customPaymentTermController.dispose();
    super.dispose();
  }

  Widget _buildPaymentDetailsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      if (_controller.documentType.value == 'WITHHOLDING_RECEIPT') {
        return const SizedBox.shrink();
      }

      final isCreditSale = _controller.documentType.value == 'CREDIT_SALE';
      final isNote = _controller.documentType.value == 'CREDIT_NOTE' ||
          _controller.documentType.value == 'DEBIT_NOTE';
      final currentMode = _controller.paymentMode.value;
      final currentTerm = _controller.paymentTerm.value;

      String termLabel(String term) {
        switch (term) {
          case 'IMMEDIATE':
            return 'Immediate (ወዲያውኑ)';
          case 'Cash on Delivery':
            return 'Cash on Delivery (COD)';
          case 'Payment in Advance':
            return 'Payment in Advance';
          case 'Net 30':
            return 'Net 30 (30 Days from Invoice)';
          case 'Net 15':
            return 'Net 15 (15 Days from Invoice)';
          case 'End of Month':
            return 'End of Month';
          case 'CREDIT':
            return 'Standard Credit';
          case 'Custom':
            return 'Custom Agreed Terms...';
          default:
            return term;
        }
      }

      if (isNote && _controller.selectedReferenceInvoice.value != null) {
        final refDocNum = _controller.selectedReferenceInvoice.value?.documentNumber ??
            _controller.selectedReferenceInvoice.value?.id.toString() ?? '';

        String modeDisplay;
        if (currentMode == 'CREDIT') {
          modeDisplay = 'Credit (ዱቤ)';
        } else if (currentMode == 'DIRECT_TRANSFER') {
          modeDisplay = 'Direct Transfer (የባንክ ዝውውር)';
        } else {
          modeDisplay = 'Cash (እጅ በእጅ)';
        }

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'mode_of_payment'.tr,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.inputDecorationTheme.fillColor ?? theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: theme.primaryColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            modeDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentTerm.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.inputDecorationTheme.fillColor ?? theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: theme.primaryColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              termLabel(currentTerm),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Automatically matched with original invoice #$refDocNum.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                ),
              ),
            ],
          ),
        );
      }

      final List<String> termOptions;
      if (currentMode == 'CREDIT' || isCreditSale) {
        termOptions = ['Net 30', 'Net 15', 'End of Month', 'CREDIT'];
        if (currentTerm.isNotEmpty && !termOptions.contains(currentTerm) && currentTerm != 'Custom') {
          termOptions.add(currentTerm);
        }
        termOptions.add('Custom');
      } else {
        termOptions = ['IMMEDIATE', 'Cash on Delivery', 'Payment in Advance'];
        if (currentTerm.isNotEmpty && !termOptions.contains(currentTerm) && currentTerm != 'Custom') {
          termOptions.add(currentTerm);
        }
        termOptions.add('Custom');
      }

      final selectedTermValue = termOptions.contains(currentTerm)
          ? currentTerm
          : (termOptions.contains('Custom') ? 'Custom' : termOptions.first);

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'mode_of_payment'.tr,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Cash (እጅ በእጅ)'),
                  selected: currentMode == 'CASH',
                  onSelected: (selected) {
                    if (selected) {
                      _controller.paymentMode.value = 'CASH';
                      _controller.paymentTerm.value = 'IMMEDIATE';
                      if (_controller.documentType.value == 'CREDIT_SALE') {
                        _controller.documentType.value = 'CASH_SALE';
                      }
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Credit (ዱቤ)'),
                  selected: currentMode == 'CREDIT' || isCreditSale,
                  onSelected: (selected) {
                    if (selected) {
                      _controller.paymentMode.value = 'CREDIT';
                      _controller.paymentTerm.value = 'Net 30';
                      _controller.documentType.value = 'CREDIT_SALE';
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Direct Transfer (የባንክ ዝውውር)'),
                  selected: currentMode == 'DIRECT_TRANSFER',
                  onSelected: (selected) {
                    if (selected) {
                      _controller.paymentMode.value = 'DIRECT_TRANSFER';
                      _controller.paymentTerm.value = 'IMMEDIATE';
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Agreed Payment Terms (የክፍያ ስምምነት)',
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedTermValue,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: termOptions.map((t) {
                return DropdownMenuItem<String>(
                  value: t,
                  child: Text(termLabel(t), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  _controller.paymentTerm.value = val;
                }
              },
            ),
            if (selectedTermValue == 'Custom') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customPaymentTermController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Custom Terms (e.g. 10/15, N/30 or Cash on Delivery)',
                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            
          ],
        ),
      );
    });
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
            child: Text(
              'Copy Access Token',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
            child: Text(
              'Copy Refresh Token',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
    );
  }
}
