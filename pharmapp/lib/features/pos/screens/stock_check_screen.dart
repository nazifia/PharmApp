import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../providers/pos_api_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  STOCK CHECK SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class StockCheckScreen extends ConsumerStatefulWidget {
  const StockCheckScreen({super.key});

  @override
  ConsumerState<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends ConsumerState<StockCheckScreen> {
  List<dynamic> _checks = [];
  bool _loading = true;
  String? _error;

  // Detail state
  Map<String, dynamic>? _selectedCheck;
  List<dynamic> _detailItems = [];
  bool _detailLoading = false;
  String _detailSearch = '';

  @override
  void initState() {
    super.initState();
    _loadChecks();
  }

  Future<void> _loadChecks() async {
    setState(() { _loading = true; _error = null; });
    try {
      final checks = await ref.read(posApiProvider).fetchStockChecks();
      if (!mounted) return;
      setState(() { _checks = checks; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDetail(int id) async {
    setState(() => _detailLoading = true);
    try {
      final detail = await ref.read(posApiProvider).fetchStockCheckDetail(id);
      if (!mounted) return;
      setState(() {
        _selectedCheck = detail;
        _detailItems = (detail['items'] as List<dynamic>?) ?? [];
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailLoading = false);
      _showError('Failed to load detail: $e');
    }
  }

  Future<void> _createCheck() async {
    try {
      await ref.read(posApiProvider).createStockCheck();
      if (!mounted) return;
      _showSnack('Stock check created', EnhancedTheme.successGreen);
      _loadChecks();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to create: $e');
    }
  }

  void _showAddItemsSheet(int checkId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddItemsSheet(
        checkId: checkId,
        alreadyAdded: _detailItems
            .map((it) => (it['itemId'] as num?)?.toInt() ?? (it['id'] as num?)?.toInt() ?? 0)
            .toSet(),
        onItemAdded: () => _loadDetail(checkId),
      ),
    );
  }

  Future<void> _approveCheck(int id) async {
    try {
      await ref.read(posApiProvider).approveStockCheck(id);
      if (!mounted) return;
      _showSnack('Stock check approved', EnhancedTheme.successGreen);
      setState(() => _selectedCheck = null);
      _loadChecks();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to approve: $e');
    }
  }

  Future<void> _deleteCheck(int id) async {
    try {
      await ref.read(posApiProvider).deleteStockCheck(id);
      if (!mounted) return;
      _showSnack('Stock check deleted', EnhancedTheme.errorRed);
      setState(() => _selectedCheck = null);
      _loadChecks();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to delete: $e');
    }
  }

  Future<void> _updateItem(int checkId, int itemId, int actualQty, String status) async {
    try {
      await ref.read(posApiProvider).updateStockCheckItem(checkId, itemId, actualQty, status);
      if (!mounted) return;
      _showSnack('Item updated', EnhancedTheme.primaryTeal);
      _loadDetail(checkId);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update item: $e');
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
    ));
  }

  void _showError(String msg) => _showSnack(msg, EnhancedTheme.errorRed);

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':     return EnhancedTheme.warningAmber;
      case 'in_progress': return EnhancedTheme.infoBlue;
      case 'completed':   return EnhancedTheme.successGreen;
      default:            return context.subLabelColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':     return 'Pending';
      case 'in_progress': return 'In Progress';
      case 'completed':   return 'Completed';
      default:            return status;
    }
  }

  // ── Detail View ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_selectedCheck != null) return _buildDetail();
    return _buildList();
  }

  Widget _buildDetail() {
    final check = _selectedCheck!;
    final status = (check['status'] as String?) ?? 'unknown';
    final createdBy = (check['createdBy'] as String?) ?? 'Unknown';
    final date = (check['createdAt'] as String?) ?? '';
    final checkId = (check['id'] as num?)?.toInt() ?? 0;

    final reconciled = _detailItems.where((it) => (it['status'] as String?) != 'pending').length;
    final total = _detailItems.length;
    final progress = total > 0 ? reconciled / total : 0.0;

    final q = _detailSearch.toLowerCase();
    final filteredItems = q.isEmpty
        ? _detailItems
        : _detailItems.where((it) {
            final name = ((it['itemName'] as String?) ?? (it['name'] as String?) ?? '').toLowerCase();
            return name.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => setState(() { _selectedCheck = null; _detailItems = []; _detailSearch = ''; }),
              ),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Stock Check #$checkId', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('$createdBy · $date', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              _statusChip(status),
            ]),
          ),
          const SizedBox(height: 8),

          // Progress indicator
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Progress: $reconciled / $total items reconciled',
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                  Text('${(progress * 100).round()}%',
                      style: const TextStyle(color: EnhancedTheme.primaryTeal,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? EnhancedTheme.successGreen : EnhancedTheme.primaryTeal),
                    minHeight: 6,
                  ),
                ),
              ]),
            ),

          // Search bar
          if (_detailItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _detailSearch = v),
                style: TextStyle(color: context.labelColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search items…',
                  hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: context.hintColor, size: 20),
                  filled: true,
                  fillColor: context.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

          // Action buttons
          if (status == 'pending' || status == 'in_progress')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _showAddItemsSheet(checkId),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.infoBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
                if (status == 'in_progress') ...[
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _approveCheck(checkId),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ],
              ]),
            ),
          if (status == 'pending' || status == 'in_progress') const SizedBox(height: 8),

          // Items list
          Expanded(child: _detailLoading
              ? const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))
              : filteredItems.isEmpty
                  ? _emptyState(Icons.inventory_2_outlined, 'No items found')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      itemBuilder: (_, i) => _detailItemCard(filteredItems[i], checkId, status),
                    )),
        ])),
      ]),
    );
  }

  Widget _detailItemCard(dynamic item, int checkId, String checkStatus) {
    final name = (item['itemName'] as String?) ?? (item['name'] as String?) ?? 'Unknown Item';
    final expected = (item['expectedQuantity'] as num?)?.toInt() ?? (item['expected'] as num?)?.toInt() ?? 0;
    final actual = (item['actualQuantity'] as num?)?.toInt() ?? (item['actual'] as num?)?.toInt();
    final itemStatus = (item['status'] as String?) ?? 'pending';
    // item['id'] is the StockCheckItem PK used in the URL; item['itemId'] is the inventory Item FK
    final itemId = (item['id'] as num?)?.toInt() ?? 0;
    final discrepancy = actual != null ? actual - expected : null;

    final _qtyController = TextEditingController(text: actual?.toString() ?? '');

    Color itemStatusColor;
    switch (itemStatus) {
      case 'matched':    itemStatusColor = EnhancedTheme.successGreen; break;
      case 'discrepant': itemStatusColor = EnhancedTheme.errorRed; break;
      default:           itemStatusColor = EnhancedTheme.warningAmber;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                Expanded(child: Text(name, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: itemStatusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(itemStatus, style: TextStyle(color: itemStatusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Expected', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('$expected', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Actual', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  const SizedBox(height: 4),
                  if (checkStatus == 'in_progress')
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
                          ),
                        ),
                        onSubmitted: (val) {
                          final q = int.tryParse(val);
                          if (q != null) {
                            final s = q == expected ? 'matched' : 'discrepant';
                            _updateItem(checkId, itemId, q, s);
                          }
                        },
                      ),
                    )
                  else
                    Text('${actual ?? '—'}', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Discrepancy', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    discrepancy != null ? (discrepancy > 0 ? '+$discrepancy' : '$discrepancy') : '—',
                    style: TextStyle(
                      color: discrepancy == null
                          ? context.hintColor
                          : discrepancy > 0
                              ? EnhancedTheme.successGreen
                              : discrepancy < 0
                                  ? EnhancedTheme.errorRed
                                  : context.labelColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ])),
              ]),
              if (checkStatus == 'in_progress') ...[
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () {
                    final q = int.tryParse(_qtyController.text);
                    if (q != null) {
                      final s = q == expected ? 'matched' : 'discrepant';
                      _updateItem(checkId, itemId, q, s);
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // ── List View ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton(
        onPressed: _createCheck,
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
              ),
              const SizedBox(width: 4),
              Text('Stock Checks', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))
              : _error != null
                  ? _errorState()
                  : _checks.isEmpty
                      ? _emptyState(Icons.fact_check_outlined, 'No stock checks yet')
                      : RefreshIndicator(
                          color: EnhancedTheme.primaryTeal,
                          onRefresh: _loadChecks,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _checks.length,
                            itemBuilder: (_, i) => _checkCard(_checks[i]),
                          ),
                        )),
        ])),
      ]),
    );
  }

  Widget _checkCard(dynamic check) {
    final id = (check['id'] as num?)?.toInt() ?? 0;
    final status = (check['status'] as String?) ?? 'unknown';
    final createdBy = (check['createdBy'] as String?) ?? 'Unknown';
    final date = (check['createdAt'] as String?) ?? '';
    final itemCount = (check['itemCount'] as num?)?.toInt() ?? (check['items'] as List?)?.length ?? 0;
    final color = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _loadDetail(id),
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
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fact_check_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Check #$id', style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('$createdBy · $date', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                ])),
                Column(children: [
                  Text('$itemCount', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('items', style: TextStyle(color: context.hintColor, fontSize: 11)),
                ]),
                const SizedBox(width: 8),
                if (status == 'pending')
                  GestureDetector(
                    onTap: () => _confirmDelete(id),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 18),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: context.hintColor, size: 22),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EnhancedTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Check?', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('This stock check will be permanently deleted.', style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: context.subLabelColor))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteCheck(id); },
            style: ElevatedButton.styleFrom(backgroundColor: EnhancedTheme.errorRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: context.hintColor, size: 64),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(color: context.subLabelColor, fontSize: 16)),
    ]));
  }

  Widget _errorState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: EnhancedTheme.errorRed, size: 48),
      const SizedBox(height: 16),
      Text('Something went wrong', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(_error ?? '', style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _loadChecks,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
          backgroundColor: EnhancedTheme.primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ADD ITEMS SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _AddItemsSheet extends ConsumerStatefulWidget {
  final int checkId;
  final Set<int> alreadyAdded;
  final VoidCallback onItemAdded;
  const _AddItemsSheet({
    required this.checkId,
    required this.alreadyAdded,
    required this.onItemAdded,
  });

  @override
  ConsumerState<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends ConsumerState<_AddItemsSheet> {
  String _search = '';
  final _searchCtrl = TextEditingController();
  final Set<int> _adding = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem(Item item) async {
    if (_adding.contains(item.id)) return;
    setState(() => _adding.add(item.id));
    try {
      await ref.read(posApiProvider).addStockCheckItem(widget.checkId, item.id);
      widget.onItemAdded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${item.name} added to check'),
          backgroundColor: EnhancedTheme.successGreen,
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Add Items to Check',
              style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700))),
          IconButton(
            icon: Icon(Icons.close_rounded, color: context.hintColor),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search medications...',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: inventoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
          error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.subLabelColor))),
          data: (items) {
            final filtered = items.where((it) {
              if (widget.alreadyAdded.contains(it.id)) return false;
              if (_search.isEmpty) return true;
              return it.name.toLowerCase().contains(_search) ||
                  it.brand.toLowerCase().contains(_search);
            }).toList();

            if (filtered.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined, color: context.hintColor, size: 48),
                const SizedBox(height: 12),
                Text('No items found', style: TextStyle(color: context.subLabelColor, fontSize: 14)),
              ]));
            }

            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                final isAdding = _adding.contains(item.id);
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_rounded, color: EnhancedTheme.primaryTeal, size: 20),
                  ),
                  title: Text(item.name, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${item.brand} · Stock: ${item.stock}',
                    style: TextStyle(color: context.hintColor, fontSize: 12),
                  ),
                  trailing: isAdding
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.add_circle_rounded, color: EnhancedTheme.primaryTeal, size: 28),
                          onPressed: () => _addItem(item),
                        ),
                );
              },
            );
          },
        )),
      ]),
    );
  }
}
