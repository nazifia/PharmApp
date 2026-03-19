import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/inventory_provider.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'All';
  bool   _isGrid  = false;

  final _filters = ['All', 'Low Stock', 'Expired', 'Expiring Soon'];

  List<Item> _applyFilter(List<Item> items) {
    final q   = _searchCtrl.text.toLowerCase();
    final now = DateTime.now();
    return items.where((item) {
      if (q.isNotEmpty &&
          !item.name.toLowerCase().contains(q) &&
          !item.brand.toLowerCase().contains(q) &&
          !item.barcode.contains(q)) {
        return false;
      }
      switch (_filter) {
        case 'Low Stock':     return item.stock <= item.lowStockThreshold;
        case 'Expired':       return item.expiryDate != null && item.expiryDate!.isBefore(now);
        case 'Expiring Soon': return item.expiryDate != null &&
            item.expiryDate!.isAfter(now) &&
            item.expiryDate!.isBefore(now.add(const Duration(days: 30)));
        default:              return true;
      }
    }).toList();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _showAddItemSheet(BuildContext context) {
    final nameCtrl    = TextEditingController();
    final brandCtrl   = TextEditingController();
    final priceCtrl   = TextEditingController();
    final stockCtrl   = TextEditingController();
    final barcodeCtrl = TextEditingController();
    String form       = 'Tablet';
    final formKey     = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Add New Item', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _sheetField(nameCtrl, 'Item Name *', validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                _sheetField(brandCtrl, 'Brand / Manufacturer'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _sheetField(priceCtrl, 'Price (₦) *',
                      keyboardType: TextInputType.number,
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: _sheetField(stockCtrl, 'Stock Qty *',
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null)),
                ]),
                const SizedBox(height: 12),
                _sheetField(barcodeCtrl, 'Barcode (optional)', keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                // Dosage form chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: ['Tablet','Capsule','Syrup','Inhaler','Sachet','Injection'].map((f) =>
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setModal(() => form = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: form == f ? EnhancedTheme.primaryTeal : ctx.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: form == f ? EnhancedTheme.primaryTeal : ctx.borderColor),
                          ),
                          child: Text(f, style: TextStyle(color: form == f ? Colors.white : ctx.subLabelColor, fontSize: 11)),
                        ),
                      ),
                    )).toList()),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final data = {
                      'name':               nameCtrl.text.trim(),
                      'brand':              brandCtrl.text.trim().isEmpty ? 'Unknown' : brandCtrl.text.trim(),
                      'dosage_form':        form,
                      'price':              double.parse(priceCtrl.text),
                      'stock':              int.parse(stockCtrl.text),
                      'low_stock_threshold': 20,
                      'barcode':            barcodeCtrl.text.trim().isEmpty ? 'N/A' : barcodeCtrl.text.trim(),
                    };
                    Navigator.of(ctx).pop();
                    try {
                      await ref.read(inventoryApiProvider).createItem(data);
                      ref.invalidate(inventoryListProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${data['name']} added'),
                        backgroundColor: EnhancedTheme.successGreen));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'), backgroundColor: EnhancedTheme.errorRed));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label,
      {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, keyboardType: keyboardType, validator: validator,
      style: TextStyle(color: context.labelColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.hintColor, fontSize: 13),
        filled: true, fillColor: context.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
        errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = _searchCtrl.text.isNotEmpty
        ? ref.watch(inventorySearchProvider(_searchCtrl.text))
        : ref.watch(inventoryListProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _buildHeader(context),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: () => ref.invalidate(inventoryListProvider),
                  child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (items) {
              final filtered = _applyFilter(items);
              if (filtered.isEmpty) return _emptyState();
              return _isGrid ? _buildGrid(filtered) : _buildList(filtered);
            },
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
      const SizedBox(width: 4),
      Expanded(child: Text('Inventory', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w600))),
      IconButton(
        icon: Icon(_isGrid ? Icons.list_rounded : Icons.grid_view_rounded, color: context.subLabelColor),
        onPressed: () => setState(() => _isGrid = !_isGrid),
      ),
      IconButton(
        icon: Icon(Icons.refresh_rounded, color: context.subLabelColor),
        onPressed: () => ref.invalidate(inventoryListProvider),
      ),
    ]),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: ClipRRect(borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: context.labelColor),
          decoration: InputDecoration(
            hintText: 'Search by name, brand, barcode…',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: context.hintColor),
            filled: true, fillColor: context.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ),
  );

  Widget _buildFilterChips() => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = _filters[i]; final active = f == _filter;
        return GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? EnhancedTheme.primaryTeal : context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? EnhancedTheme.primaryTeal : context.borderColor),
            ),
            child: Text(f, style: TextStyle(color: active ? Colors.white : context.subLabelColor,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      },
    ),
  );

  Widget _buildList(List<Item> items) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    itemCount: items.length,
    itemBuilder: (_, i) => _itemCard(items[i]),
  );

  Widget _buildGrid(List<Item> items) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
      mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
    itemCount: items.length,
    itemBuilder: (_, i) => _itemGridCard(items[i]),
  );

  Color _stockColor(Item item) {
    if (item.stock == 0) return EnhancedTheme.errorRed;
    if (item.stock <= item.lowStockThreshold) return EnhancedTheme.warningAmber;
    return EnhancedTheme.successGreen;
  }

  Widget _itemCard(Item item) {
    final sc  = _stockColor(item);
    final now = DateTime.now();
    final exp = item.expiryDate != null && item.expiryDate!.isBefore(now);
    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      child: ClipRRect(borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: exp ? context.cardColor.withValues(alpha: 0.5) : context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: exp ? EnhancedTheme.errorRed.withValues(alpha: 0.3) : context.borderColor),
            ),
            child: Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.medication_rounded, color: sc, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${item.brand}  ·  ${item.dosageForm}',
                    style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₦${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _stockBadge(item),
                if (exp) Padding(padding: const EdgeInsets.only(top: 4), child: _chip('Expired', EnhancedTheme.errorRed)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _itemGridCard(Item item) {
    final sc = _stockColor(item);
    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      child: ClipRRect(borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.medication_rounded, color: sc, size: 20)),
              const SizedBox(height: 10),
              Text(item.name, style: TextStyle(color: context.labelColor, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₦${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                _stockBadge(item),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stockBadge(Item item) {
    final c = _stockColor(item);
    final label = item.stock == 0 ? 'Out' : item.stock <= item.lowStockThreshold ? '${item.stock} low' : '${item.stock}';
    return _chip(label, c);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inventory_2_outlined, color: context.hintColor, size: 64),
    const SizedBox(height: 16),
    Text('No items found', style: TextStyle(color: context.subLabelColor, fontSize: 16)),
  ]));
}
