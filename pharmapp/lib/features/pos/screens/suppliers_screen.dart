import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/pos_api_provider.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<dynamic> _suppliers = [];
  List<dynamic> _procurements = [];
  bool _loadingSuppliers = true;
  bool _loadingProcurements = true;
  final _searchSupplierCtrl = TextEditingController();
  final _searchProcCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchSupplierCtrl.dispose();
    _searchProcCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSuppliers(), _loadProcurements()]);
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loadingSuppliers = true);
    try {
      final data = await ref.read(posApiProvider).fetchSuppliers();
      if (mounted) setState(() { _suppliers = data; _loadingSuppliers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  Future<void> _loadProcurements() async {
    setState(() => _loadingProcurements = true);
    try {
      final data = await ref.read(posApiProvider).fetchProcurements();
      if (mounted) setState(() { _procurements = data; _loadingProcurements = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProcurements = false);
    }
  }

  Future<void> _deleteSupplier(int id) async {
    try {
      await ref.read(posApiProvider).deleteSupplier(id);
      if (mounted) {
        setState(() => _suppliers.removeWhere((s) => s['id'] == id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('Supplier deleted', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Failed to delete: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  void _showAddProcurementSheet() {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.info_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('Add at least one supplier first', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewProcurementSheet(
        suppliers: _suppliers,
        onCreated: _loadProcurements,
      ),
    );
  }

  void _showProcurementDetail(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProcurementDetailSheet(
        procurement: p,
        onDispatched: _loadProcurements,
      ),
    );
  }

  void _showAddSupplierSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final contactCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1A2535) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1))),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: EnhancedTheme.accentPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Text('New Supplier',
                    style: GoogleFonts.outfit(color: context.labelColor,
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 24),

              _sheetField(nameCtrl, 'Supplier Name', Icons.business_rounded,
                  EnhancedTheme.accentPurple),
              const SizedBox(height: 14),
              _sheetField(phoneCtrl, 'Phone Number', Icons.phone_rounded,
                  EnhancedTheme.primaryTeal,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _sheetField(contactCtrl, 'Contact Info (optional)',
                  Icons.info_outline_rounded, EnhancedTheme.infoBlue),
              const SizedBox(height: 24),

              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await ref.read(posApiProvider).createSupplier(
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      contactInfo: contactCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadSuppliers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Supplier added', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                        ]),
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        content: Row(children: [
                          const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                        ]),
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.accentPurple,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Add Supplier',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700,
                        fontSize: 16)),
              )),
            ]),
          ),
        );
      },
    );
  }

  void _showEditSupplierSheet(Map<String, dynamic> supplier) {
    final nameCtrl = TextEditingController(text: supplier['name'] ?? '');
    final phoneCtrl = TextEditingController(text: supplier['phone'] ?? '');
    final contactCtrl = TextEditingController(text: supplier['contactInfo'] ?? '');
    final id = supplier['id'] as int?;
    if (id == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1A2535) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1))),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: EnhancedTheme.primaryTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Edit Supplier',
                    style: GoogleFonts.outfit(color: context.labelColor,
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 24),

              _sheetField(nameCtrl, 'Supplier Name', Icons.business_rounded,
                  EnhancedTheme.accentPurple),
              const SizedBox(height: 14),
              _sheetField(phoneCtrl, 'Phone Number', Icons.phone_rounded,
                  EnhancedTheme.primaryTeal,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _sheetField(contactCtrl, 'Contact Info (optional)',
                  Icons.info_outline_rounded, EnhancedTheme.infoBlue),
              const SizedBox(height: 24),

              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await ref.read(posApiProvider).updateSupplier(
                      id,
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      contactInfo: contactCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadSuppliers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Supplier updated', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                        ]),
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        content: Row(children: [
                          const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                        ]),
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Save Changes',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700,
                        fontSize: 16)),
              )),
            ]),
          ),
        );
      },
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon,
      Color color, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: context.labelColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: color, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tabController.index == 0
            ? _showAddSupplierSheet
            : _showAddProcurementSheet,
        backgroundColor: _tabController.index == 0
            ? EnhancedTheme.accentPurple
            : EnhancedTheme.primaryTeal,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Add Supplier' : 'New Procurement',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blob
        Positioned(
          top: -60, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(child: Column(children: [
          // Header
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppShell.roleFallback(ref)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Suppliers',
                        style: GoogleFonts.outfit(color: context.labelColor,
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Manage suppliers & procurements',
                        style: GoogleFonts.inter(color: context.subLabelColor,
                            fontSize: 11)),
                  ])),
                ]),
              ),
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() {}),
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        EnhancedTheme.primaryTeal,
                        EnhancedTheme.accentCyan,
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                            blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.black,
                    unselectedLabelColor: context.subLabelColor,
                    labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16),
                          const SizedBox(width: 6),
                          const Text('Suppliers'),
                          if (_suppliers.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${_suppliers.length}',
                                  style: GoogleFonts.outfit(fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      )),
                      Tab(child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_shipping_rounded, size: 16),
                          const SizedBox(width: 6),
                          const Text('Procurements'),
                          if (_procurements.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${_procurements.length}',
                                  style: GoogleFonts.outfit(fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _buildSuppliersTab(),
              _buildProcurementsTab(),
            ],
          )),
        ])),
      ]),
    );
  }

  // ── Suppliers Tab ──────────────────────────────────────────────────────────

  Widget _buildSuppliersTab() {
    final q = _searchSupplierCtrl.text.toLowerCase();
    final filtered = _suppliers.where((s) =>
        (s['name'] ?? '').toString().toLowerCase().contains(q) ||
        (s['phone'] ?? '').toString().contains(q)).toList();

    return RefreshIndicator(
      onRefresh: _loadSuppliers,
      color: EnhancedTheme.primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _searchBar(_searchSupplierCtrl, 'Search suppliers…'),
          if (_loadingSuppliers)
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnhancedTheme.loadingShimmer(height: 90, radius: 16),
            ))
          else if (filtered.isEmpty)
            _emptyState(Icons.local_shipping_outlined, 'No suppliers found',
                'Tap + to add a new supplier')
          else
            ...filtered.asMap().entries.map((e) =>
                _supplierTile(e.value, e.key)),
        ],
      ),
    );
  }

  Widget _supplierTile(Map<String, dynamic> s, int index) {
    final name = s['name'] ?? '';
    final phone = s['phone'] ?? '';
    final contactInfo = s['contactInfo'] ?? '';
    final id = s['id'] as int?;

    // Generate avatar color from name
    final avatarColors = [
      EnhancedTheme.accentPurple,
      EnhancedTheme.primaryTeal,
      EnhancedTheme.accentCyan,
      EnhancedTheme.infoBlue,
      EnhancedTheme.successGreen,
    ];
    final avatarColor = avatarColors[name.length % avatarColors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(id ?? UniqueKey()),
        direction: DismissDirection.endToStart,
        onDismissed: (_) { if (id != null) _deleteSupplier(id); },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              EnhancedTheme.errorRed.withValues(alpha: 0.25),
            ]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.delete_rounded, color: EnhancedTheme.errorRed, size: 22),
            const SizedBox(width: 8),
            Text('Delete', style: GoogleFonts.outfit(
                color: EnhancedTheme.errorRed, fontWeight: FontWeight.w600)),
          ]),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: avatarColor.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                      color: avatarColor.withValues(alpha: 0.06),
                      blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(children: [
                // Left accent
                Container(
                  width: 4,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [avatarColor, avatarColor.withValues(alpha: 0.3)],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18)),
                  ),
                ),
                const SizedBox(width: 14),
                // Avatar
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        avatarColor,
                        avatarColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: avatarColor.withValues(alpha: 0.35),
                          blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Text(initial,
                        style: GoogleFonts.outfit(color: Colors.black,
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: GoogleFonts.outfit(color: context.labelColor,
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (phone.isNotEmpty)
                      Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.phone_rounded,
                              color: EnhancedTheme.primaryTeal, size: 12),
                        ),
                        const SizedBox(width: 6),
                        Text(phone,
                            style: GoogleFonts.inter(color: context.subLabelColor,
                                fontSize: 12)),
                      ]),
                    if (contactInfo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(contactInfo,
                          style: GoogleFonts.inter(color: context.hintColor,
                              fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                )),
                GestureDetector(
                  onTap: () => _showEditSupplierSheet(s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: EnhancedTheme.primaryTeal, size: 16),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.04, end: 0);
  }

  // ── Procurements Tab ───────────────────────────────────────────────────────

  Widget _buildProcurementsTab() {
    final q = _searchProcCtrl.text.toLowerCase();
    final filtered = _procurements.where((p) {
      final supplier =
          (p['supplier']?['name'] ?? p['supplierName'] ?? '').toString().toLowerCase();
      return supplier.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadProcurements,
      color: EnhancedTheme.primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _searchBar(_searchProcCtrl, 'Search by supplier…'),
          if (_loadingProcurements)
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnhancedTheme.loadingShimmer(height: 96, radius: 16),
            ))
          else if (filtered.isEmpty)
            _emptyState(Icons.inventory_2_outlined, 'No procurements found',
                'Tap + to create a procurement')
          else
            ...filtered.asMap().entries.map((e) =>
                _procurementTile(e.value, e.key)),
        ],
      ),
    );
  }

  Widget _procurementTile(Map<String, dynamic> p, int index) {
    final supplierName = p['supplier']?['name'] ?? p['supplierName'] ?? 'Unknown';
    final total = (p['total'] as num?)?.toDouble() ??
        (p['totalAmount'] as num?)?.toDouble() ?? 0;
    final status = (p['status'] ?? 'draft').toString().toLowerCase();
    final dateStr = p['date'] ?? p['createdAt'] ?? '';
    final isDraft = status == 'draft';
    final itemList = (p['items'] as List?) ?? [];
    final itemCount = itemList.length;
    final statusColor = isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showProcurementDetail(p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                      color: statusColor.withValues(alpha: 0.06),
                      blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(children: [
                // Top strip
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [statusColor, statusColor.withValues(alpha: 0.3)]),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    // Icon
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            statusColor.withValues(alpha: 0.25),
                            statusColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        isDraft ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                        color: statusColor, size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(supplierName,
                          style: GoogleFonts.outfit(color: context.labelColor,
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.inventory_2_outlined,
                            color: context.hintColor, size: 12),
                        const SizedBox(width: 4),
                        Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(color: context.subLabelColor,
                                fontSize: 11)),
                        const SizedBox(width: 8),
                        if (dateStr.isNotEmpty) ...[
                          Icon(Icons.calendar_today_rounded,
                              color: context.hintColor, size: 12),
                          const SizedBox(width: 4),
                          Text(dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr,
                              style: GoogleFonts.inter(
                                  color: context.subLabelColor, fontSize: 11)),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      Text('₦${total.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(color: context.labelColor,
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _statusBadge(status),
                      const SizedBox(height: 8),
                      if (isDraft)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.send_rounded,
                                color: EnhancedTheme.primaryTeal, size: 10),
                            const SizedBox(width: 4),
                            Text('Dispatch',
                                style: GoogleFonts.outfit(
                                    color: EnhancedTheme.primaryTeal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        )
                      else
                        Icon(Icons.chevron_right_rounded,
                            color: context.hintColor, size: 18),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _statusBadge(String status) {
    final isDraft = status == 'draft';
    final color = isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen;
    final label = status[0].toUpperCase() + status.substring(1);
    final icon = isDraft ? Icons.schedule_rounded : Icons.verified_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.outfit(color: color,
                fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _searchBar(TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
              Colors.transparent,
            ]),
          ),
          child: Icon(icon,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.7), size: 40),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: GoogleFonts.outfit(color: context.subLabelColor,
                fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.inter(color: context.hintColor, fontSize: 12)),
      ]),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NEW PROCUREMENT SHEET
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Procurement Line Item model ─────────────────────────────────────────────

class _ProcurementLineItem {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController brandCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();
  final TextEditingController barcodeCtrl = TextEditingController();
  String dosageForm = 'Tablet';
  String unit = 'Pack';
  int markupPct = 20;
  DateTime? expiryDate;

  double get costPrice => double.tryParse(costCtrl.text) ?? 0;
  int get quantity => int.tryParse(qtyCtrl.text) ?? 0;
  double get sellingPrice => costPrice * (1 + markupPct / 100);
  double get subtotal => costPrice * quantity;

  void dispose() {
    nameCtrl.dispose();
    brandCtrl.dispose();
    qtyCtrl.dispose();
    costCtrl.dispose();
    barcodeCtrl.dispose();
  }
}

// ─── New Procurement Bottom Sheet ────────────────────────────────────────────

class _NewProcurementSheet extends ConsumerStatefulWidget {
  final List<dynamic> suppliers;
  final VoidCallback onCreated;
  const _NewProcurementSheet({required this.suppliers, required this.onCreated});

  @override
  ConsumerState<_NewProcurementSheet> createState() => _NewProcurementSheetState();
}

class _NewProcurementSheetState extends ConsumerState<_NewProcurementSheet> {
  int? _selectedSupplierId;
  final List<_ProcurementLineItem> _lines = [_ProcurementLineItem()];
  bool _submitting = false;
  String _destination = 'retail'; // retail | wholesale

  static const _dosageForms = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Cream',
    'Ointment', 'Suspension', 'Drops', 'Inhaler', 'Patch', 'Other'];
  static const _units = ['Pack', 'Box', 'Carton', 'Piece', 'Strip', 'Bottle', 'Vial', 'Ampoule', 'Tube', 'Sachet'];
  static const _markups = [0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100];

  @override
  void dispose() {
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (sum, l) => sum + l.subtotal);

  InputDecoration _inputDec(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 12),
    prefixText: prefix,
    prefixStyle: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
    focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
  );

  Future<void> _submit(String status) async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.info_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('Please select a supplier', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
      return;
    }
    final items = _lines.where((l) => l.nameCtrl.text.isNotEmpty).map((l) => {
      'itemName': l.nameCtrl.text.trim(),
      'brand': l.brandCtrl.text.trim(),
      'dosageForm': l.dosageForm,
      'unit': l.unit,
      'quantity': l.quantity,
      'costPrice': l.costPrice,
      'markup': l.markupPct,
      'sellingPrice': l.sellingPrice,
      'expiryDate': l.expiryDate?.toIso8601String().split('T').first,
      'barcode': l.barcodeCtrl.text.trim(),
      'subtotal': l.subtotal,
    }).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.info_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('Add at least one item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(posApiProvider).createProcurement(
        supplierId: _selectedSupplierId!,
        items: items.cast<Map<String, dynamic>>(),
        status: status,
        destination: _destination,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        final destLabel = _destination == 'retail' ? 'Retail Store' : 'Wholesale Store';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(status == 'completed'
                ? 'Procurement dispatched to $destLabel'
                : 'Procurement saved as draft', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1A2535) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: EnhancedTheme.primaryTeal, size: 20),
            ),
            const SizedBox(width: 12),
            Text('New Procurement',
                style: GoogleFonts.outfit(color: context.labelColor,
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),

          // Supplier selector
          Text('Supplier',
              style: GoogleFonts.outfit(color: context.subLabelColor,
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedSupplierId,
              hint: Text('Select supplier',
                  style: GoogleFonts.inter(color: context.hintColor, fontSize: 14)),
              dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
              style: GoogleFonts.inter(color: context.labelColor, fontSize: 14),
              items: widget.suppliers.map<DropdownMenuItem<int>>((s) {
                final id = s['id'] as int;
                final name = s['name'] as String? ?? 'Unknown';
                return DropdownMenuItem(value: id, child: Text(name));
              }).toList(),
              onChanged: (v) => setState(() => _selectedSupplierId = v),
            )),
          ),
          const SizedBox(height: 20),

          // Items header
          Row(children: [
            Expanded(child: Text('Items (${_lines.length})',
                style: GoogleFonts.outfit(color: context.labelColor,
                    fontSize: 14, fontWeight: FontWeight.w700))),
            GestureDetector(
              onTap: () => setState(() => _lines.add(_ProcurementLineItem())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded,
                      color: EnhancedTheme.primaryTeal, size: 16),
                  const SizedBox(width: 4),
                  Text('Add Item',
                      style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Line items
          ...List.generate(_lines.length, (i) => _lineItemCard(i)),
          const SizedBox(height: 12),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                EnhancedTheme.accentCyan.withValues(alpha: 0.06),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: EnhancedTheme.primaryTeal, size: 18),
                const SizedBox(width: 8),
                Text('Total Cost',
                    style: GoogleFonts.outfit(color: context.labelColor,
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              Text('₦${_total.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 16),

          // Destination selector
          Text('Store Destination',
              style: GoogleFonts.outfit(color: context.subLabelColor,
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _destChip('retail', 'Retail Store',
                Icons.storefront_rounded, EnhancedTheme.infoBlue)),
            const SizedBox(width: 10),
            Expanded(child: _destChip('wholesale', 'Wholesale',
                Icons.warehouse_rounded, EnhancedTheme.accentPurple)),
          ]),
          const SizedBox(height: 16),

          // Buttons
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _submitting ? null : () => _submit('draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.labelColor,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Save Draft',
                  style: GoogleFonts.outfit(fontSize: 14,
                      fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit('completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _destination == 'retail'
                    ? EnhancedTheme.infoBlue
                    : EnhancedTheme.accentPurple,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : Text(
                      'Dispatch to ${_destination == 'retail' ? 'Retail' : 'Wholesale'}',
                      style: GoogleFonts.outfit(fontSize: 13,
                          fontWeight: FontWeight.w700)),
            )),
          ]),
        ],
      )),
    );
  }

  Widget _lineItemCard(int i) {
    final line = _lines[i];
    final selling = line.sellingPrice;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Item ${i + 1}',
                    style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (_lines.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _lines[i].dispose();
                    _lines.removeAt(i);
                  }),
                  child: Container(
                    width: 28, height: 28,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: line.nameCtrl,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
                decoration: _inputDec('Drug / item name *'),
              ),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(child: TextField(
                  controller: line.brandCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
                  decoration: _inputDec('Brand (optional)'),
                )),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(
                  value: line.dosageForm,
                  items: _dosageForms,
                  onChanged: (v) => setState(() => line.dosageForm = v ?? line.dosageForm),
                )),
              ]),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(child: TextField(
                  controller: line.qtyCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
                  decoration: _inputDec('Quantity *'),
                )),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(
                  value: line.unit,
                  items: _units,
                  onChanged: (v) => setState(() => line.unit = v ?? line.unit),
                )),
              ]),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(child: TextField(
                  controller: line.costCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
                  decoration: _inputDec('Cost price *', prefix: '₦'),
                )),
                const SizedBox(width: 8),
                Expanded(child: _dropdown(
                  value: line.markupPct,
                  items: _markups,
                  labelBuilder: (v) => '$v% markup',
                  onChanged: (v) =>
                      setState(() => line.markupPct = v ?? line.markupPct),
                )),
              ]),
              const SizedBox(height: 8),

              if (line.costPrice > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.successGreen.withValues(alpha: 0.1),
                      EnhancedTheme.successGreen.withValues(alpha: 0.05),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: EnhancedTheme.successGreen.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Row(children: [
                      const Icon(Icons.sell_rounded,
                          color: EnhancedTheme.successGreen, size: 14),
                      const SizedBox(width: 6),
                      Text('Selling Price',
                          style: GoogleFonts.inter(
                              color: context.subLabelColor, fontSize: 12)),
                    ]),
                    Text('₦${selling.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                            color: EnhancedTheme.successGreen,
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              if (line.costPrice > 0) const SizedBox(height: 8),

              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: line.expiryDate ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2040),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: EnhancedTheme.primaryTeal),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => line.expiryDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: line.expiryDate != null
                              ? EnhancedTheme.primaryTeal.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_rounded,
                          color: line.expiryDate != null
                              ? EnhancedTheme.primaryTeal
                              : context.hintColor,
                          size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        line.expiryDate != null
                            ? '${line.expiryDate!.year}-${line.expiryDate!.month.toString().padLeft(2, '0')}-${line.expiryDate!.day.toString().padLeft(2, '0')}'
                            : 'Expiry date',
                        style: GoogleFonts.inter(
                            color: line.expiryDate != null
                                ? context.labelColor
                                : context.hintColor,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: line.barcodeCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
                  decoration: _inputDec('Barcode (opt.)'),
                )),
              ]),

              if (line.subtotal > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Subtotal: ₦${line.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(color: context.subLabelColor,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _destChip(String value, String label, IconData icon, Color color) {
    final active = _destination == value;
    return GestureDetector(
      onTap: () => setState(() => _destination = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.08),
                ])
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color : Colors.white.withValues(alpha: 0.1),
              width: active ? 1.5 : 1),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.15),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? color : context.subLabelColor, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  color: active ? color : context.subLabelColor,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(child: DropdownButton<T>(
        isExpanded: true,
        value: value,
        isDense: true,
        dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        style: GoogleFonts.inter(color: context.labelColor, fontSize: 12),
        items: items.map((v) => DropdownMenuItem<T>(
          value: v,
          child: Text(labelBuilder != null ? labelBuilder(v) : '$v',
              overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PROCUREMENT DETAIL & DISPATCH SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _ProcurementDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> procurement;
  final VoidCallback onDispatched;
  const _ProcurementDetailSheet(
      {required this.procurement, required this.onDispatched});

  @override
  ConsumerState<_ProcurementDetailSheet> createState() =>
      _ProcurementDetailSheetState();
}

class _ProcurementDetailSheetState
    extends ConsumerState<_ProcurementDetailSheet> {
  bool _dispatching = false;

  Future<void> _dispatch(String destination) async {
    final p = widget.procurement;
    final id = p['id'] as int?;
    if (id == null) return;

    final isDraft = (p['status'] ?? 'draft').toString().toLowerCase() == 'draft';
    if (!isDraft) {
      Navigator.pop(context);
      return;
    }

    final label = destination == 'retail' ? 'Retail Store' : 'Wholesale Store';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Send to $label?',
            style: GoogleFonts.outfit(color: context.labelColor,
                fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'All ${(p['items'] as List?)?.length ?? 0} item(s) from this procurement will be added to $label inventory.',
          style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: context.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destination == 'retail'
                  ? EnhancedTheme.infoBlue
                  : EnhancedTheme.accentPurple,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Confirm', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _dispatching = true);
    try {
      await ref.read(posApiProvider).completeProcurement(id, destination: destination);
      if (mounted) {
        Navigator.pop(context);
        widget.onDispatched();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Items dispatched to $label', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.procurement;
    final supplierName = p['supplier']?['name'] ?? p['supplierName'] ?? 'Unknown';
    final total = (p['total'] as num?)?.toDouble() ?? 0;
    final status = (p['status'] ?? 'draft').toString().toLowerCase();
    final isDraft = status == 'draft';
    final items = (p['items'] as List?) ?? [];
    final dateStr = p['date'] ?? '';
    final statusColor = isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1A2535) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EnhancedTheme.accentCyan.withValues(alpha: 0.3),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: EnhancedTheme.accentCyan, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(supplierName,
                style: GoogleFonts.outfit(color: context.labelColor,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              '${items.length} item(s)${dateStr.isNotEmpty ? ' · ${dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr}' : ''}',
              style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12),
            ),
          ])),
          _statusBadgeInline(status),
        ]),
        const SizedBox(height: 14),

        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
            _miniStat('Items', '${items.length}', EnhancedTheme.accentCyan),
            Container(width: 1, height: 24,
                color: Colors.white.withValues(alpha: 0.1)),
            _miniStat('Status', isDraft ? 'Draft' : 'Dispatched', statusColor),
            Container(width: 1, height: 24,
                color: Colors.white.withValues(alpha: 0.1)),
            _miniStat('Total', '₦${total.toStringAsFixed(0)}',
                EnhancedTheme.primaryTeal),
          ]),
        ),
        const SizedBox(height: 12),

        // Items list
        Expanded(child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (_, i) => _itemRow(items[i] as Map<String, dynamic>, i),
        )),

        // Total bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
              EnhancedTheme.accentCyan.withValues(alpha: 0.06),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text('Total Cost',
                style: GoogleFonts.outfit(color: context.labelColor,
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text('₦${total.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),

        // Dispatch buttons (only for draft)
        if (isDraft) ...[
          if (_dispatching)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Center(child: CircularProgressIndicator(
                  color: EnhancedTheme.primaryTeal)),
            )
          else
            Column(children: [
              Text('Dispatch inventory to:',
                  style: GoogleFonts.inter(color: context.subLabelColor,
                      fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _dispatch('retail'),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: Text('Retail Store',
                      style: GoogleFonts.outfit(fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.infoBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _dispatch('wholesale'),
                  icon: const Icon(Icons.warehouse_rounded, size: 18),
                  label: Text('Wholesale',
                      style: GoogleFonts.outfit(fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.accentPurple,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                )),
              ]),
            ]),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  EnhancedTheme.successGreen.withValues(alpha: 0.12),
                  EnhancedTheme.successGreen.withValues(alpha: 0.05),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: EnhancedTheme.successGreen.withValues(alpha: 0.35)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                const Icon(Icons.check_circle_rounded,
                    color: EnhancedTheme.successGreen, size: 20),
                const SizedBox(width: 10),
                Text('Items have been moved to inventory',
                    style: GoogleFonts.outfit(color: EnhancedTheme.successGreen,
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.outfit(color: color,
          fontSize: 14, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: context.hintColor,
          fontSize: 10)),
    ]);
  }

  Widget _itemRow(Map<String, dynamic> item, int index) {
    final name = item['itemName'] as String? ?? '';
    final brand = item['brand'] as String? ?? '';
    final dosageForm = item['dosageForm'] as String? ?? '';
    final qty = item['quantity'] ?? 0;
    final unit = item['unit'] as String? ?? 'Pcs';
    final cost = (item['costPrice'] as num?)?.toDouble() ?? 0;
    final markup = (item['markup'] as num?)?.toDouble() ?? 0;
    final selling = cost * (1 + markup / 100);
    final subtotal = (item['subtotal'] as num?)?.toDouble() ??
        (cost * (qty as num));
    final expiry = item['expiryDate'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: GoogleFonts.outfit(
                            color: EnhancedTheme.primaryTeal,
                            fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: GoogleFonts.outfit(color: context.labelColor,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (brand.isNotEmpty || dosageForm.isNotEmpty)
                    Text(
                      [if (brand.isNotEmpty) brand, if (dosageForm.isNotEmpty) dosageForm]
                          .join(' · '),
                      style: GoogleFonts.inter(color: context.subLabelColor,
                          fontSize: 11),
                    ),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text('$qty $unit',
                      style: GoogleFonts.outfit(color: context.labelColor,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _infoChip('Cost', '₦${cost.toStringAsFixed(2)}',
                    EnhancedTheme.warningAmber),
                _infoChip('Sell', '₦${selling.toStringAsFixed(2)}',
                    EnhancedTheme.successGreen),
                _infoChip('Markup', '${markup.toStringAsFixed(0)}%',
                    EnhancedTheme.accentCyan),
                if (expiry.isNotEmpty)
                  _infoChip('Exp',
                      expiry.length > 10 ? expiry.substring(0, 10) : expiry,
                      EnhancedTheme.accentPurple),
              ]),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Subtotal: ₦${subtotal.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(color: context.subLabelColor,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(children: [
      Text(label,
          style: GoogleFonts.inter(color: color.withValues(alpha: 0.7),
              fontSize: 9)),
      Text(value,
          style: GoogleFonts.outfit(color: color,
              fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _statusBadgeInline(String status) {
    final isDraft = status == 'draft';
    final color = isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen;
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(color: color,
              fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
