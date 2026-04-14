import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart';
import 'package:pharmapp/core/offline/sync_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/widgets/paywall_widget.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import '../providers/inventory_provider.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _filter    = 'All';
  bool   _isGrid    = false;
  late final TabController _tabCtrl;

  final _filters = ['All', 'Low Stock', 'Expired', 'Expiring Soon'];

  @override
  void initState() {
    super.initState();
    final role = ref.read(currentUserProvider)?.role ?? '';
    final isWholesale = ['Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson']
        .contains(role);
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: isWholesale ? 1 : 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _currentStore => _tabCtrl.index == 0 ? 'retail' : 'wholesale';

  void _invalidateCurrent() {
    if (_tabCtrl.index == 0) {
      ref.invalidate(retailInventoryProvider);
    } else {
      ref.invalidate(wholesaleInventoryProvider);
    }
  }

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

  void _showBranchPicker(BuildContext context) {
    final branches   = ref.read(branchListProvider);
    final active     = branches.where((b) => b.isActive).toList();
    final userRole   = ref.read(currentUserProvider)?.role ?? '';
    final isAdmin    = const {'Admin', 'Manager', 'Wholesale Manager'}.contains(userRole);
    final current    = ref.read(activeBranchProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.store_rounded, color: EnhancedTheme.primaryTeal, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Select Branch',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          // All Branches option (admins only)
          if (isAdmin) _branchPickerTile(
            ctx: ctx,
            icon: Icons.business_rounded,
            label: 'All Branches',
            subtitle: 'Show inventory across all branches',
            isSelected: current == null || current.id <= 0,
            onTap: () {
              ref.read(activeBranchProvider.notifier).state = null;
              ref.invalidate(retailInventoryProvider);
              ref.invalidate(wholesaleInventoryProvider);
              Navigator.pop(ctx);
            },
          ),
          if (isAdmin && active.isNotEmpty) Divider(color: context.borderColor, height: 16),
          // Individual branch tiles
          ...active.map((b) => _branchPickerTile(
            ctx: ctx,
            icon: b.isMain ? Icons.home_work_rounded : Icons.store_outlined,
            label: b.name,
            subtitle: b.address.isNotEmpty ? b.address : null,
            badge: b.isMain ? 'Main' : null,
            isSelected: current?.id == b.id,
            onTap: () {
              ref.read(activeBranchProvider.notifier).state = b;
              ref.invalidate(retailInventoryProvider);
              ref.invalidate(wholesaleInventoryProvider);
              Navigator.pop(ctx);
            },
          )),
          if (active.isEmpty && !isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No branches available.',
                  style: TextStyle(color: context.subLabelColor, fontSize: 13)),
            ),
        ]),
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
        color: isSelected
            ? EnhancedTheme.primaryTeal.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4) : context.borderColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Icon(icon,
            color: isSelected ? EnhancedTheme.primaryTeal : context.subLabelColor,
            size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: isSelected ? EnhancedTheme.primaryTeal : context.labelColor,
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: EnhancedTheme.primaryTeal, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          if (subtitle != null)
            Text(subtitle,
                style: TextStyle(color: context.hintColor, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: EnhancedTheme.primaryTeal, size: 18),
      ]),
    ),
  );

  void _showAddItemSheet(BuildContext context) {
    final nameCtrl    = TextEditingController();
    final brandCtrl   = TextEditingController();
    final costCtrl    = TextEditingController();
    final priceCtrl   = TextEditingController();
    final stockCtrl   = TextEditingController();
    final barcodeCtrl = TextEditingController();
    String form       = 'Tablet';
    double markup     = 0.0;
    String store      = _currentStore;
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Handle
                  Center(child: Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(
                      color: context.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_circle_rounded, color: EnhancedTheme.primaryTeal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Add New Item',
                        style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 24),
                  _sheetField(nameCtrl, 'Item Name *', validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  _sheetField(brandCtrl, 'Brand / Manufacturer'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _sheetField(costCtrl, 'Cost Price (₦)',
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final cost = double.tryParse(v) ?? 0;
                          if (cost > 0 && markup > 0) {
                            priceCtrl.text = (cost * (1 + markup / 100)).toStringAsFixed(0);
                            setModal(() {});
                          }
                        })),
                    const SizedBox(width: 12),
                    Expanded(child: _sheetField(stockCtrl, 'Stock Qty *',
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null)),
                  ]),
                  const SizedBox(height: 12),
                  // Markup selector
                  Text('Markup %', style: TextStyle(color: context.hintColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [0.0, 2.5, 5.0, 7.5, 10.0, 12.5, 15.0, 17.5, 20.0, 22.5, 25.0, 27.5, 30.0, 35.0, 40.0, 45.0, 50.0, 60.0, 70.0, 80.0, 100.0].map((m) =>
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            final cost = double.tryParse(costCtrl.text) ?? 0;
                            setModal(() {
                              markup = m;
                              if (cost > 0) priceCtrl.text = (cost * (1 + m / 100)).toStringAsFixed(0);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: markup == m ? EnhancedTheme.successGreen.withValues(alpha: 0.15) : ctx.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: markup == m ? EnhancedTheme.successGreen : ctx.borderColor, width: markup == m ? 1.5 : 1),
                            ),
                            child: Text('${m % 1 == 0 ? m.toInt() : m}%', style: TextStyle(
                                color: markup == m ? EnhancedTheme.successGreen : ctx.subLabelColor,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      )).toList()),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _sheetField(priceCtrl, 'Selling Price (₦) *',
                        keyboardType: TextInputType.number,
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
                  ]),
                  const SizedBox(height: 12),
                  _sheetField(barcodeCtrl, 'Barcode (optional)', keyboardType: TextInputType.number),
                  const SizedBox(height: 20),
                  // Store selector
                  Text('Store', style: TextStyle(color: context.hintColor, fontSize: 12, fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Row(children: ['retail', 'wholesale'].map((s) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setModal(() => store = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: store == s
                              ? const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan])
                              : null,
                          color: store == s ? null : ctx.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: store == s ? EnhancedTheme.primaryTeal : ctx.borderColor,
                              width: store == s ? 0 : 1),
                          boxShadow: store == s
                              ? [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(store == s ? Icons.check_circle_rounded : Icons.circle_outlined,
                              size: 14, color: store == s ? Colors.black : ctx.subLabelColor),
                          const SizedBox(width: 6),
                          Text(s == 'retail' ? 'Retail' : 'Wholesale',
                              style: TextStyle(color: store == s ? Colors.black : ctx.subLabelColor,
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  )).toList()),
                  const SizedBox(height: 20),
                  // Dosage form chips
                  Text('Dosage Form', style: TextStyle(color: context.hintColor, fontSize: 12, fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: ['Tablet','Capsule','Cream','Consumable','Galenical','Injection','Infusion','Inhaler','Suspension','Syrup','Drops','Solution','Eye-drop','Ear-drop','Eye-ointment','Rectal','Vaginal','Detergent','Drinks','Paste','Patch','Table-water','Food-item','Sweets','Soaps','Biscuits'].map((f) =>
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setModal(() => form = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: form == f ? EnhancedTheme.accentPurple.withValues(alpha: 0.15) : ctx.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: form == f ? EnhancedTheme.accentPurple : ctx.borderColor,
                                  width: form == f ? 1.5 : 1),
                            ),
                            child: Text(f, style: TextStyle(
                                color: form == f ? EnhancedTheme.accentPurple : ctx.subLabelColor,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      )).toList()),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final data = {
                        'name':              nameCtrl.text.trim(),
                        'brand':             brandCtrl.text.trim().isEmpty ? 'Unknown' : brandCtrl.text.trim(),
                        'dosageForm':        form,
                        'costPrice':         double.tryParse(costCtrl.text) ?? 0.0,
                        'markup':            markup,
                        'price':             double.parse(priceCtrl.text),
                        'stock':             int.parse(stockCtrl.text),
                        'lowStockThreshold': 20,
                        'barcode':           barcodeCtrl.text.trim().isEmpty ? 'N/A' : barcodeCtrl.text.trim(),
                        'store':             store,
                      };
                      // Inject active branch_id so item is assigned to correct branch.
                      final branchId = ref.read(activeBranchProvider)?.id;
                      if (branchId != null && branchId > 0) data['branch_id'] = branchId;

                      Navigator.of(ctx).pop();
                      try {
                        // Use notifier so branch_id injection and offline caching are handled.
                        final created = await ref.read(inventoryNotifierProvider.notifier).createItem(data);
                        if (!context.mounted) return;
                        final notifierState = ref.read(inventoryNotifierProvider);
                        if (notifierState.hasError) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Error: ${notifierState.error}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } else if (created != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${data['name']} added to ${(data['store'] as String).toUpperCase()}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } else {
                          // null + no error = queued offline by notifier
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: const Row(children: [
                              Icon(Icons.cloud_off_rounded, color: Colors.black, size: 20),
                              SizedBox(width: 10),
                              Expanded(child: Text('Offline — item queued for sync', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                          content: Row(children: [
                            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Error: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                          ]),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('Add Item',
                            style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label,
      {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, void Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl, keyboardType: keyboardType, validator: validator, onChanged: onChanged,
      style: TextStyle(color: context.labelColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.hintColor, fontSize: 13),
        filled: true, fillColor: context.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 2)),
        errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Item', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blobs
        Positioned(top: -60, right: -40,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.07)))),
        Positioned(top: 80, left: -50,
          child: Container(width: 150, height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.accentCyan.withValues(alpha: 0.05)))),
        SafeArea(child: Column(children: [
          _buildHeader(context),
          const UsageLimitWarning(limitType: 'items'),
          _buildSearchBar(),
          _buildFilterChips(),
          // Store tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    onTap: (_) => setState(() {}),
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                          blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.black,
                    unselectedLabelColor: context.subLabelColor,
                    labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: 'Retail'),
                      Tab(text: 'Wholesale'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Tab content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (ref.read(isOnlineProvider)) {
                  await ref.read(syncServiceProvider).syncAll();
                }
                ref.invalidate(retailInventoryProvider);
                ref.invalidate(wholesaleInventoryProvider);
              },
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _StoreInventoryView(
                    store: 'retail',
                    filter: _filter,
                    isGrid: _isGrid,
                    applyFilter: _applyFilter,
                  ),
                  _StoreInventoryView(
                    store: 'wholesale',
                    filter: _filter,
                    isGrid: _isGrid,
                    applyFilter: _applyFilter,
                  ),
                ],
              ),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
    child: Row(children: [
      Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Builder(builder: (ctx) => IconButton(
          icon: Icon(
            ctx.canPop() ? Icons.arrow_back_rounded : Icons.menu_rounded,
            color: context.labelColor, size: 20),
          onPressed: () => ctx.canPop()
              ? ctx.pop()
              : Scaffold.of(ctx).openDrawer(),
        )),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Inventory',
            style: GoogleFonts.outfit(color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w800)),
        Builder(builder: (ctx) {
          final activeBranch = ref.watch(activeBranchProvider);
          final label = (activeBranch != null && activeBranch.id > 0)
              ? activeBranch.name
              : 'All Branches';
          final isSpecific = activeBranch != null && activeBranch.id > 0;
          return GestureDetector(
            onTap: () => _showBranchPicker(context),
            child: Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSpecific
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.12)
                    : context.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSpecific
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.3)
                      : context.borderColor,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isSpecific ? Icons.store_rounded : Icons.business_rounded,
                  color: isSpecific ? EnhancedTheme.primaryTeal : context.subLabelColor,
                  size: 10,
                ),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: isSpecific ? EnhancedTheme.primaryTeal : context.subLabelColor,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded,
                    color: isSpecific ? EnhancedTheme.primaryTeal : context.subLabelColor,
                    size: 10),
              ]),
            ),
          );
        }),
      ])),
      Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: IconButton(
          icon: Icon(_isGrid ? Icons.list_rounded : Icons.grid_view_rounded,
              color: _isGrid ? EnhancedTheme.primaryTeal : context.subLabelColor, size: 20),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: IconButton(
          icon: Icon(Icons.refresh_rounded, color: context.subLabelColor, size: 20),
          onPressed: _invalidateCurrent,
        ),
      ),
    ]),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
    child: ClipRRect(borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name, brand, barcode…',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: EnhancedTheme.primaryTeal, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: context.hintColor, size: 18),
                    onPressed: () => setState(() => _searchCtrl.clear()),
                  )
                : null,
            filled: true,
            fillColor: context.cardColor,
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
  ).animate().fadeIn(duration: 400.ms, delay: 100.ms);

  Widget _buildFilterChips() => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = _filters[i];
        final active = f == _filter;
        Color chipColor = EnhancedTheme.primaryTeal;
        if (f == 'Low Stock') chipColor = EnhancedTheme.warningAmber;
        if (f == 'Expired') chipColor = EnhancedTheme.errorRed;
        if (f == 'Expiring Soon') chipColor = EnhancedTheme.accentOrange;
        return GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: active ? chipColor.withValues(alpha: 0.15) : context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? chipColor : context.borderColor,
                  width: active ? 1.5 : 1),
              boxShadow: active
                  ? [BoxShadow(color: chipColor.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Text(f, style: TextStyle(
                color: active ? chipColor : context.subLabelColor,
                fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
      },
    ),
  ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
}

// ── Per-store inventory view ──────────────────────────────────────────────────

class _StoreInventoryView extends ConsumerWidget {
  final String store;
  final String filter;
  final bool isGrid;
  final List<Item> Function(List<Item>) applyFilter;

  const _StoreInventoryView({
    required this.store,
    required this.filter,
    required this.isGrid,
    required this.applyFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = store == 'retail'
        ? ref.watch(retailInventoryProvider)
        : ref.watch(wholesaleInventoryProvider);

    return inventoryAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: List.generate(5, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EnhancedTheme.loadingShimmer(height: 76, radius: 18),
        )),
      ),
      error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Connection failed', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => store == 'retail'
              ? ref.invalidate(retailInventoryProvider)
              : ref.invalidate(wholesaleInventoryProvider),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ])),
      data: (items) {
        final filtered = applyFilter(items);
        if (filtered.isEmpty) return _emptyState(context);
        return isGrid ? _buildGrid(context, filtered) : _buildList(context, filtered);
      },
    );
  }

  Widget _buildList(BuildContext context, List<Item> items) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
    itemCount: items.length,
    itemBuilder: (_, i) => _itemCard(context, items[i])
        .animate(delay: (i * 40).ms)
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.05, end: 0),
  );

  Widget _buildGrid(BuildContext context, List<Item> items) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
      mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.95),
    itemCount: items.length,
    itemBuilder: (_, i) => _itemGridCard(context, items[i])
        .animate(delay: (i * 40).ms)
        .fadeIn(duration: 350.ms)
        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
  );

  Color _stockColor(Item item) {
    if (item.stock == 0) return EnhancedTheme.errorRed;
    if (item.stock <= item.lowStockThreshold) return EnhancedTheme.warningAmber;
    return EnhancedTheme.successGreen;
  }

  Widget _itemCard(BuildContext context, Item item) {
    final sc  = _stockColor(item);
    final now = DateTime.now();
    final exp = item.expiryDate != null && item.expiryDate!.isBefore(now);

    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: exp ? EnhancedTheme.errorRed.withValues(alpha: 0.06) : context.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: exp
                        ? EnhancedTheme.errorRed.withValues(alpha: 0.3)
                        : sc == EnhancedTheme.errorRed
                            ? EnhancedTheme.errorRed.withValues(alpha: 0.2)
                            : context.borderColor,
                    width: exp ? 1.5 : 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                // Icon with gradient bg
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sc.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.medication_rounded, color: sc, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name,
                      style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${item.brand}  ·  ${item.dosageForm}',
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _stockBadge(item),
                    if (exp) ...[const SizedBox(width: 6), _chip('Expired', EnhancedTheme.errorRed)],
                  ]),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₦${item.price.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                          color: EnhancedTheme.primaryTeal, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded, color: context.hintColor, size: 18),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemGridCard(BuildContext context, Item item) {
    final sc = _stockColor(item);
    return GestureDetector(
      onTap: () => context.push('/item/${item.id}'),
      child: ClipRRect(borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sc.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.medication_rounded, color: sc, size: 22),
                ),
                _stockBadge(item),
              ]),
              const SizedBox(height: 10),
              Text(item.name,
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              const Spacer(),
              Text('₦${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                      color: EnhancedTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stockBadge(Item item) {
    final c = _stockColor(item);
    final label = item.stock == 0
        ? 'Out of Stock'
        : item.stock <= item.lowStockThreshold
            ? '${item.stock} low'
            : '${item.stock} in stock';
    return _chip(label, c);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _emptyState(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [
            EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
            EnhancedTheme.primaryTeal.withValues(alpha: 0.03),
          ]),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.inventory_2_outlined, color: EnhancedTheme.primaryTeal, size: 56),
      ),
      const SizedBox(height: 20),
      Text('No items found',
          style: GoogleFonts.outfit(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('No ${store == 'retail' ? 'retail' : 'wholesale'} items match your search',
          style: TextStyle(color: context.subLabelColor, fontSize: 13)),
    ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
  );
}
