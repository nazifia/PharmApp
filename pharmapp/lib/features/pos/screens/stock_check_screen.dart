import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../providers/pos_api_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  STOCK CHECK SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class StockCheckScreen extends ConsumerStatefulWidget {
  final bool isWholesale;
  final bool showReport;
  const StockCheckScreen({super.key, this.isWholesale = false, this.showReport = false});

  @override
  ConsumerState<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends ConsumerState<StockCheckScreen> {
  bool get _isWholesale => widget.isWholesale;
  String get _storeType => _isWholesale ? 'wholesale' : 'retail';
  List<dynamic> _checks = [];
  bool _loading = true;
  String? _error;
  bool _showReport = false;
  Map<String, dynamic>? _reportData;
  bool _reportLoading = false;

  // Detail state
  Map<String, dynamic>? _selectedCheck;
  List<dynamic> _detailItems = [];
  bool _detailLoading = false;
  String _detailSearch = '';

  @override
  void initState() {
    super.initState();
    if (widget.showReport) {
      _showReport = true;
      _loadReport();
    } else {
      _loadChecks();
    }
  }

  Future<void> _loadChecks() async {
    setState(() { _loading = true; _error = null; });
    try {
      final checks = await ref.read(posApiProvider)
          .fetchStockChecks(storeType: _storeType);
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

  Future<void> _loadReport() async {
    setState(() { _reportLoading = true; });
    try {
      final data = await ref.read(posApiProvider)
          .fetchStockCheckReport(storeType: _storeType);
      if (!mounted) return;
      setState(() { _reportData = data; _reportLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportLoading = false);
      _showError('Failed to load report: $e');
    }
  }

  Future<void> _createCheck() async {
    try {
      await ref.read(posApiProvider).createStockCheck(storeType: _storeType);
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
        isWholesale: _isWholesale,
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
    final isError = color == EnhancedTheme.errorRed;
    final isSuccess = color == EnhancedTheme.successGreen;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(
          isError ? Icons.error_rounded : isSuccess ? Icons.check_circle_rounded : Icons.info_rounded,
          color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':     return Icons.schedule_rounded;
      case 'in_progress': return Icons.sync_rounded;
      case 'completed':   return Icons.check_circle_rounded;
      default:            return Icons.help_outline_rounded;
    }
  }

  // ── Detail View ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_selectedCheck != null) return _buildDetail();
    if (_showReport) return _buildReport();
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

    final statusCol = _statusColor(status);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blob
        Positioned(
          top: -80, left: -40,
          child: Container(
            width: 250, height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                statusCol.withValues(alpha: 0.12),
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
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border(bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                    onPressed: () => setState(() {
                      _selectedCheck = null;
                      _detailItems = [];
                      _detailSearch = '';
                    }),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Stock Check #$checkId',
                        style: GoogleFonts.outfit(color: context.labelColor,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('$createdBy · ${date.length > 10 ? date.substring(0, 10) : date}',
                        style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 11)),
                  ])),
                  _statusChip(status),
                ]),
              ),
            ),
          ),

          // Progress card
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusCol.withValues(alpha: 0.12),
                          statusCol.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusCol.withValues(alpha: 0.25)),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Icon(_statusIcon(status), color: statusCol, size: 18),
                        const SizedBox(width: 8),
                        Text('Reconciliation Progress',
                            style: GoogleFonts.outfit(color: context.labelColor,
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusCol.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: GoogleFonts.outfit(color: statusCol,
                                fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: statusCol.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              progress == 1.0 ? EnhancedTheme.successGreen : statusCol),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('$reconciled of $total items reconciled',
                            style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 11)),
                        Text('${total - reconciled} remaining',
                            style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),

          const SizedBox(height: 10),

          // Search bar
          if (_detailItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _detailSearch = v),
                style: GoogleFonts.inter(color: context.labelColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search items…',
                  hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35))),
                  focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(
                          color: EnhancedTheme.primaryTeal, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Action buttons
          if (status == 'pending' || status == 'in_progress')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _showAddItemsSheet(checkId),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Add Items',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.infoBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                )),
                if (status == 'in_progress') ...[
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _approveCheck(checkId),
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: Text('Approve',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.successGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  )),
                ],
              ]),
            ),

          // Items list
          Expanded(child: _detailLoading
              ? const Center(child: CircularProgressIndicator(
                  color: EnhancedTheme.primaryTeal))
              : filteredItems.isEmpty
                  ? _emptyState(Icons.inventory_2_outlined, 'No items found')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filteredItems.length,
                      itemBuilder: (_, i) => _detailItemCard(
                          filteredItems[i], checkId, status, i),
                    )),
        ])),
      ]),
    );
  }

  Widget _detailItemCard(dynamic item, int checkId, String checkStatus, int index) {
    final name = (item['itemName'] as String?) ?? (item['name'] as String?) ?? 'Unknown Item';
    final expected = (item['expectedQuantity'] as num?)?.toInt() ?? (item['expected'] as num?)?.toInt() ?? 0;
    final actual = (item['actualQuantity'] as num?)?.toInt() ?? (item['actual'] as num?)?.toInt();
    final itemStatus = (item['status'] as String?) ?? 'pending';
    final itemId = (item['id'] as num?)?.toInt() ?? 0;
    final discrepancy = actual != null ? actual - expected : null;
    final itemCostDiff = (item['costDifference'] as num?);

    final qtyController = TextEditingController(text: actual?.toString() ?? '');

    Color itemStatusColor;
    switch (itemStatus) {
      case 'matched':    itemStatusColor = EnhancedTheme.successGreen; break;
      case 'discrepant': itemStatusColor = EnhancedTheme.errorRed; break;
      default:           itemStatusColor = EnhancedTheme.warningAmber;
    }

    IconData itemStatusIcon;
    switch (itemStatus) {
      case 'matched':    itemStatusIcon = Icons.check_circle_rounded; break;
      case 'discrepant': itemStatusIcon = Icons.error_rounded; break;
      default:           itemStatusIcon = Icons.schedule_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: itemStatus == 'pending'
                    ? Colors.white.withValues(alpha: 0.1)
                    : itemStatusColor.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(children: [
              // Header bar
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: itemStatusColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Icon(Icons.medication_rounded,
                      color: itemStatusColor.withValues(alpha: 0.7), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name,
                      style: GoogleFonts.outfit(color: context.labelColor,
                          fontSize: 14, fontWeight: FontWeight.w600))),
                  Icon(itemStatusIcon, color: itemStatusColor, size: 16),
                  const SizedBox(width: 4),
                  Text(itemStatus,
                      style: GoogleFonts.outfit(color: itemStatusColor,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  // Stats row
                  Row(children: [
                    Expanded(child: _statCell('Expected', '$expected',
                        EnhancedTheme.infoBlue, Icons.inventory_rounded)),
                    Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.1)),
                    Expanded(child: checkStatus == 'in_progress'
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Actual Count',
                                  style: GoogleFonts.inter(color: context.subLabelColor,
                                      fontSize: 10)),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.outfit(color: context.labelColor,
                                      fontSize: 15, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.08),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.4))),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.4))),
                                    focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(
                                            color: EnhancedTheme.primaryTeal, width: 1.5)),
                                  ),
                                  onSubmitted: (val) {
                                    final q = int.tryParse(val);
                                    if (q != null) {
                                      final s = q == expected ? 'matched' : 'discrepant';
                                      _updateItem(checkId, itemId, q, s);
                                    }
                                  },
                                ),
                              ),
                            ]),
                          )
                        : _statCell('Actual', '${actual ?? '—'}',
                            actual == null ? context.hintColor : EnhancedTheme.primaryTeal,
                            Icons.fact_check_rounded)),
                    Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.1)),
                    Expanded(child: _statCell(
                      'Discrepancy',
                      discrepancy != null
                          ? (discrepancy > 0 ? '+$discrepancy' : '$discrepancy')
                          : '—',
                      discrepancy == null
                          ? context.hintColor
                          : discrepancy > 0
                              ? EnhancedTheme.successGreen
                              : discrepancy < 0
                                  ? EnhancedTheme.errorRed
                                  : context.labelColor,
                      discrepancy == null
                          ? Icons.remove_rounded
                          : discrepancy > 0
                              ? Icons.trending_up_rounded
                              : discrepancy < 0
                                  ? Icons.trending_down_rounded
                                  : Icons.check_rounded,
                    )),
                  ]),

                  if (itemCostDiff != null && itemCostDiff != 0) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.attach_money_rounded,
                          color: itemCostDiff < 0
                              ? EnhancedTheme.errorRed
                              : EnhancedTheme.successGreen,
                          size: 12),
                      const SizedBox(width: 4),
                      Text('Cost diff: ',
                          style: GoogleFonts.inter(
                              color: context.subLabelColor, fontSize: 11)),
                      Text(_fmt(itemCostDiff),
                          style: GoogleFonts.outfit(
                              color: itemCostDiff < 0
                                  ? EnhancedTheme.errorRed
                                  : EnhancedTheme.successGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ],

                  if (checkStatus == 'in_progress') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final q = int.tryParse(qtyController.text);
                          if (q != null) {
                            final s = q == expected ? 'matched' : 'discrepant';
                            _updateItem(checkId, itemId, q, s);
                          }
                        },
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: Text('Save Count',
                            style: GoogleFonts.outfit(fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.primaryTeal,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _statCell(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(color: color,
                fontSize: 20, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.1),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), color: color, size: 12),
        const SizedBox(width: 4),
        Text(_statusLabel(status),
            style: GoogleFonts.outfit(color: color,
                fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── Report View ────────────────────────────────────────────────────────────

  Widget _buildReport() {
    final summary = (_reportData?['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final completed = (_reportData?['completedChecks'] as List?) ?? [];

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        Positioned(
          top: -60, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.accentPurple.withValues(alpha: 0.12),
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
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border(bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                    onPressed: () => setState(() => _showReport = false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_isWholesale ? 'WS Stock Check Report' : 'Stock Check Report',
                        style: GoogleFonts.outfit(color: context.labelColor,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Completed checks summary',
                        style: GoogleFonts.inter(color: context.subLabelColor,
                            fontSize: 11)),
                  ])),
                  GestureDetector(
                    onTap: _loadReport,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          color: EnhancedTheme.accentPurple, size: 18),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          Expanded(child: _reportLoading
              ? const Center(child: CircularProgressIndicator(
                  color: EnhancedTheme.accentPurple))
              : RefreshIndicator(
                  color: EnhancedTheme.accentPurple,
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // Summary cards grid
                      if (summary.isNotEmpty) ...[
                        Text('Overview',
                            style: GoogleFonts.outfit(color: context.labelColor,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _summaryCard('Total Checks',
                                '${summary['totalChecks'] ?? 0}',
                                EnhancedTheme.primaryTeal,
                                Icons.fact_check_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryCard('Completed',
                                '${summary['completedChecks'] ?? 0}',
                                EnhancedTheme.successGreen,
                                Icons.check_circle_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryCard('Items Checked',
                                '${summary['totalItemsChecked'] ?? 0}',
                                EnhancedTheme.infoBlue,
                                Icons.inventory_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryCard('Discrepancies',
                                '${summary['totalDiscrepancies'] ?? 0}',
                                EnhancedTheme.errorRed,
                                Icons.warning_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryCard('Adjustments Made',
                                '${summary['totalAdjustments'] ?? 0}',
                                EnhancedTheme.warningAmber,
                                Icons.tune_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryCard(
                                'Cost Difference',
                                _fmt((summary['totalCostDifference'] as num?) ?? 0),
                                EnhancedTheme.accentPurple,
                                Icons.attach_money_rounded)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Completed checks list
                      if (completed.isNotEmpty) ...[
                        Text('Completed Checks',
                            style: GoogleFonts.outfit(color: context.labelColor,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        ...completed.asMap().entries.map(
                            (e) => _reportCheckCard(e.value, e.key)),
                      ] else if (!_reportLoading)
                        _emptyState(Icons.bar_chart_rounded,
                            'No completed checks yet'),
                    ],
                  ),
                )),
        ])),
      ]),
    );
  }

  String _fmt(num v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1000000) return '$sign₦${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '$sign₦${(abs / 1000).toStringAsFixed(1)}K';
    return '$sign₦${abs.toStringAsFixed(0)}';
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(label,
                  style: GoogleFonts.inter(color: context.subLabelColor,
                      fontSize: 10),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.outfit(color: color,
                    fontSize: 24, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }

  Widget _reportCheckCard(dynamic check, int index) {
    final id = (check['id'] as num?)?.toInt() ?? 0;
    final createdBy = (check['createdBy'] as String?) ?? 'Unknown';
    final date = (check['createdAt'] as String?) ?? '';
    final total = (check['totalItems'] as num?)?.toInt() ?? 0;
    final matched = (check['matchedItems'] as num?)?.toInt() ?? 0;
    final discrepant = (check['discrepantItems'] as num?)?.toInt() ?? 0;
    final adjusted = (check['adjustedItems'] as num?)?.toInt() ?? 0;
    final costDiff = (check['totalCostDifference'] as num?) ?? 0;

    final accuracy = total > 0 ? matched / total : 1.0;
    final accuracyPct = (accuracy * 100).round();
    final accentColor = discrepant == 0
        ? EnhancedTheme.successGreen
        : discrepant <= 2
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.errorRed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              // Accent strip
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.3)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.fact_check_rounded, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Check #$id',
                          style: GoogleFonts.outfit(color: context.labelColor,
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Row(children: [
                        Icon(Icons.person_outline_rounded,
                            color: context.hintColor, size: 11),
                        const SizedBox(width: 3),
                        Text(createdBy,
                            style: GoogleFonts.inter(color: context.subLabelColor,
                                fontSize: 11)),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_rounded,
                            color: context.hintColor, size: 11),
                        const SizedBox(width: 3),
                        Text(date.length > 10 ? date.substring(0, 10) : date,
                            style: GoogleFonts.inter(color: context.subLabelColor,
                                fontSize: 11)),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$accuracyPct%',
                          style: GoogleFonts.outfit(color: accentColor,
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('accuracy',
                          style: GoogleFonts.inter(color: context.hintColor,
                              fontSize: 10)),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  // Stats row
                  Row(children: [
                    Expanded(child: _reportStat('Total', '$total',
                        EnhancedTheme.infoBlue, Icons.inventory_rounded)),
                    Expanded(child: _reportStat('Matched', '$matched',
                        EnhancedTheme.successGreen, Icons.check_rounded)),
                    Expanded(child: _reportStat('Discrepant', '$discrepant',
                        EnhancedTheme.errorRed, Icons.warning_rounded)),
                    Expanded(child: _reportStat('Adjusted', '$adjusted',
                        EnhancedTheme.warningAmber, Icons.tune_rounded)),
                  ]),
                  const SizedBox(height: 10),
                  // Accuracy bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: accuracy,
                      backgroundColor: accentColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 6,
                    ),
                  ),
                  if (costDiff != 0) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.attach_money_rounded,
                          color: costDiff < 0
                              ? EnhancedTheme.errorRed
                              : EnhancedTheme.successGreen,
                          size: 13),
                      const SizedBox(width: 4),
                      Text('Cost difference: ',
                          style: GoogleFonts.inter(
                              color: context.subLabelColor, fontSize: 11)),
                      Text(_fmt(costDiff),
                          style: GoogleFonts.outfit(
                              color: costDiff < 0
                                  ? EnhancedTheme.errorRed
                                  : EnhancedTheme.successGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _reportStat(String label, String value, Color color, IconData icon) {
    return Column(children: [
      Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
      const SizedBox(height: 3),
      Text(value,
          style: GoogleFonts.outfit(color: color,
              fontSize: 16, fontWeight: FontWeight.w800)),
      Text(label,
          style: GoogleFonts.inter(color: context.hintColor, fontSize: 9)),
    ]);
  }

  // ── List View ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCheck,
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Check',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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
                EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
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
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border(bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppShell.roleFallback(ref)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_isWholesale ? 'WS Stock Checks' : 'Stock Checks',
                        style: GoogleFonts.outfit(color: context.labelColor,
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(_isWholesale
                        ? 'Wholesale inventory reconciliation'
                        : 'Retail inventory reconciliation',
                        style: GoogleFonts.inter(color: context.subLabelColor,
                            fontSize: 11)),
                  ])),
                  if (_checks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: Text('${_checks.length} checks',
                          style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => _showReport = true);
                      _loadReport();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bar_chart_rounded,
                            color: EnhancedTheme.accentPurple, size: 14),
                        const SizedBox(width: 4),
                        Text('Report',
                            style: GoogleFonts.outfit(
                                color: EnhancedTheme.accentPurple,
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _loading
              ? _buildSkeletonList()
              : _error != null
                  ? _errorState()
                  : _checks.isEmpty
                      ? _emptyState(Icons.fact_check_outlined, 'No stock checks yet')
                      : RefreshIndicator(
                          color: EnhancedTheme.primaryTeal,
                          onRefresh: _loadChecks,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _checks.length,
                            itemBuilder: (_, i) => _checkCard(_checks[i], i),
                          ),
                        )),
        ])),
      ]),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: EnhancedTheme.loadingShimmer(height: 80, radius: 16),
      ),
    );
  }

  Widget _checkCard(dynamic check, int index) {
    final id = (check['id'] as num?)?.toInt() ?? 0;
    final status = (check['status'] as String?) ?? 'unknown';
    final createdBy = (check['createdBy'] as String?) ?? 'Unknown';
    final date = (check['createdAt'] as String?) ?? '';
    final itemCount = (check['itemCount'] as num?)?.toInt() ??
        (check['items'] as List?)?.length ?? 0;
    final color = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _loadDetail(id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.06),
                      blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(children: [
                // Top accent strip
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.3)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                            color.withValues(alpha: 0.25),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.fact_check_rounded, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Check #$id',
                            style: GoogleFonts.outfit(color: context.labelColor,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        _statusChip(status),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.person_outline_rounded,
                            color: context.hintColor, size: 12),
                        const SizedBox(width: 4),
                        Text(createdBy,
                            style: GoogleFonts.inter(color: context.subLabelColor,
                                fontSize: 11)),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_rounded,
                            color: context.hintColor, size: 12),
                        const SizedBox(width: 4),
                        Text(date.length > 10 ? date.substring(0, 10) : date,
                            style: GoogleFonts.inter(color: context.subLabelColor,
                                fontSize: 11)),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$itemCount',
                          style: GoogleFonts.outfit(color: color,
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('items',
                          style: GoogleFonts.inter(color: context.hintColor,
                              fontSize: 10)),
                    ]),
                    const SizedBox(width: 8),
                    if (status == 'pending')
                      GestureDetector(
                        onTap: () => _confirmDelete(id),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: EnhancedTheme.errorRed.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: EnhancedTheme.errorRed, size: 18),
                        ),
                      )
                    else
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.chevron_right_rounded,
                            color: context.hintColor, size: 18),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.04, end: 0);
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EnhancedTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Check?',
            style: GoogleFonts.outfit(color: context.labelColor,
                fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('This stock check will be permanently deleted.',
            style: GoogleFonts.inter(color: context.subLabelColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: context.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteCheck(id); },
            style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.errorRed,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('Delete', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
              Colors.transparent,
            ]),
          ),
          child: Icon(icon, color: EnhancedTheme.primaryTeal.withValues(alpha: 0.6),
              size: 44),
        ),
        const SizedBox(height: 16),
        Text(message,
            style: GoogleFonts.outfit(color: context.subLabelColor,
                fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Tap + to get started',
            style: GoogleFonts.inter(color: context.hintColor, fontSize: 13)),
      ]),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _errorState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.error_outline_rounded,
              color: EnhancedTheme.errorRed, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Something went wrong',
            style: GoogleFonts.outfit(color: context.labelColor,
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_error ?? '',
            style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadChecks,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text('Retry', style: GoogleFonts.outfit()),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ADD ITEMS SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _AddItemsSheet extends ConsumerStatefulWidget {
  final int checkId;
  final bool isWholesale;
  final Set<int> alreadyAdded;
  final VoidCallback onItemAdded;
  const _AddItemsSheet({
    required this.checkId,
    required this.isWholesale,
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
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 1),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('${item.name} added to check', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
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
            Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = widget.isWholesale
        ? ref.watch(wholesaleInventoryProvider)
        : ref.watch(retailInventoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1A2535) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_circle_rounded,
                color: EnhancedTheme.primaryTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Add Items to Check',
              style: GoogleFonts.outfit(color: context.labelColor,
                  fontSize: 18, fontWeight: FontWeight.w700))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          style: GoogleFonts.inter(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search medications...',
            hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.35))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.35))),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide:
                    BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: inventoryAsync.when(
          loading: () => ListView.builder(
            itemCount: 6,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EnhancedTheme.loadingShimmer(height: 60, radius: 12),
            ),
          ),
          error: (e, _) => Center(
            child: Text('$e',
                style: GoogleFonts.inter(color: context.subLabelColor)),
          ),
          data: (items) {
            final filtered = items.where((it) {
              if (widget.alreadyAdded.contains(it.id)) return false;
              if (_search.isEmpty) return true;
              return it.name.toLowerCase().contains(_search) ||
                  it.brand.toLowerCase().contains(_search);
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: EnhancedTheme.primaryTeal, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text('No items found',
                      style: GoogleFonts.outfit(color: context.subLabelColor,
                          fontSize: 14)),
                ]),
              );
            }

            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                final isAdding = _adding.contains(item.id);
                final stockColor = item.stock == 0
                    ? EnhancedTheme.errorRed
                    : item.stock <= item.lowStockThreshold
                        ? EnhancedTheme.warningAmber
                        : EnhancedTheme.successGreen;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medication_rounded,
                                color: EnhancedTheme.primaryTeal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: GoogleFonts.outfit(
                                      color: context.labelColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Row(children: [
                                Text(item.brand,
                                    style: GoogleFonts.inter(
                                        color: context.hintColor, fontSize: 11)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: stockColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${item.stock} in stock',
                                      style: GoogleFonts.inter(
                                          color: stockColor, fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ],
                          )),
                          isAdding
                              ? const SizedBox(
                                  width: 28, height: 28,
                                  child: CircularProgressIndicator(
                                      color: EnhancedTheme.primaryTeal,
                                      strokeWidth: 2.5))
                              : GestureDetector(
                                  onTap: () => _addItem(item),
                                  child: Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: EnhancedTheme.primaryTeal.withValues(
                                          alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: EnhancedTheme.primaryTeal
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        color: EnhancedTheme.primaryTeal, size: 18),
                                  ),
                                ),
                        ]),
                      ),
                    ),
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
