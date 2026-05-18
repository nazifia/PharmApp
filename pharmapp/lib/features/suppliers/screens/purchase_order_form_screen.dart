import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../providers/purchase_order_provider.dart';

class _POLineItem {
  int? itemId;
  String itemName = '';
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();

  _POLineItem();

  int get quantity => int.tryParse(qtyCtrl.text) ?? 0;
  double get unitCost => double.tryParse(costCtrl.text) ?? 0;
  double get subtotal => quantity * unitCost;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState
    extends ConsumerState<PurchaseOrderFormScreen> {
  int? _selectedSupplierId;
  String? _selectedSupplierName;
  DateTime? _expectedDelivery;
  final _notesCtrl = TextEditingController();
  final List<_POLineItem> _lines = [_POLineItem()];
  bool _submitting = false;

  List<dynamic> _suppliers = [];
  bool _loadingSuppliers = true;

  List<Item> _inventoryItems = [];
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final suppliers = await ref.read(posApiProvider).fetchSuppliers();
      if (mounted) setState(() { _suppliers = suppliers; _loadingSuppliers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
    try {
      final items = await ref.read(inventoryApiProvider).fetchInventory();
      if (mounted) setState(() { _inventoryItems = items; _loadingItems = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  double get _total =>
      _lines.fold(0.0, (sum, l) => sum + l.subtotal);

  Future<void> _submit() async {
    if (_selectedSupplierId == null) {
      _showSnackBar('Please select a supplier', EnhancedTheme.warningAmber,
          Icons.info_rounded);
      return;
    }
    final validLines =
        _lines.where((l) => l.itemName.isNotEmpty && l.quantity > 0).toList();
    if (validLines.isEmpty) {
      _showSnackBar('Add at least one item with quantity > 0',
          EnhancedTheme.warningAmber, Icons.info_rounded);
      return;
    }

    setState(() => _submitting = true);
    try {
      final order = await ref
          .read(purchaseOrderListProvider.notifier)
          .createOrder({
        'supplier_id': _selectedSupplierId,
        'supplier_name': _selectedSupplierName ?? '',
        'status': 'draft',
        if (_expectedDelivery != null)
          'expected_delivery':
              _expectedDelivery!.toIso8601String().split('T').first,
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'items': validLines
            .map((l) => {
                  if (l.itemId != null) 'item_id': l.itemId,
                  'item_name': l.itemName,
                  'quantity_ordered': l.quantity,
                  'quantity_received': 0,
                  'unit_cost': l.unitCost,
                })
            .toList(),
      });

      if (mounted) {
        context.go('/dashboard/purchase-orders/${order?.id}');
        _showSnackBar(
            'Purchase order created', EnhancedTheme.successGreen, Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnackBar('Failed: $e', EnhancedTheme.errorRed, Icons.error_rounded);
      }
    }
  }

  void _showSnackBar(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(icon, color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  InputDecoration _inputDec(String hint, {String? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: context.hintColor, fontSize: 12),
        prefixText: prefix,
        prefixStyle: GoogleFonts.inter(
            color: context.subLabelColor, fontSize: 13),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: const OutlineInputBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(
                color: EnhancedTheme.primaryTeal, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(
          child: Column(children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04)),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: context.labelColor),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/dashboard/purchase-orders'),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('New Purchase Order',
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text('Create a draft PO',
                            style: GoogleFonts.inter(
                                color: context.subLabelColor,
                                fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  _sectionLabel('Supplier'),
                  const SizedBox(height: 8),
                  _loadingSuppliers
                      ? EnhancedTheme.loadingShimmer(height: 48, radius: 12)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child:
                              DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedSupplierId,
                            hint: Text('Select supplier',
                                style: GoogleFonts.inter(
                                    color: context.hintColor,
                                    fontSize: 14)),
                            dropdownColor: context.isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            style: GoogleFonts.inter(
                                color: context.labelColor, fontSize: 14),
                            items: _suppliers
                                .map<DropdownMenuItem<int>>((s) {
                              final id = s['id'] as int;
                              final name =
                                  s['name'] as String? ?? 'Unknown';
                              return DropdownMenuItem(
                                  value: id, child: Text(name));
                            }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final s = _suppliers
                                  .firstWhere((x) => x['id'] == v);
                              setState(() {
                                _selectedSupplierId = v;
                                _selectedSupplierName =
                                    s['name'] as String?;
                              });
                            },
                          )),
                        ),
                  const SizedBox(height: 16),
                  _sectionLabel('Expected Delivery (optional)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expectedDelivery ??
                            DateTime.now()
                                .add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: EnhancedTheme.primaryTeal,
                              onPrimary: Colors.white,
                              surface: Color(0xFF1E293B),
                              onSurface: Color(0xFFE2E8F0),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _expectedDelivery = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _expectedDelivery != null
                              ? EnhancedTheme.primaryTeal
                                  .withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_month_rounded,
                            color: _expectedDelivery != null
                                ? EnhancedTheme.primaryTeal
                                : context.hintColor,
                            size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _expectedDelivery != null
                              ? '${_expectedDelivery!.year}-${_expectedDelivery!.month.toString().padLeft(2, '0')}-${_expectedDelivery!.day.toString().padLeft(2, '0')}'
                              : 'Pick a date',
                          style: GoogleFonts.inter(
                              color: _expectedDelivery != null
                                  ? context.labelColor
                                  : context.hintColor,
                              fontSize: 14),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Notes (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(
                        color: context.labelColor, fontSize: 13),
                    decoration: _inputDec('Add notes…'),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: Text(
                          'Items (${_lines.length})',
                          style: GoogleFonts.outfit(
                              color: context.labelColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _lines.add(_POLineItem())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: EnhancedTheme.primaryTeal
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          const Icon(Icons.add_rounded,
                              color: EnhancedTheme.primaryTeal,
                              size: 16),
                          const SizedBox(width: 4),
                          Text('Add Item',
                              style: GoogleFonts.outfit(
                                  color: EnhancedTheme.primaryTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ...List.generate(
                      _lines.length, (i) => _lineCard(i)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.12),
                            EnhancedTheme.accentCyan
                                .withValues(alpha: 0.06),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: EnhancedTheme.primaryTeal
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                          Row(children: [
                            const Icon(Icons.receipt_long_rounded,
                                color: EnhancedTheme.primaryTeal,
                                size: 18),
                            const SizedBox(width: 8),
                            Text('Total',
                                style: GoogleFonts.outfit(
                                    color: context.labelColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          Text('₦${_total.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                  color: EnhancedTheme.primaryTeal,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.primaryTeal,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : Text('Create Draft PO',
                              style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: GoogleFonts.outfit(
          color: context.subLabelColor,
          fontSize: 12,
          fontWeight: FontWeight.w600));

  Widget _lineCard(int i) {
    final line = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Item ${i + 1}',
                    style: GoogleFonts.outfit(
                        color: EnhancedTheme.primaryTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (_lines.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _lines[i].dispose();
                    _lines.removeAt(i);
                  }),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: EnhancedTheme.errorRed, size: 16),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _loadingItems
                  ? EnhancedTheme.loadingShimmer(height: 40, radius: 10)
                  : _inventoryItems.isEmpty
                      ? TextField(
                          onChanged: (v) =>
                              setState(() => line.itemName = v),
                          style: GoogleFonts.inter(
                              color: context.labelColor, fontSize: 13),
                          decoration: _inputDec('Item name *'),
                        )
                      : _itemDropdown(line),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: line.qtyCtrl,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                        color: context.labelColor, fontSize: 13),
                    decoration: _inputDec('Quantity *'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.costCtrl,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: GoogleFonts.inter(
                        color: context.labelColor, fontSize: 13),
                    decoration: _inputDec('Unit Cost *', prefix: '₦'),
                  ),
                ),
              ]),
              if (line.subtotal > 0) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Subtotal: ₦${line.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                          color: context.subLabelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _itemDropdown(_POLineItem line) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
        isExpanded: true,
        isDense: true,
        value: line.itemId,
        hint: Text('Select item',
            style: GoogleFonts.inter(
                color: context.hintColor, fontSize: 13)),
        dropdownColor:
            context.isDark ? const Color(0xFF1E293B) : Colors.white,
        style:
            GoogleFonts.inter(color: context.labelColor, fontSize: 13),
        items: _inventoryItems
            .map((item) => DropdownMenuItem<int>(
                  value: item.id,
                  child: Text(
                    item.brand.isNotEmpty
                        ? '${item.name} (${item.brand})'
                        : item.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          final item = _inventoryItems.firstWhere((x) => x.id == v);
          setState(() {
            line.itemId = v;
            line.itemName = item.name;
            if (line.costCtrl.text.isEmpty && item.costPrice > 0) {
              line.costCtrl.text =
                  item.costPrice.toStringAsFixed(2);
            }
          });
        },
      )),
    );
  }
}
