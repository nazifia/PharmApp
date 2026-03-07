import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter    = 'All';
  bool   _isGrid    = false;

  final _filters = ['All', 'Low Stock', 'Expired', 'Prescription'];

  // Mock inventory items
  final _items = [
    {'id': 1, 'name': 'Paracetamol 500mg',  'brand': 'Cipla',      'form': 'Tablet',  'price': 75.0,   'stock': 5,   'low': 20, 'expired': false, 'rx': false, 'barcode': '8901234567890'},
    {'id': 2, 'name': 'Amoxicillin 250mg',  'brand': 'Sun Pharma', 'form': 'Capsule', 'price': 180.0,  'stock': 3,   'low': 15, 'expired': false, 'rx': true,  'barcode': '8901234567891'},
    {'id': 3, 'name': 'Metformin 500mg',    'brand': 'USV',        'form': 'Tablet',  'price': 120.0,  'stock': 8,   'low': 25, 'expired': false, 'rx': true,  'barcode': '8901234567892'},
    {'id': 4, 'name': 'Omeprazole 20mg',    'brand': 'Alkem',      'form': 'Capsule', 'price': 95.0,   'stock': 2,   'low': 10, 'expired': false, 'rx': false, 'barcode': '8901234567893'},
    {'id': 5, 'name': 'Vitamin C 500mg',    'brand': 'Emzor',      'form': 'Tablet',  'price': 450.0,  'stock': 80,  'low': 20, 'expired': false, 'rx': false, 'barcode': '8901234567894'},
    {'id': 6, 'name': 'Ibuprofen 400mg',    'brand': 'Greenfield', 'form': 'Tablet',  'price': 65.0,   'stock': 45,  'low': 20, 'expired': false, 'rx': false, 'barcode': '8901234567895'},
    {'id': 7, 'name': 'Lisinopril 10mg',    'brand': 'Zenith',     'form': 'Tablet',  'price': 220.0,  'stock': 12,  'low': 20, 'expired': false, 'rx': true,  'barcode': '8901234567896'},
    {'id': 8, 'name': 'Salbutamol Inhaler', 'brand': 'GSK',        'form': 'Inhaler', 'price': 1800.0, 'stock': 6,   'low': 10, 'expired': false, 'rx': true,  'barcode': '8901234567897'},
    {'id': 9, 'name': 'ORS Sachet',         'brand': 'Rehydration','form': 'Sachet',  'price': 25.0,   'stock': 200, 'low': 50, 'expired': false, 'rx': false, 'barcode': '8901234567898'},
    {'id':10, 'name': 'Tetracycline 250mg', 'brand': 'NAFDAC',     'form': 'Capsule', 'price': 80.0,   'stock': 0,   'low': 15, 'expired': true,  'rx': true,  'barcode': '8901234567899'},
  ];

  List<Map<String, dynamic>> get _filtered {
    var list = _items.where((item) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isNotEmpty &&
          !(item['name'] as String).toLowerCase().contains(q) &&
          !(item['brand'] as String).toLowerCase().contains(q) &&
          !(item['barcode'] as String).contains(q)) return false;
      switch (_filter) {
        case 'Low Stock':  return (item['stock'] as int) <= (item['low'] as int);
        case 'Expired':    return item['expired'] as bool;
        case 'Prescription': return item['rx'] as bool;
        default: return true;
      }
    }).toList();
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddItemSheet(BuildContext context) {
    final nameCtrl     = TextEditingController();
    final brandCtrl    = TextEditingController();
    final priceCtrl    = TextEditingController();
    final stockCtrl    = TextEditingController();
    final barcodeCtrl  = TextEditingController();
    String form        = 'Tablet';
    bool   isRx        = false;
    final formKey      = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Handle
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Add New Item', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                _sheetField(nameCtrl,    'Item Name *',  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                _sheetField(brandCtrl,   'Brand / Manufacturer'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _sheetField(priceCtrl, 'Price (₹) *',
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Invalid' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: _sheetField(stockCtrl, 'Stock Qty *',
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null)),
                ]),
                const SizedBox(height: 12),
                _sheetField(barcodeCtrl, 'Barcode (optional)', keyboardType: TextInputType.number),
                const SizedBox(height: 16),

                // Dosage form selector
                Row(children: [
                  Text('Form:', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const SizedBox(width: 10),
                  ...['Tablet','Capsule','Syrup','Inhaler','Sachet','Injection'].map((f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setModal(() => form = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: form == f ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: form == f ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.15)),
                        ),
                        child: Text(f, style: TextStyle(color: form == f ? Colors.white : Colors.white54, fontSize: 11)),
                      ),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),

                // Rx toggle
                Row(children: [
                  Switch(
                    value: isRx,
                    onChanged: (v) => setModal(() => isRx = v),
                    activeColor: EnhancedTheme.accentPurple,
                  ),
                  const SizedBox(width: 8),
                  Text('Prescription Required', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                ]),
                const SizedBox(height: 20),

                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final newItem = {
                        'id':       _items.length + 1,
                        'name':     nameCtrl.text.trim(),
                        'brand':    brandCtrl.text.trim().isEmpty ? 'Unknown' : brandCtrl.text.trim(),
                        'form':     form,
                        'price':    double.parse(priceCtrl.text),
                        'stock':    int.parse(stockCtrl.text),
                        'low':      20,
                        'expired':  false,
                        'rx':       isRx,
                        'barcode':  barcodeCtrl.text.trim().isEmpty ? 'N/A' : barcodeCtrl.text.trim(),
                      };
                      setState(() => _items.add(newItem));
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${nameCtrl.text.trim()} added to inventory'),
                              backgroundColor: EnhancedTheme.successGreen));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal,
                    foregroundColor: Colors.white,
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
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0,0.5,1]))),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(
                  child: _isGrid
                      ? _buildGrid()
                      : _buildList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
        const SizedBox(width: 4),
        const Expanded(child: Text('Inventory', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600))),
        IconButton(
          icon: Icon(_isGrid ? Icons.list_rounded : Icons.grid_view_rounded, color: Colors.white70),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, brand, barcode…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f      = _filters[i];
          final active = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.15)),
              ),
              child: Text(f, style: TextStyle(
                color: active ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _itemCard(items[i]),
    );
  }

  Widget _buildGrid() {
    final items = _filtered;
    if (items.isEmpty) return _emptyState();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
      itemCount: items.length,
      itemBuilder: (_, i) => _itemGridCard(items[i]),
    );
  }

  Color _stockColor(int stock, int low) {
    if (stock == 0) return EnhancedTheme.errorRed;
    if (stock <= low) return EnhancedTheme.warningAmber;
    return EnhancedTheme.successGreen;
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final sc  = _stockColor(item['stock'] as int, item['low'] as int);
    final exp = item['expired'] as bool;

    return GestureDetector(
      onTap: () => context.push('/item/${item['id']}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(exp ? 0.04 : 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: exp ? EnhancedTheme.errorRed.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.medication_rounded, color: sc, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${item['brand']}  ·  ${item['form']}',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${(item['price'] as double).toStringAsFixed(0)}',
                    style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _stockBadge(item['stock'] as int, item['low'] as int),
                if (exp) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _chip('Expired', EnhancedTheme.errorRed)),
                if (item['rx'] as bool) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _chip('Rx', EnhancedTheme.accentPurple)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _itemGridCard(Map<String, dynamic> item) {
    final sc = _stockColor(item['stock'] as int, item['low'] as int);
    return GestureDetector(
      onTap: () => context.push('/item/${item['id']}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.medication_rounded, color: sc, size: 20),
              ),
              const SizedBox(height: 10),
              Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(item['brand'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₹${(item['price'] as double).toStringAsFixed(0)}',
                    style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                _stockBadge(item['stock'] as int, item['low'] as int),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stockBadge(int stock, int low) {
    final c = _stockColor(stock, low);
    final label = stock == 0 ? 'Out' : stock <= low ? '$stock low' : '$stock';
    return _chip(label, c);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inventory_2_outlined, color: Colors.white.withOpacity(0.2), size: 64),
      const SizedBox(height: 16),
      Text('No items found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
    ]),
  );
}
