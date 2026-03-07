import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'All';

  final _filters = ['All', 'Retail', 'Wholesale', 'Wallet'];

  final _customers = [
    {'id': 1, 'name': 'Adaeze Okafor',    'phone': '+2348012345678', 'type': 'Retail',    'wallet': 1500.0, 'purchases': 24, 'debt': 0.0},
    {'id': 2, 'name': 'City Pharmacy',    'phone': '+2348023456789', 'type': 'Wholesale', 'wallet': 0.0,    'purchases': 87, 'debt': 15000.0},
    {'id': 3, 'name': 'Emeka Nwosu',      'phone': '+2348034567890', 'type': 'Retail',    'wallet': 350.0,  'purchases': 12, 'debt': 0.0},
    {'id': 4, 'name': 'Sunrise Medical',  'phone': '+2348045678901', 'type': 'Wholesale', 'wallet': 0.0,    'purchases': 53, 'debt': 8500.0},
    {'id': 5, 'name': 'Fatima Aliyu',     'phone': '+2348056789012', 'type': 'Retail',    'wallet': 2200.0, 'purchases': 38, 'debt': 0.0},
    {'id': 6, 'name': 'Green Cross Clinic','phone': '+2348067890123', 'type': 'Wholesale', 'wallet': 0.0,   'purchases': 41, 'debt': 0.0},
    {'id': 7, 'name': 'Chidi Eze',        'phone': '+2348078901234', 'type': 'Retail',    'wallet': 0.0,    'purchases': 6,  'debt': 500.0},
    {'id': 8, 'name': 'Medicare Hub',     'phone': '+2348089012345', 'type': 'Wholesale', 'wallet': 0.0,    'purchases': 29, 'debt': 22000.0},
  ];

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _customers.where((c) {
      if (q.isNotEmpty &&
          !(c['name'] as String).toLowerCase().contains(q) &&
          !(c['phone'] as String).contains(q)) return false;
      switch (_filter) {
        case 'Retail':    return c['type'] == 'Retail';
        case 'Wholesale': return c['type'] == 'Wholesale';
        case 'Wallet':    return (c['wallet'] as double) > 0;
        default:          return true;
      }
    }).toList();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl   = TextEditingController();
    final phoneCtrl  = TextEditingController();
    String type      = 'Retail';
    final formKey    = GlobalKey<FormState>();

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Add Customer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                _sheetField(nameCtrl, 'Full Name / Business Name *',
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                _sheetField(phoneCtrl, 'Phone Number *',
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),

                // Customer type
                Row(children: [
                  Text('Type:', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const SizedBox(width: 12),
                  ...['Retail', 'Wholesale'].map((t) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setModal(() => type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: type == t
                              ? (t == 'Wholesale' ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal)
                              : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: type == t
                                ? (t == 'Wholesale' ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal)
                                : Colors.white.withOpacity(0.15)),
                        ),
                        child: Text(t, style: TextStyle(
                          color: type == t ? Colors.white : Colors.white54,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  )),
                ]),
                const SizedBox(height: 24),

                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final newCustomer = {
                        'id':        _customers.length + 1,
                        'name':      nameCtrl.text.trim(),
                        'phone':     phoneCtrl.text.trim(),
                        'type':      type,
                        'wallet':    0.0,
                        'purchases': 0,
                        'debt':      0.0,
                      };
                      setState(() => _customers.add(newCustomer));
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${nameCtrl.text.trim()} added'),
                              backgroundColor: EnhancedTheme.successGreen));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w700)),
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
        onPressed: () => _showAddCustomerSheet(context),
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer'),
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1]))),
          SafeArea(child: Column(children: [
            _buildHeader(context),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(child: _buildList()),
          ])),
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
        const Expanded(child: Text('Customers', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EnhancedTheme.primaryTeal.withOpacity(0.3)),
          ),
          child: Text('${_customers.length} total', style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
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
              hintText: 'Search by name or phone…',
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
          final f = _filters[i];
          final active = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.15)),
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
    if (items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, color: Colors.white.withOpacity(0.2), size: 64),
        const SizedBox(height: 16),
        Text('No customers found', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _customerCard(items[i]),
    );
  }

  Widget _customerCard(Map<String, dynamic> c) {
    final isWholesale = c['type'] == 'Wholesale';
    final hasDebt = (c['debt'] as double) > 0;
    final hasWallet = (c['wallet'] as double) > 0;

    return GestureDetector(
      onTap: () => context.push('/customer/${c['id']}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasDebt ? EnhancedTheme.errorRed.withOpacity(0.06) : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hasDebt ? EnhancedTheme.errorRed.withOpacity(0.25) : Colors.white.withOpacity(0.1)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: (isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal).withOpacity(0.15),
                child: Text(
                  (c['name'] as String)[0].toUpperCase(),
                  style: TextStyle(
                    color: isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal,
                    fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(c['phone'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  _chip(c['type'] as String, isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal),
                  if (hasWallet) _chip('₹${(c['wallet'] as double).toStringAsFixed(0)} wallet', EnhancedTheme.successGreen),
                  if (hasDebt) _chip('₹${(c['debt'] as double).toStringAsFixed(0)} due', EnhancedTheme.errorRed),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${c['purchases']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('purchases', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}
