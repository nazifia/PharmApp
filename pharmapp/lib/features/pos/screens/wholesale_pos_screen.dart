import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/customer.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wholesale_cart_provider.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';
import 'package:pharmapp/shared/widgets/barcode_scanner_sheet.dart';
import 'package:pharmapp/shared/widgets/hardware_scanner_listener.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'wholesale_cart_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class WholesalePOSScreen extends ConsumerStatefulWidget {
  const WholesalePOSScreen({super.key});

  @override
  ConsumerState<WholesalePOSScreen> createState() => _WholesalePOSScreenState();
}

class _WholesalePOSScreenState extends ConsumerState<WholesalePOSScreen> {
  final _searchCtrl = TextEditingController();
  bool _gridView = false;

  static const _kWalkIn = WsSelectedCustomer(
    id: -1, name: 'Walk-in Customer', walletBalance: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pre = ref.read(selectedCustomerProvider);
      if (pre != null) {
        ref.read(wsSelectedCustomerProvider.notifier).state = WsSelectedCustomer(
          id: pre.id, name: pre.name, walletBalance: pre.walletBalance,
        );
        ref.read(selectedCustomerProvider.notifier).state = null;
      } else if (ref.read(wsSelectedCustomerProvider) == null) {
        ref.read(wsSelectedCustomerProvider.notifier).state = _kWalkIn;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {required _SnackType type}) {
    final color = type == _SnackType.success
        ? EnhancedTheme.successGreen
        : type == _SnackType.error
            ? EnhancedTheme.errorRed
            : type == _SnackType.warning
                ? EnhancedTheme.warningAmber
                : EnhancedTheme.infoBlue;
    final icon = type == _SnackType.success
        ? Icons.check_circle_rounded
        : type == _SnackType.error
            ? Icons.error_rounded
            : type == _SnackType.warning
                ? Icons.warning_amber_rounded
                : Icons.info_rounded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(icon, color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  // ── Barcode scanning ───────────────────────────────────────────────────────

  Future<void> _onBarcodeScanned(String code) async {
    final trimmed = code.trim();
    final lower   = trimmed.toLowerCase();
    Item? match = ref.read(wholesaleBarcodeLookupProvider)[lower];
    match ??= await ref.read(inventoryApiProvider).fetchItemByBarcode(trimmed);
    if (!mounted) return;
    if (match == null) {
      _showSnackBar('Item not found for barcode: $trimmed', type: _SnackType.error);
      return;
    }
    if (match.stock == 0) {
      _showSnackBar('${match.name} is out of stock', type: _SnackType.error);
      return;
    }
    final cart  = ref.read(wsCartProvider);
    final inCart = cart.where((l) => l.id == match!.id).fold<double>(0, (s, l) => s + l.qty);
    if (inCart >= match.stock) {
      _showSnackBar('${match.name} — maximum stock in cart', type: _SnackType.error);
      return;
    }
    ref.read(wsCartProvider.notifier).addItem(match);
    _showSnackBar('${match.name} added to cart', type: _SnackType.success);
  }

  Color _categoryColor(Item item) {
    final name = item.name.toLowerCase();
    if (name.contains('pain') || name.contains('analg') ||
        name.contains('ibuprofen') || name.contains('aspirin')) { return EnhancedTheme.errorRed; }
    if (name.contains('antibiotic') || name.contains('amoxicil') ||
        name.contains('cipro')) { return EnhancedTheme.accentPurple; }
    if (name.contains('vitamin') || name.contains('supplement') ||
        name.contains('zinc')) { return EnhancedTheme.successGreen; }
    if (name.contains('antiviral') || name.contains('acyclo')) { return EnhancedTheme.infoBlue; }
    return EnhancedTheme.accentCyan;
  }

  // ── Branch picker ──────────────────────────────────────────────────────────

  void _showBranchPicker(BuildContext context) {
    if (!ref.read(canSwitchBranchProvider)) return; // non-admins cannot switch
    final user = ref.read(currentUserProvider);
    if ((user?.branchId ?? 0) != 0) return;

    final branches = ref.read(branchListProvider);
    final active   = branches.where((b) => b.isActive).toList();
    final userRole = user?.role ?? '';
    final isAdmin  = const {'Admin', 'Manager', 'Wholesale Manager'}.contains(userRole);
    final current  = ref.read(activeBranchProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Select Branch',
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            if (isAdmin) _branchPickerTile(
              ctx: ctx,
              icon: Icons.business_rounded,
              label: 'All Branches',
              subtitle: 'Show items across all branches',
              isSelected: current == null || current.id <= 0,
              onTap: () {
                ref.read(activeBranchProvider.notifier).state = null;
                ref.invalidate(wholesaleInventoryProvider);
                Navigator.pop(ctx);
              },
            ),
            if (isAdmin && active.isNotEmpty) const Divider(color: Colors.white12, height: 16),
            ...active.map((b) => _branchPickerTile(
              ctx: ctx,
              icon: b.isMain ? Icons.home_work_rounded : Icons.store_outlined,
              label: b.name,
              subtitle: b.address.isNotEmpty ? b.address : null,
              badge: b.isMain ? 'Main' : null,
              isSelected: current?.id == b.id,
              onTap: () {
                ref.read(activeBranchProvider.notifier).state = b;
                ref.invalidate(wholesaleInventoryProvider);
                Navigator.pop(ctx);
              },
            )),
            if (active.isEmpty && !isAdmin)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No branches available.',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _branchPickerTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    String? subtitle,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? EnhancedTheme.accentCyan.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
              : Colors.white12,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Icon(icon, color: isSelected ? EnhancedTheme.accentCyan : Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: isSelected ? EnhancedTheme.accentCyan : Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: EnhancedTheme.accentCyan, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: EnhancedTheme.accentCyan, size: 18),
      ]),
    ),
  );

  // ── Customer picker ────────────────────────────────────────────────────────

  void _showCustomerPicker(List<Customer> customers) {
    const kWalkInId   = -1;
    const kWalkInName = 'Walk-in Customer';

    final searchCtrl  = TextEditingController();
    final wsCustomers = customers.where((c) => c.isWholesale).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.85, minChildSize: 0.3,
        builder: (ctx, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setSheetState) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: ctx.isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: ctx.borderColor),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.store_rounded,
                            color: EnhancedTheme.accentCyan, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text('Select Customer',
                          style: GoogleFonts.outfit(color: ctx.labelColor,
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(wsSelectedCustomerProvider.notifier).state = _kWalkIn;
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.clear_rounded,
                            size: 14, color: EnhancedTheme.errorRed),
                        label: const Text('Clear',
                            style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 13)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      style: TextStyle(color: ctx.labelColor),
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone…',
                        hintStyle: TextStyle(color: ctx.hintColor),
                        prefixIcon: Icon(Icons.search_rounded, color: ctx.hintColor, size: 20),
                        filled: true, fillColor: ctx.cardColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Walk-in shortcut
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Builder(builder: (_) {
                      final current   = ref.watch(wsSelectedCustomerProvider);
                      final isWalkIn  = current?.id == kWalkInId;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWalkIn
                                ? EnhancedTheme.accentOrange.withValues(alpha: 0.4)
                                : ctx.borderColor,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            tileColor: isWalkIn
                                ? EnhancedTheme.accentOrange.withValues(alpha: 0.1)
                                : ctx.cardColor,
                            onTap: () {
                              ref.read(wsSelectedCustomerProvider.notifier).state =
                                  const WsSelectedCustomer(
                                    id: kWalkInId,
                                    name: kWalkInName,
                                    walletBalance: 0,
                                  );
                              Navigator.pop(ctx);
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.accentOrange.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_outline_rounded,
                                  color: EnhancedTheme.accentOrange, size: 18),
                            ),
                            title: Text(kWalkInName,
                                style: TextStyle(color: ctx.labelColor,
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text('No account required',
                                style: TextStyle(color: ctx.hintColor, fontSize: 12)),
                            trailing: isWalkIn
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: EnhancedTheme.accentOrange.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded,
                                        color: EnhancedTheme.accentOrange, size: 14))
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: Builder(builder: (_) {
                    final q        = searchCtrl.text.toLowerCase();
                    final filtered = wsCustomers
                        .where((c) =>
                            c.name.toLowerCase().contains(q) || c.phone.contains(q))
                        .toList();
                    if (filtered.isEmpty) {
                      return Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                                EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                              ]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.people_outline_rounded,
                                color: EnhancedTheme.accentCyan, size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text('No wholesale customers found',
                              style: GoogleFonts.inter(
                                  color: ctx.subLabelColor, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Try a different search term',
                              style: TextStyle(color: ctx.hintColor, fontSize: 12)),
                        ],
                      ));
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final current    = ref.watch(wsSelectedCustomerProvider);
                        final isSelected = current?.id == c.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                                  : ctx.borderColor,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              tileColor: isSelected
                                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.1)
                                  : ctx.cardColor,
                              onTap: () {
                                ref.read(wsSelectedCustomerProvider.notifier).state =
                                    WsSelectedCustomer(
                                      id: c.id,
                                      name: c.name,
                                      walletBalance: c.walletBalance,
                                    );
                                Navigator.pop(ctx);
                              },
                              leading: CircleAvatar(
                                backgroundColor:
                                    EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.outfit(
                                      color: EnhancedTheme.accentCyan,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(c.name,
                                  style: TextStyle(color: ctx.labelColor,
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                              isThreeLine: c.walletBalance > 0 && c.outstandingDebt > 0,
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.phone,
                                    style: TextStyle(
                                        color: ctx.subLabelColor, fontSize: 12)),
                                if (c.walletBalance > 0)
                                  Text('Wallet: ${fmtN(c.walletBalance)}',
                                      style: const TextStyle(
                                          color: EnhancedTheme.successGreen,
                                          fontSize: 11, fontWeight: FontWeight.w600)),
                                if (c.outstandingDebt > 0)
                                  Text('Debt: ${fmtN(c.outstandingDebt)}',
                                      style: const TextStyle(
                                          color: EnhancedTheme.errorRed,
                                          fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                              trailing: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded,
                                          color: EnhancedTheme.accentCyan, size: 14))
                                  : null,
                            ),
                          ),
                        );
                      },
                    );
                  })),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(wholesaleInventoryProvider);
    final customersAsync = ref.watch(customerListProvider);
    final cart           = ref.watch(wsCartProvider);
    final cartCount      = cart.fold(0.0, (s, l) => s + l.qty);
    final wide           = MediaQuery.of(context).size.width > 800;

    final filteredAsync = inventoryAsync.whenData((items) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isEmpty) return items;
      return items.where((i) =>
          i.name.toLowerCase().contains(q) ||
          i.brand.toLowerCase().contains(q) ||
          i.barcode.toLowerCase().contains(q)).toList();
    });

    return HardwareScannerListener(
      onBarcodeScanned: _onBarcodeScanned,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        drawer: const AppDrawer(),
        body: Stack(children: [
          Container(decoration: context.bgGradient),
          SafeArea(child: Column(children: [
            _header(context, cartCount),
            _customerRow(context, customersAsync),
            Expanded(child: wide
                ? Row(children: [
                    Expanded(flex: 3, child: _itemsPanel(filteredAsync, cart)),
                    VerticalDivider(width: 1, color: context.borderColor),
                    Expanded(flex: 2, child: _cartPanel(cart)),
                  ])
                : _itemsPanel(filteredAsync, cart)),
          ])),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, double cartCount) {
    final itemCount =
        ref.watch(wholesaleInventoryProvider).whenOrNull(data: (l) => l.length);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            EnhancedTheme.accentCyan.withValues(alpha: 0.2),
            EnhancedTheme.accentPurple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Builder(builder: (ctx) => GestureDetector(
          onTap: () => ctx.canPop()
              ? ctx.pop()
              : Scaffold.of(ctx).openDrawer(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              ctx.canPop() ? Icons.arrow_back_rounded : Icons.menu_rounded,
              color: Colors.black, size: 18),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wholesale POS',
              style: GoogleFonts.outfit(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
          Row(children: [
            Flexible(child: Builder(builder: (_) {
              final activeBranch = ref.watch(activeBranchProvider);
              final label = (activeBranch != null && activeBranch.id > 0)
                  ? activeBranch.name
                  : 'All Branches';
              final isSpecific = activeBranch != null && activeBranch.id > 0;
              final canSwitch = ref.watch(canSwitchBranchProvider);
              return GestureDetector(
                onTap: canSwitch ? () => _showBranchPicker(context) : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSpecific
                          ? EnhancedTheme.accentCyan.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSpecific
                            ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                            : Colors.black26,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        isSpecific ? Icons.store_rounded : Icons.business_rounded,
                        color: isSpecific ? EnhancedTheme.accentCyan : Colors.black54,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isSpecific ? EnhancedTheme.accentCyan : Colors.black54,
                              fontSize: 10, fontWeight: FontWeight.w700)),
                      if (canSwitch) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.expand_more_rounded,
                            color: isSpecific ? EnhancedTheme.accentCyan : Colors.black54,
                            size: 10),
                      ],
                    ]),
                  ),
                ),
              );
            })),
            if (itemCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$itemCount items',
                    style: const TextStyle(
                        color: EnhancedTheme.accentPurple, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ])),
        GestureDetector(
          onTap: () => setState(() => _gridView = !_gridView),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(
                _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: Colors.black, size: 18),
          ),
        ),
        if (cartCount > 0) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const WholesaleCartScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.4),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_cart_rounded, color: Colors.black, size: 13),
                const SizedBox(width: 4),
                Text(fmtWsQty(cartCount),
                    style: const TextStyle(
                        color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }

  // ── Customer Row ────────────────────────────────────────────────────────────

  Widget _customerRow(BuildContext context, AsyncValue<List<Customer>> customersAsync) {
    final selected   = ref.watch(wsSelectedCustomerProvider);
    final isWalkIn   = selected?.id == -1;
    final hasCustomer = selected != null;
    final accentColor = isWalkIn ? EnhancedTheme.accentOrange : EnhancedTheme.accentCyan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GestureDetector(
        onTap: () => _showCustomerPicker(customersAsync.valueOrNull ?? []),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: hasCustomer
                ? accentColor.withValues(alpha: 0.1)
                : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasCustomer
                  ? accentColor.withValues(alpha: 0.4)
                  : context.borderColor,
              width: hasCustomer ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (hasCustomer ? accentColor : context.hintColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isWalkIn ? Icons.person_outline_rounded : Icons.store_rounded,
                color: hasCustomer ? accentColor : context.hintColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: hasCustomer
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(selected.name,
                        style: TextStyle(color: context.labelColor,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (isWalkIn)
                      Text('No account required',
                          style: TextStyle(color: context.hintColor, fontSize: 11))
                    else
                      Row(children: [
                        const Icon(Icons.account_balance_wallet_rounded,
                            color: EnhancedTheme.successGreen, size: 11),
                        const SizedBox(width: 4),
                        Text(fmtN(selected.walletBalance),
                            style: const TextStyle(
                                color: EnhancedTheme.successGreen,
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                  ])
                : Text('Select wholesale customer',
                    style: TextStyle(color: context.hintColor, fontSize: 13))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: hasCustomer ? accentColor : context.hintColor, size: 20),
          ]),
        ),
      ),
    );
  }

  // ── Items Panel ────────────────────────────────────────────────────────────

  Widget _itemsPanel(AsyncValue<List<Item>> filtered, List<WsCartLine> cart) {
    final wide = MediaQuery.of(context).size.width > 800;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: context.labelColor),
              decoration: InputDecoration(
                hintText: 'Search items by name, brand, barcode…',
                hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: context.hintColor, size: 16),
                        onPressed: () => setState(() => _searchCtrl.clear()))
                    : null,
                filled: true, fillColor: context.cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showBarcodeScannerSheet(context, _onBarcodeScanned),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: EnhancedTheme.primaryTeal, size: 22),
            ),
          ),
        ]),
      ),
      Expanded(child: filtered.when(
        loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: EnhancedTheme.accentCyan, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Loading catalogue…', style: TextStyle(color: context.hintColor, fontSize: 13)),
        ])),
        error: (e, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Failed to load items',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('$e',
                style: TextStyle(color: context.subLabelColor, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(wholesaleInventoryProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: EnhancedTheme.accentCyan),
              label: const Text('Retry', style: TextStyle(color: EnhancedTheme.accentCyan)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: EnhancedTheme.accentCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        )),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    EnhancedTheme.accentPurple.withValues(alpha: 0.08),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: EnhancedTheme.accentCyan, size: 40),
              ),
              const SizedBox(height: 16),
              Text('No items found',
                  style: GoogleFonts.outfit(
                      color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                _searchCtrl.text.isEmpty
                    ? 'Add wholesale items from inventory'
                    : 'Try a different search term',
                style: TextStyle(color: context.subLabelColor, fontSize: 13),
              ),
            ]));
          }
          return _gridView
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueGridCard(items[i], cart, wide)
                      .animate(delay: (i * 30).ms)
                      .fadeIn(duration: 250.ms)
                      .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _catalogueListItem(items[i], cart, wide)
                      .animate(delay: (i * 25).ms)
                      .fadeIn(duration: 250.ms)
                      .slideX(begin: 0.05, end: 0),
                );
        },
      )),
    ]);
  }

  Widget _catalogueListItem(Item item, List<WsCartLine> cart, bool wide) {
    final cartLine   = cart.where((l) => l.id == item.id).firstOrNull;
    final inCart     = cartLine != null;
    final atMax      = (cartLine?.qty ?? 0) >= item.stock && item.stock > 0;
    final outOfStock = item.stock == 0;
    final lowStock   = item.stock > 0 && item.stock <= item.lowStockThreshold;
    final accentColor = outOfStock ? context.hintColor : _categoryColor(item);

    void onAdd() {
      if (outOfStock || atMax) return;
      ref.read(wsCartProvider.notifier).addItem(item);
      if (!wide) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const WholesaleCartScreen()));
      }
    }

    return GestureDetector(
      onTap: onAdd,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: outOfStock
                ? context.cardColor.withValues(alpha: 0.3)
                : inCart
                    ? EnhancedTheme.accentCyan.withValues(alpha: 0.07)
                    : context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart
                  ? EnhancedTheme.accentCyan.withValues(alpha: 0.35)
                  : context.borderColor,
              width: inCart ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accentColor.withValues(alpha: outOfStock ? 0.08 : 0.18),
                  accentColor.withValues(alpha: outOfStock ? 0.04 : 0.08),
                ]),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.medication_rounded, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: TextStyle(
                      color: outOfStock ? context.hintColor : context.labelColor,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (item.brand.isNotEmpty)
                Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: outOfStock
                      ? EnhancedTheme.errorRed.withValues(alpha: 0.1)
                      : lowStock
                          ? EnhancedTheme.warningAmber.withValues(alpha: 0.1)
                          : EnhancedTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  outOfStock
                      ? 'Out of stock'
                      : lowStock
                          ? '${item.stock} left — low'
                          : '${item.stock} in stock',
                  style: TextStyle(
                    color: outOfStock
                        ? EnhancedTheme.errorRed
                        : lowStock
                            ? EnhancedTheme.warningAmber
                            : EnhancedTheme.successGreen,
                    fontSize: 10, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('₦', style: TextStyle(
                    color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
                    fontSize: 11, fontWeight: FontWeight.w600)),
                Text(fmtNum(item.price),
                    style: TextStyle(
                        color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                if (item.unitOfDispensing.isNotEmpty)
                  Text('/${item.unitOfDispensing}',
                      style: TextStyle(
                          color: outOfStock ? context.hintColor : context.subLabelColor,
                          fontSize: 10)),
              ]),
              const SizedBox(height: 6),
              if (!outOfStock)
                atMax
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Max in cart',
                            style: TextStyle(
                                color: EnhancedTheme.warningAmber,
                                fontSize: 10, fontWeight: FontWeight.w600)))
                    : GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: inCart
                                ? const LinearGradient(
                                    colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple])
                                : null,
                            color: inCart ? null : context.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: inCart
                                ? null
                                : Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.5)),
                          ),
                          child: Text(inCart ? '+ More' : 'Add',
                              style: TextStyle(
                                  color: inCart ? Colors.black : EnhancedTheme.accentCyan,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
            ]),
          ]),
        ),
      ),
    ));
  }

  Widget _catalogueGridCard(Item item, List<WsCartLine> cart, bool wide) {
    final cartLine   = cart.where((l) => l.id == item.id).firstOrNull;
    final inCart     = cartLine != null;
    final atMax      = (cartLine?.qty ?? 0) >= item.stock && item.stock > 0;
    final outOfStock = item.stock == 0;
    final lowStock   = item.stock > 0 && item.stock <= item.lowStockThreshold;
    final accentColor = outOfStock ? context.hintColor : _categoryColor(item);

    void onTap() {
      if (outOfStock || atMax) return;
      ref.read(wsCartProvider.notifier).addItem(item);
      if (!wide) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const WholesaleCartScreen()));
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: outOfStock
                  ? context.cardColor.withValues(alpha: 0.3)
                  : inCart
                      ? EnhancedTheme.accentCyan.withValues(alpha: 0.08)
                      : context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: inCart
                    ? EnhancedTheme.accentCyan.withValues(alpha: 0.45)
                    : context.borderColor,
                width: inCart ? 1.5 : 1.0,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accentColor.withValues(alpha: outOfStock ? 0.08 : 0.2),
                      accentColor.withValues(alpha: outOfStock ? 0.04 : 0.1),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.medication_rounded, color: accentColor, size: 18),
                ),
                if ((cartLine?.qty ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(fmtWsQty(cartLine!.qty),
                        style: const TextStyle(
                            color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const Spacer(),
              Text(item.name,
                  style: TextStyle(
                      color: outOfStock ? context.hintColor : context.labelColor,
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(fmtN(item.price),
                  style: TextStyle(
                      color: outOfStock ? context.hintColor : EnhancedTheme.accentCyan,
                      fontSize: 14, fontWeight: FontWeight.w800)),
              if (item.unitOfDispensing.isNotEmpty)
                Text('/${item.unitOfDispensing}',
                    style: TextStyle(
                        color: outOfStock ? context.hintColor : context.subLabelColor,
                        fontSize: 9)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: outOfStock
                      ? EnhancedTheme.errorRed.withValues(alpha: 0.1)
                      : (atMax || lowStock)
                          ? EnhancedTheme.warningAmber.withValues(alpha: 0.1)
                          : EnhancedTheme.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  outOfStock
                      ? 'Out of stock'
                      : atMax
                          ? 'Max in cart'
                          : '${item.stock} left',
                  style: TextStyle(
                    color: outOfStock
                        ? EnhancedTheme.errorRed
                        : (atMax || lowStock)
                            ? EnhancedTheme.warningAmber
                            : EnhancedTheme.successGreen,
                    fontSize: 9, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Cart Panel (wide layout only) ─────────────────────────────────────────

  Widget _cartPanel(List<WsCartLine> cart) {
    final cartTotal = cart.fold(0.0, (s, l) => s + l.total);
    final cartCount = cart.fold(0.0, (s, l) => s + l.qty);

    return Column(children: [
      Expanded(child: cart.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                    EnhancedTheme.accentPurple.withValues(alpha: 0.06),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined, color: context.hintColor, size: 28),
              ),
              const SizedBox(height: 10),
              Text('Cart is empty',
                  style: GoogleFonts.outfit(
                      color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Tap any item to add',
                  style: TextStyle(color: context.subLabelColor, fontSize: 11)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: cart.length,
              itemBuilder: (_, i) => WsCartItemWidget(
                key: ValueKey(cart[i].id),
                line: cart[i],
                onQtyChange:      (id, qty)     => ref.read(wsCartProvider.notifier).updateQty(id, qty),
                onRemove:         (id)           => ref.read(wsCartProvider.notifier).removeItem(id),
                onDiscountChange: (id, discount) => ref.read(wsCartProvider.notifier).updateDiscount(id, discount),
              ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0),
            )),
      if (cart.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                        EnhancedTheme.accentPurple.withValues(alpha: 0.08),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${cart.length} lines · ${fmtWsQty(cartCount)} units',
                            style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                        const Text('Order Total',
                            style: TextStyle(color: Colors.black87, fontSize: 12)),
                      ]),
                      Text(fmtN(cartTotal),
                          style: GoogleFonts.outfit(
                              color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.35),
                          blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const WholesaleCartScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Checkout',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

enum _SnackType { success, error, warning }
