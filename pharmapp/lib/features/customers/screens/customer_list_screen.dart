import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/customer_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter    = 'All';
  final _filters    = ['All', 'Retail', 'Wholesale', 'Wallet', 'Debt'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Customer> _applyFilter(List<Customer> list) {
    final q = _searchCtrl.text.toLowerCase();
    return list.where((c) {
      if (q.isNotEmpty &&
          !c.name.toLowerCase().contains(q) &&
          !c.phone.contains(q)) {
        return false;
      }
      switch (_filter) {
        case 'Retail':    return !c.isWholesale;
        case 'Wholesale': return c.isWholesale;
        case 'Wallet':    return c.walletBalance > 0;
        case 'Debt':      return c.outstandingDebt > 0;
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
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(top: BorderSide(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4), width: 1.5)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                child: Form(
                  key: formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Center(child: Container(
                      width: 44, height: 5,
                      decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3)),
                    )),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: EnhancedTheme.primaryTeal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Add New Customer',
                          style: GoogleFonts.outfit(
                              color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Text('Register a retail or wholesale customer',
                          style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                    ),
                    const SizedBox(height: 24),
                    _sheetField(nameCtrl, 'Full Name / Business Name *',
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 14),
                    _sheetField(phoneCtrl, 'Phone Number *', keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 20),
                    Text('Customer Type', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Row(children: ['Retail', 'Wholesale'].map((t) => Expanded(child: Padding(
                      padding: EdgeInsets.only(right: t == 'Retail' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setModal(() => type = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: type == t ? LinearGradient(
                              colors: t == 'Wholesale'
                                  ? [EnhancedTheme.accentCyan, EnhancedTheme.infoBlue]
                                  : [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ) : null,
                            color: type == t ? null : ctx.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: type == t
                                  ? Colors.transparent
                                  : ctx.borderColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(
                              t == 'Wholesale' ? Icons.store_rounded : Icons.storefront_rounded,
                              color: type == t ? Colors.white : ctx.subLabelColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(t, style: TextStyle(
                                color: type == t ? Colors.white : ctx.subLabelColor,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ))).toList()),
                    const SizedBox(height: 28),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.of(ctx).pop();
                        final result = await ref.read(customerNotifierProvider.notifier).createCustomer({
                          'name':         nameCtrl.text.trim(),
                          'phone':        phoneCtrl.text.trim(),
                          'is_wholesale': type == 'Wholesale',
                        });
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: (result != null ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.92),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                          content: Row(children: [
                            Icon(result != null ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(result != null ? '${result.name} added successfully' : 'Failed to add customer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                          ]),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text('Add Customer',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                    )),
                  ]),
                ),
              ),
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
        labelText: label, labelStyle: TextStyle(color: context.hintColor, fontSize: 13),
        filled: true, fillColor: context.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
        errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerSheet(context),
        backgroundColor: EnhancedTheme.primaryTeal,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Customer', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative background circles
        Positioned(
          top: -60, right: -60,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: 100, left: -80,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EnhancedTheme.accentCyan.withValues(alpha: 0.05),
            ),
          ),
        ),

        SafeArea(child: Column(children: [
          _buildHeader(context, customersAsync.value?.length),
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: customersAsync.when(
            loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  color: EnhancedTheme.primaryTeal,
                  backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text('Loading customers…',
                  style: TextStyle(color: context.subLabelColor, fontSize: 13)),
            ])),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Connection Error', style: GoogleFonts.outfit(
                  color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(customerListProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ])),
            data: (customers) {
              final filtered = _applyFilter(customers);
              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.03),
                      ]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded,
                        color: EnhancedTheme.primaryTeal, size: 56),
                  ),
                  const SizedBox(height: 20),
                  Text('No customers found',
                      style: GoogleFonts.outfit(
                          color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(_filter == 'All' ? 'Add your first customer using the button below' : 'Try a different filter',
                      style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _customerCard(filtered[i])
                    .animate(delay: (i * 40).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.2, end: 0),
              );
            },
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, int? count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
        ),
        const SizedBox(width: 4),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Customers',
              style: GoogleFonts.outfit(
                  color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w800)),
          Text('Manage your customer base',
              style: TextStyle(color: context.subLabelColor, fontSize: 12)),
        ])),
        if (count != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                EnhancedTheme.accentCyan.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people_rounded, color: EnhancedTheme.primaryTeal, size: 14),
            const SizedBox(width: 6),
            Text('$count', style: const TextStyle(
                color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: context.subLabelColor),
          onPressed: () => ref.invalidate(customerListProvider),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: ClipRRect(borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl, onChanged: (_) => setState(() {}),
          style: TextStyle(color: context.labelColor),
          decoration: InputDecoration(
            hintText: 'Search by name or phone…',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: context.hintColor),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() {}); },
                  )
                : null,
            filled: true, fillColor: context.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ),
  );

  Widget _buildFilterChips() => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = _filters[i];
        final active = f == _filter;
        final chipColors = {
          'All': EnhancedTheme.primaryTeal,
          'Retail': EnhancedTheme.accentCyan,
          'Wholesale': EnhancedTheme.accentPurple,
          'Wallet': EnhancedTheme.successGreen,
          'Debt': EnhancedTheme.errorRed,
        };
        final color = chipColors[f] ?? EnhancedTheme.primaryTeal;
        return GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: active ? LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ) : null,
              color: active ? null : context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? color : context.borderColor,
                width: active ? 0 : 1,
              ),
              boxShadow: active ? [BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8, offset: const Offset(0, 3),
              )] : [],
            ),
            child: Text(f, style: TextStyle(
                color: active ? Colors.white : context.subLabelColor,
                fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
      },
    ),
  );

  Widget _customerCard(Customer c) {
    final isWholesale = c.isWholesale;
    final accentColor = isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal;
    final hasDebt = c.outstandingDebt > 0;
    final initials = c.name.trim().split(' ')
        .where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

    return GestureDetector(
      onTap: () => context.push('/customer/${c.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasDebt ? EnhancedTheme.errorRed : accentColor).withValues(alpha: 0.08),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasDebt
                    ? EnhancedTheme.errorRed.withValues(alpha: 0.06)
                    : context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasDebt
                      ? EnhancedTheme.errorRed.withValues(alpha: 0.3)
                      : context.borderColor,
                  width: hasDebt ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                // Avatar with gradient background
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Center(
                    child: Text(initials.isNotEmpty ? initials : '?',
                        style: TextStyle(color: accentColor, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name,
                      style: GoogleFonts.outfit(
                          color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.phone_rounded, color: context.hintColor, size: 11),
                    const SizedBox(width: 4),
                    Text(c.phone, style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _chip(c.type, accentColor,
                        icon: isWholesale ? Icons.store_rounded : Icons.storefront_rounded),
                    if (c.walletBalance > 0)
                      _chip('₦${c.walletBalance.toStringAsFixed(0)}', EnhancedTheme.successGreen,
                          icon: Icons.account_balance_wallet_rounded),
                    if (hasDebt)
                      _chip('₦${c.outstandingDebt.toStringAsFixed(0)} due', EnhancedTheme.errorRed,
                          icon: Icons.warning_rounded),
                  ]),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${c.totalPurchases}',
                        style: TextStyle(color: accentColor, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Text('purchases', style: TextStyle(color: context.hintColor, fontSize: 10)),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded, color: context.hintColor, size: 18),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, color: color, size: 9),
        const SizedBox(width: 4),
      ],
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}
