import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier deleted'), backgroundColor: EnhancedTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: EnhancedTheme.errorRed),
        );
      }
    }
  }

  void _showAddProcurementSheet() {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one supplier first'),
        backgroundColor: EnhancedTheme.warningAmber,
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
              color: context.scaffoldBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Text('New Supplier', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              TextField(
                controller: nameCtrl,
                style: TextStyle(color: context.labelColor),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: context.subLabelColor),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: context.labelColor),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: context.subLabelColor),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: contactCtrl,
                style: TextStyle(color: context.labelColor),
                decoration: InputDecoration(
                  labelText: 'Contact Info',
                  labelStyle: TextStyle(color: context.subLabelColor),
                ),
              ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Supplier added'), backgroundColor: EnhancedTheme.successGreen),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: EnhancedTheme.errorRed),
                      );
                    }
                  }
                },
                child: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              )),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tabController.index == 0 ? _showAddSupplierSheet : _showAddProcurementSheet,
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Add Supplier' : 'New Procurement',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Suppliers', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Manage suppliers & procurements', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
            ]),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              indicator: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: EnhancedTheme.primaryTeal,
              unselectedLabelColor: context.subLabelColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Suppliers'),
                Tab(text: 'Procurements'),
              ],
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
          // Search bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchSupplierCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: context.labelColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search suppliers…',
                hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: context.hintColor, size: 20),
                filled: true,
                fillColor: context.cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor)),
                focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_loadingSuppliers)
            ...List.generate(4, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnhancedTheme.loadingShimmer(height: 80),
            ))
          else if (filtered.isEmpty)
            _emptyState(Icons.local_shipping_outlined, 'No suppliers found', 'Tap + to add a new supplier')
          else
            ...filtered.map((s) => _supplierTile(s)),
        ],
      ),
    );
  }

  Widget _supplierTile(Map<String, dynamic> s) {
    final name = s['name'] ?? '';
    final phone = s['phone'] ?? '';
    final contactInfo = s['contactInfo'] ?? '';
    final id = s['id'] as int?;

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
            color: EnhancedTheme.errorRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: EnhancedTheme.errorRed),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: EnhancedTheme.accentPurple, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.phone_rounded, color: context.hintColor, size: 13),
                      const SizedBox(width: 4),
                      Text(phone, style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                    ]),
                  ],
                  if (contactInfo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(contactInfo, style: TextStyle(color: context.hintColor, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Procurements Tab ───────────────────────────────────────────────────────

  Widget _buildProcurementsTab() {
    final q = _searchProcCtrl.text.toLowerCase();
    final filtered = _procurements.where((p) {
      final supplier = (p['supplier']?['name'] ?? p['supplierName'] ?? '').toString().toLowerCase();
      return supplier.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadProcurements,
      color: EnhancedTheme.primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchProcCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: context.labelColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by supplier…',
                hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: context.hintColor, size: 20),
                filled: true,
                fillColor: context.cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor)),
                focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_loadingProcurements)
            ...List.generate(4, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnhancedTheme.loadingShimmer(height: 88),
            ))
          else if (filtered.isEmpty)
            _emptyState(Icons.inventory_2_outlined, 'No procurements found', 'Tap + to create a procurement')
          else
            ...filtered.map((p) => _procurementTile(p)),
        ],
      ),
    );
  }

  Widget _procurementTile(Map<String, dynamic> p) {
    final supplierName = p['supplier']?['name'] ?? p['supplierName'] ?? 'Unknown';
    final total = (p['total'] as num?)?.toDouble() ?? (p['totalAmount'] as num?)?.toDouble() ?? 0;
    final status = (p['status'] ?? 'draft').toString().toLowerCase();
    final dateStr = p['date'] ?? p['createdAt'] ?? '';
    final isDraft = status == 'draft';
    final itemList = (p['items'] as List?) ?? [];
    final itemCount = itemList.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showProcurementDetail(p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDraft ? EnhancedTheme.warningAmber.withValues(alpha: 0.3) : context.borderColor),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDraft ? Icons.inventory_2_rounded : Icons.check_circle_rounded,
                    color: isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(supplierName, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$itemCount item${itemCount == 1 ? '' : 's'} · $dateStr',
                      style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('₦${total.toStringAsFixed(2)}',
                      style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _statusBadge(status),
                  const SizedBox(height: 8),
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Tap to dispatch',
                          style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.w600)),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: context.hintColor, size: 18),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isDraft = status == 'draft';
    final color = isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen;
    final label = status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Icon(icon, color: context.hintColor, size: 48),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: context.subLabelColor, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: context.hintColor, fontSize: 12)),
      ]),
    );
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
    hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
    prefixText: prefix,
    prefixStyle: TextStyle(color: context.subLabelColor, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: context.cardColor,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
  );

  Future<void> _submit(String status) async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a supplier'), backgroundColor: EnhancedTheme.warningAmber));
      return;
    }
    final items = _lines.where((l) => l.nameCtrl.text.isNotEmpty).map((l) => {
      'name': l.nameCtrl.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one item'), backgroundColor: EnhancedTheme.warningAmber));
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
          content: Text(status == 'completed' ? 'Procurement dispatched to $destLabel' : 'Procurement saved as draft'),
          backgroundColor: EnhancedTheme.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: EnhancedTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1A2535) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('New Procurement', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // Supplier selector
          Text('Supplier', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
            child: DropdownButtonHideUnderline(child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedSupplierId,
              hint: Text('Select supplier', style: TextStyle(color: context.hintColor, fontSize: 14)),
              dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: context.labelColor, fontSize: 14),
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
            Expanded(child: Text('Items (${_lines.length})', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () => setState(() => _lines.add(_ProcurementLineItem())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: EnhancedTheme.primaryTeal, size: 16),
                  SizedBox(width: 4),
                  Text('Add Item', style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total Cost', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('₦${_total.toStringAsFixed(2)}', style: const TextStyle(
                  color: EnhancedTheme.primaryTeal, fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 16),

          // Destination selector
          Text('Store Destination', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _destChip('retail', 'Retail Store', Icons.storefront_rounded, EnhancedTheme.infoBlue)),
            const SizedBox(width: 10),
            Expanded(child: _destChip('wholesale', 'Wholesale', Icons.warehouse_rounded, EnhancedTheme.accentPurple)),
          ]),
          const SizedBox(height: 16),

          // Save as Draft / Complete & Dispatch
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _submitting ? null : () => _submit('draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.labelColor,
                side: BorderSide(color: context.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save Draft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit('completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _destination == 'retail' ? EnhancedTheme.infoBlue : EnhancedTheme.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Dispatch to ${_destination == 'retail' ? 'Retail' : 'Wholesale'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Item ${i + 1}', style: const TextStyle(
                  color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (_lines.length > 1)
              GestureDetector(
                onTap: () => setState(() { _lines[i].dispose(); _lines.removeAt(i); }),
                child: Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 20),
              ),
          ]),
          const SizedBox(height: 10),

          // Drug name
          TextField(
            controller: line.nameCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: context.labelColor, fontSize: 13),
            decoration: _inputDec('Drug / item name *'),
          ),
          const SizedBox(height: 8),

          // Brand + Dosage form
          Row(children: [
            Expanded(child: TextField(
              controller: line.brandCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: context.labelColor, fontSize: 13),
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

          // Qty + Unit
          Row(children: [
            Expanded(child: TextField(
              controller: line.qtyCtrl,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.labelColor, fontSize: 13),
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

          // Cost price + Markup
          Row(children: [
            Expanded(child: TextField(
              controller: line.costCtrl,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: context.labelColor, fontSize: 13),
              decoration: _inputDec('Cost price *', prefix: '₦'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _dropdown(
              value: line.markupPct,
              items: _markups,
              labelBuilder: (v) => '$v% markup',
              onChanged: (v) => setState(() => line.markupPct = v ?? line.markupPct),
            )),
          ]),
          const SizedBox(height: 8),

          // Selling price indicator
          if (line.costPrice > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EnhancedTheme.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Selling Price', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                Text('₦${selling.toStringAsFixed(2)}',
                    style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          if (line.costPrice > 0) const SizedBox(height: 8),

          // Expiry date + Barcode
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: line.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2040),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.dark(primary: EnhancedTheme.primaryTeal),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => line.expiryDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: line.expiryDate != null ? EnhancedTheme.primaryTeal.withValues(alpha: 0.5) : context.borderColor),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_month_rounded,
                      color: line.expiryDate != null ? EnhancedTheme.primaryTeal : context.hintColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    line.expiryDate != null
                        ? '${line.expiryDate!.year}-${line.expiryDate!.month.toString().padLeft(2,'0')}-${line.expiryDate!.day.toString().padLeft(2,'0')}'
                        : 'Expiry date',
                    style: TextStyle(
                        color: line.expiryDate != null ? context.labelColor : context.hintColor,
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
              style: TextStyle(color: context.labelColor, fontSize: 13),
              decoration: _inputDec('Barcode (opt.)'),
            )),
          ]),

          // Subtotal
          if (line.subtotal > 0) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight,
              child: Text('Subtotal: ₦${line.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(color: context.subLabelColor, fontSize: 11, fontWeight: FontWeight.w600))),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : context.borderColor, width: active ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? color : context.subLabelColor, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonHideUnderline(child: DropdownButton<T>(
        isExpanded: true,
        value: value,
        isDense: true,
        dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(color: context.labelColor, fontSize: 12),
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
  const _ProcurementDetailSheet({required this.procurement, required this.onDispatched});

  @override
  ConsumerState<_ProcurementDetailSheet> createState() => _ProcurementDetailSheetState();
}

class _ProcurementDetailSheetState extends ConsumerState<_ProcurementDetailSheet> {
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
            style: TextStyle(color: context.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'All ${(p['items'] as List?)?.length ?? 0} item(s) from this procurement will be added to $label inventory.',
          style: TextStyle(color: context.subLabelColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destination == 'retail' ? EnhancedTheme.infoBlue : EnhancedTheme.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Confirm'),
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
          content: Text('Items dispatched to $label'),
          backgroundColor: EnhancedTheme.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: EnhancedTheme.accentCyan, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(supplierName, style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${items.length} item(s) · ${dateStr.isNotEmpty ? dateStr.substring(0, 10) : ''}',
                style: TextStyle(color: context.subLabelColor, fontSize: 12)),
          ])),
          _statusBadgeInline(status),
        ]),
        const SizedBox(height: 16),

        // Items list
        Expanded(child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (_, i) => _itemRow(items[i] as Map<String, dynamic>),
        )),

        // Total bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Cost', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('₦${total.toStringAsFixed(2)}',
                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),

        // Dispatch buttons (only for draft)
        if (isDraft) ...[
          if (_dispatching)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            )
          else
            Column(children: [
              Text('Dispatch to:', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _dispatch('retail'),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('Retail Store', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.infoBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _dispatch('wholesale'),
                  icon: const Icon(Icons.warehouse_rounded, size: 18),
                  label: const Text('Wholesale', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
              ]),
            ]),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: EnhancedTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded, color: EnhancedTheme.successGreen, size: 18),
                const SizedBox(width: 8),
                Text('Items have been moved to inventory',
                    style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final name = item['itemName'] as String? ?? '';
    final brand = item['brand'] as String? ?? '';
    final dosageForm = item['dosageForm'] as String? ?? '';
    final qty = item['quantity'] ?? 0;
    final unit = item['unit'] as String? ?? 'Pcs';
    final cost = (item['costPrice'] as num?)?.toDouble() ?? 0;
    final markup = (item['markup'] as num?)?.toDouble() ?? 0;
    final selling = cost * (1 + markup / 100);
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (cost * (qty as num));
    final expiry = item['expiryDate'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
              if (brand.isNotEmpty || dosageForm.isNotEmpty)
                Text('${brand.isNotEmpty ? brand : ''}${brand.isNotEmpty && dosageForm.isNotEmpty ? ' · ' : ''}${dosageForm}',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
            ])),
            Text('$qty $unit', style: TextStyle(color: context.hintColor, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _infoChip('Cost', '₦${cost.toStringAsFixed(2)}', EnhancedTheme.warningAmber),
            const SizedBox(width: 8),
            _infoChip('Sell', '₦${selling.toStringAsFixed(2)}', EnhancedTheme.successGreen),
            const SizedBox(width: 8),
            _infoChip('Markup', '${markup.toStringAsFixed(0)}%', EnhancedTheme.accentCyan),
            if (expiry.isNotEmpty) ...[
              const SizedBox(width: 8),
              _infoChip('Exp', expiry.length > 10 ? expiry.substring(0, 10) : expiry, EnhancedTheme.accentPurple),
            ],
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Subtotal: ₦${subtotal.toStringAsFixed(2)}',
                style: TextStyle(color: context.subLabelColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
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
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _statusBadgeInline(String status) {
    final isDraft = status == 'draft';
    final color = isDraft ? EnhancedTheme.warningAmber : EnhancedTheme.successGreen;
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
