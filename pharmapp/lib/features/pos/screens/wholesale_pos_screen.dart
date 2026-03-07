import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class WholesalePOSScreen extends ConsumerStatefulWidget {
  const WholesalePOSScreen({super.key});

  @override
  ConsumerState<WholesalePOSScreen> createState() => _WholesalePOSScreenState();
}

class _WholesalePOSScreenState extends ConsumerState<WholesalePOSScreen> {
  final _searchCtrl   = TextEditingController();
  String? _selectedCustomer;
  final List<_CartLine> _cart = [];

  // Mock catalogue
  static const _catalogue = [
    {'id': 1, 'name': 'Paracetamol 500mg 10x10', 'brand': 'Cipla',      'price': 600.0,   'stock': 50},
    {'id': 2, 'name': 'Amoxicillin 250mg 10x10', 'brand': 'Sun Pharma', 'price': 1500.0,  'stock': 30},
    {'id': 3, 'name': 'Vitamin C 500mg 30s',      'brand': 'Emzor',      'price': 3200.0,  'stock': 40},
    {'id': 4, 'name': 'Ibuprofen 400mg 10x10',   'brand': 'Greenfield', 'price': 550.0,   'stock': 60},
    {'id': 5, 'name': 'ORS Sachet Box 50s',       'brand': 'Rehydration','price': 1100.0,  'stock': 80},
    {'id': 6, 'name': 'Metformin 500mg 10x10',   'brand': 'USV',        'price': 950.0,   'stock': 45},
  ];

  static const _customers = [
    'City Pharmacy', 'Sunrise Medical', 'Green Cross Clinic',
    'Medicare Hub', 'Alpha Healthcare',
  ];

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return List.from(_catalogue);
    return _catalogue.where((i) =>
        (i['name'] as String).toLowerCase().contains(q) ||
        (i['brand'] as String).toLowerCase().contains(q)).toList();
  }

  double get _cartTotal => _cart.fold(0, (s, l) => s + l.total);
  int    get _cartCount => _cart.fold(0, (s, l) => s + l.qty);

  void _addToCart(Map<String, dynamic> item) {
    final idx = _cart.indexWhere((l) => l.id == item['id']);
    setState(() {
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWithQty(_cart[idx].qty + 1);
      } else {
        _cart.add(_CartLine(
          id:    item['id'] as int,
          name:  item['name'] as String,
          price: item['price'] as double,
          qty:   1,
        ));
      }
    });
  }

  void _removeFromCart(int id) => setState(() => _cart.removeWhere((l) => l.id == id));

  void _updateQty(int id, int qty) {
    if (qty <= 0) { _removeFromCart(id); return; }
    setState(() {
      final idx = _cart.indexWhere((l) => l.id == id);
      if (idx >= 0) _cart[idx] = _cart[idx].copyWithQty(qty);
    });
  }

  void _checkout() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty')));
      return;
    }
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed for $_selectedCustomer – ₹${_cartTotal.toStringAsFixed(2)}')));
    setState(() { _cart.clear(); _selectedCustomer = null; });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          SafeArea(child: Column(children: [
            _header(context),
            Expanded(child: wide
                ? Row(children: [
                    Expanded(flex: 3, child: _itemsPanel()),
                    const VerticalDivider(width: 1, color: Colors.white12),
                    Expanded(flex: 2, child: _cartPanel()),
                  ])
                : _mobileLayout()),
          ])),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
        const SizedBox(width: 4),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wholesale POS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          Text('Bulk order processing', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: EnhancedTheme.accentCyan.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.accentCyan.withOpacity(0.3)),
          ),
          child: Text('${_cartCount} items', style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _mobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: EnhancedTheme.accentCyan,
          unselectedLabelColor: Colors.white38,
          indicatorColor: EnhancedTheme.accentCyan,
          tabs: [
            Tab(text: 'Catalogue (${_filtered.length})'),
            Tab(text: 'Cart (${_cart.length})'),
          ],
        ),
        Expanded(child: TabBarView(children: [_itemsPanel(), _cartPanel()])),
      ]),
    );
  }

  Widget _itemsPanel() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search catalogue…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _catalogueItem(_filtered[i]),
      )),
    ]);
  }

  Widget _catalogueItem(Map<String, dynamic> item) {
    final inCart = _cart.any((l) => l.id == item['id']);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: inCart
                ? EnhancedTheme.accentCyan.withOpacity(0.08)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: inCart ? EnhancedTheme.accentCyan.withOpacity(0.3) : Colors.white.withOpacity(0.09)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: EnhancedTheme.accentCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.medication_rounded, color: EnhancedTheme.accentCyan, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(item['brand'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${(item['price'] as double).toStringAsFixed(0)}',
                  style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _addToCart(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EnhancedTheme.primaryTeal.withOpacity(0.3)),
                  ),
                  child: Text(inCart ? '+ Add more' : 'Add',
                      style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _cartPanel() {
    return Column(children: [
      // Customer selector
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCustomer,
                  hint: Text('Select wholesale customer',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  iconEnabledColor: Colors.white38,
                  items: _customers.map((c) => DropdownMenuItem(value: c,
                      child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _selectedCustomer = v),
                ),
              ),
            ),
          ),
        ),
      ),

      // Cart items
      Expanded(child: _cart.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.white.withOpacity(0.2), size: 52),
              const SizedBox(height: 12),
              Text('No items in cart', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: _cart.length,
              itemBuilder: (_, i) => _cartItem(_cart[i]),
            )),

      // Totals + checkout
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_cart.length} items  ·  $_cartCount units',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                  Text('₹${_cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Place Wholesale Order', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _cartItem(_CartLine line) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('₹${line.price.toStringAsFixed(0)} × ${line.qty} = ₹${line.total.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ])),
            Row(children: [
              _qtyBtn(Icons.remove, () => _updateQty(line.id, line.qty - 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${line.qty}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              _qtyBtn(Icons.add, () => _updateQty(line.id, line.qty + 1)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    ),
  );
}

class _CartLine {
  final int id; final String name; final double price; final int qty;
  const _CartLine({required this.id, required this.name, required this.price, required this.qty});
  double get total => price * qty;
  _CartLine copyWithQty(int q) => _CartLine(id: id, name: name, price: price, qty: q);
}
