import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import '../providers/customer_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter    = 'All';
  final _filters    = ['All', 'Retail', 'Wholesale', 'Wallet'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Customer> _applyFilter(List<Customer> list) {
    final q = _searchCtrl.text.toLowerCase();
    return list.where((c) {
      if (q.isNotEmpty &&
          !c.name.toLowerCase().contains(q) &&
          !c.phone.contains(q)) return false;
      switch (_filter) {
        case 'Retail':    return !c.isWholesale;
        case 'Wholesale': return c.isWholesale;
        case 'Wallet':    return c.walletBalance > 0;
        default:          return true;
      }
    }).toList();
  }

  void _showAddCustomerSheet(BuildContext context) {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    String type     = 'Retail';
    final formKey   = GlobalKey<FormState>();

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
                _sheetField(phoneCtrl, 'Phone Number *', keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                Row(children: [
                  Text('Type:', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
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
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: type == t
                              ? (t == 'Wholesale' ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal)
                              : Colors.white.withValues(alpha: 0.15)),
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
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(ctx).pop();
                    final result = await ref.read(customerNotifierProvider.notifier).createCustomer({
                      'name':         nameCtrl.text.trim(),
                      'phone':        phoneCtrl.text.trim(),
                      'is_wholesale': type == 'Wholesale',
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result != null ? '${result.name} added' : 'Failed to add customer'),
                        backgroundColor: result != null ? EnhancedTheme.successGreen : EnhancedTheme.errorRed));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
      controller: ctrl, keyboardType: keyboardType, validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerSheet(context),
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer'),
      ),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, 0.5, 1]))),
        SafeArea(child: Column(children: [
          _buildHeader(context, customersAsync.value?.length),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: customersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: () => ref.invalidate(customerListProvider),
                  child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (customers) {
              final filtered = _applyFilter(customers);
              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.2), size: 64),
                  const SizedBox(height: 16),
                  Text('No customers found', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                ]));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _customerCard(filtered[i]),
              );
            },
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, int? count) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
      const SizedBox(width: 4),
      const Expanded(child: Text('Customers', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600))),
      if (count != null) Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
        ),
        child: Text('$count total', style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: () => ref.invalidate(customerListProvider)),
    ]),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: ClipRRect(borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl, onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by name or phone…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4)),
            filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
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
              color: active ? EnhancedTheme.primaryTeal : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? EnhancedTheme.primaryTeal : Colors.white.withValues(alpha: 0.15)),
            ),
            child: Text(f, style: TextStyle(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      },
    ),
  );

  Widget _customerCard(Customer c) => GestureDetector(
    onTap: () => context.push('/customer/${c.id}'),
    child: ClipRRect(borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.outstandingDebt > 0
                ? EnhancedTheme.errorRed.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outstandingDebt > 0
                ? EnhancedTheme.errorRed.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: (c.isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal).withValues(alpha: 0.15),
              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: c.isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal,
                  fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(c.phone, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                _chip(c.type, c.isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal),
                if (c.walletBalance > 0)
                  _chip('₹${c.walletBalance.toStringAsFixed(0)} wallet', EnhancedTheme.successGreen),
                if (c.outstandingDebt > 0)
                  _chip('₹${c.outstandingDebt.toStringAsFixed(0)} due', EnhancedTheme.errorRed),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${c.totalPurchases}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('purchases', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
            ]),
          ]),
        ),
      ),
    ),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}
