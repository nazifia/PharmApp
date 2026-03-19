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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _completeProcurement(int id) async {
    try {
      await ref.read(posApiProvider).completeProcurement(id);
      _loadProcurements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procurement completed'), backgroundColor: EnhancedTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: EnhancedTheme.errorRed),
        );
      }
    }
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
        onPressed: _tabController.index == 0 ? _showAddSupplierSheet : null,
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
    return RefreshIndicator(
      onRefresh: _loadSuppliers,
      color: EnhancedTheme.primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (_loadingSuppliers)
            ...List.generate(4, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnhancedTheme.loadingShimmer(height: 80),
            ))
          else if (_suppliers.isEmpty)
            _emptyState(Icons.local_shipping_outlined, 'No suppliers found', 'Tap + to add a new supplier')
          else
            ..._suppliers.map((s) => _supplierTile(s)),
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
    return RefreshIndicator(
      onRefresh: _loadProcurements,
      color: EnhancedTheme.primaryTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (_loadingProcurements)
            ...List.generate(4, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: EnhancedTheme.loadingShimmer(height: 88),
            ))
          else if (_procurements.isEmpty)
            _emptyState(Icons.inventory_2_outlined, 'No procurements found', 'Create a procurement to get started')
          else
            ..._procurements.map((p) => _procurementTile(p)),
        ],
      ),
    );
  }

  Widget _procurementTile(Map<String, dynamic> p) {
    final supplierName = p['supplier']?['name'] ?? p['supplierName'] ?? 'Unknown';
    final totalAmount = (p['totalAmount'] as num?)?.toDouble() ?? 0;
    final status = (p['status'] ?? 'draft').toString().toLowerCase();
    final dateStr = p['date'] ?? p['createdAt'] ?? '';
    final id = p['id'] as int?;
    final isDraft = status == 'draft';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: EnhancedTheme.accentCyan, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(supplierName, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(dateStr, style: TextStyle(color: context.hintColor, fontSize: 11)),
                ])),
                _statusBadge(status),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('₦${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
                if (isDraft && id != null)
                  GestureDetector(
                    onTap: () => _completeProcurement(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.successGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle_outline_rounded, color: EnhancedTheme.successGreen, size: 15),
                        SizedBox(width: 4),
                        Text('Complete', style: TextStyle(color: EnhancedTheme.successGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ]),
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
        Text(title, style: TextStyle(color: context.subLabelColor, fontSize: 14)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: context.hintColor, fontSize: 12)),
      ]),
    );
  }
}
