import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final transfersListProvider = FutureProvider.autoDispose.family<List<dynamic>, TransfersParams>((ref, params) {
  return ref.watch(posApiProvider).fetchTransfers(
    status: params.status,
    direction: params.direction,
  );
});

class TransfersParams {
  final String? status;
  final String? direction;
  const TransfersParams({this.status, this.direction});

  @override
  bool operator ==(Object other) =>
      other is TransfersParams && other.status == status && other.direction == direction;

  @override
  int get hashCode => Object.hash(status, direction);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  int _statusFilter = 0; // 0=All, 1=Pending, 2=Approved, 3=Received, 4=Rejected

  String? get _filterStatus {
    switch (_statusFilter) {
      case 1: return 'pending';
      case 2: return 'approved';
      case 3: return 'received';
      case 4: return 'rejected';
      default: return null;
    }
  }

  TransfersParams get _params => TransfersParams(status: _filterStatus);

  Future<void> _refresh() async {
    ref.invalidate(transfersListProvider(_params));
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreateTransferSheet(onCreated: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transfersAsync = ref.watch(transfersListProvider(_params));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Transfer', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context),
          _filterChips(),
          Expanded(child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: _transfersList(transfersAsync),
          )),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
        onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppShell.roleFallback(ref));
                }
              },
      ),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Transfers',
            style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('Manage stock transfers',
            style: TextStyle(color: context.subLabelColor, fontSize: 11)),
      ])),
    ]),
  );

  // ── Filter Chips ───────────────────────────────────────────────────────────

  Widget _filterChips() {
    const filters = ['All', 'Pending', 'Approved', 'Received', 'Rejected'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: filters.asMap().entries.map((e) {
          final active = e.key == _statusFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? EnhancedTheme.primaryTeal : context.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? EnhancedTheme.primaryTeal : context.borderColor,
                  ),
                ),
                child: Text(e.value, textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active ? Colors.white : context.subLabelColor,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }

  // ── Transfers List ─────────────────────────────────────────────────────────

  Widget _transfersList(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EnhancedTheme.loadingShimmer(height: 90, radius: 16),
        ),
      ),
      error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
        const SizedBox(height: 12),
        Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _refresh,
          child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal)),
        ),
      ])),
      data: (transfers) {
        if (transfers.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.swap_horiz_rounded, color: context.hintColor, size: 56),
            const SizedBox(height: 12),
            Text('No transfers found',
                style: TextStyle(color: context.subLabelColor, fontSize: 15, fontWeight: FontWeight.w500)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: transfers.length,
          itemBuilder: (_, i) => _transferCard(transfers[i] as Map<String, dynamic>),
        );
      },
    );
  }

  Widget _transferCard(Map<String, dynamic> t) {
    final id = t['id'] ?? 0;
    final itemName = t['itemName'] as String? ?? t['item_name'] as String? ?? 'Unknown';
    final requestedQty = t['requestedQty'] ?? t['requested_qty'] ?? 0;
    final approvedQty = t['approvedQty'] ?? t['approved_qty'];
    final unit = t['unit'] as String? ?? 'Pcs';
    final isFromWholesale = t['fromWholesale'] == true || t['from_wholesale'] == true;
    final status = (t['status'] as String? ?? 'pending').toLowerCase();
    final dateStr = t['createdAt'] as String? ?? t['created_at'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = EnhancedTheme.successGreen;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'received':
        statusColor = EnhancedTheme.infoBlue;
        statusIcon = Icons.inventory_rounded;
        break;
      case 'rejected':
        statusColor = EnhancedTheme.errorRed;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = EnhancedTheme.warningAmber;
        statusIcon = Icons.hourglass_bottom_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: (isFromWholesale ? EnhancedTheme.accentPurple : EnhancedTheme.successGreen).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isFromWholesale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isFromWholesale ? EnhancedTheme.accentPurple : EnhancedTheme.successGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(itemName,
                      style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$requestedQty $unit · ${isFromWholesale ? "Wholesale → Retail" : "Retail → Wholesale"}',
                      style: TextStyle(color: context.hintColor, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (approvedQty != null) ...[
                const SizedBox(height: 6),
                Text('Approved: $approvedQty $unit',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ],
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_formatDate(dateStr),
                    style: TextStyle(color: context.hintColor, fontSize: 10)),
              ],
              if (status == 'pending') ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _actionBtn('Approve', EnhancedTheme.successGreen, () => _showApproveDialog(id is int ? id : int.tryParse('$id') ?? 0, itemName, requestedQty is int ? requestedQty : int.tryParse('$requestedQty') ?? 0))),
                  const SizedBox(width: 8),
                  Expanded(child: _actionBtn('Reject', EnhancedTheme.errorRed, () => _rejectTransfer(id is int ? id : int.tryParse('$id') ?? 0))),
                ]),
              ],
              if (status == 'approved') ...[
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: _actionBtn('Receive', EnhancedTheme.infoBlue, () => _showReceiveDialog(
                  id is int ? id : int.tryParse('$id') ?? 0,
                  itemName,
                  approvedQty ?? requestedQty,
                  unit,
                  isFromWholesale,
                ))),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(child: Text(label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ),
    );
  }

  void _showApproveDialog(int id, String itemName, int requestedQty) {
    final qtyCtrl = TextEditingController(text: '$requestedQty');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          Text('Approve Transfer', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(itemName, style: TextStyle(color: context.subLabelColor, fontSize: 14)),
          const SizedBox(height: 20),
          Text('Approved Quantity', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.labelColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              hintStyle: TextStyle(color: context.hintColor),
              filled: true,
              fillColor: context.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.borderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Requested: $requestedQty', style: TextStyle(color: context.hintColor, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;
              Navigator.pop(context);
              await _approveTransfer(id, qty);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Confirm Approve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ]),
      ),
    );
  }

  Future<void> _approveTransfer(int id, int qty) async {
    try {
      await ref.read(posApiProvider).approveTransfer(id, qty);
      ref.invalidate(transfersListProvider(_params));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transfer approved'),
          backgroundColor: EnhancedTheme.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    }
  }

  Future<void> _rejectTransfer(int id) async {
    try {
      await ref.read(posApiProvider).rejectTransfer(id);
      ref.invalidate(transfersListProvider(_params));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transfer rejected'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    }
  }

  void _showReceiveDialog(int id, String itemName, dynamic qty, String unit, bool isFromWholesale) {
    final src = isFromWholesale ? 'Wholesale' : 'Retail';
    final dst = isFromWholesale ? 'Retail' : 'Wholesale';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Receive',
            style: TextStyle(color: ctx.labelColor, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(itemName,
              style: TextStyle(color: ctx.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Move $qty $unit from $src → $dst.',
              style: TextStyle(color: ctx.subLabelColor, fontSize: 13)),
          const SizedBox(height: 8),
          Text('Stock will be updated in both stores.',
              style: TextStyle(color: ctx.hintColor, fontSize: 12)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ctx.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _receiveTransfer(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.infoBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Receive', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _receiveTransfer(int id) async {
    try {
      await ref.read(posApiProvider).receiveTransfer(id);
      ref.invalidate(transfersListProvider(_params));
      // Refresh inventory so stock counts reflect the transfer
      ref.invalidate(inventoryListProvider);
      ref.invalidate(retailInventoryProvider);
      ref.invalidate(wholesaleInventoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transfer received — stock updated'),
          backgroundColor: EnhancedTheme.infoBlue,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
    } catch (_) {
      return raw;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CREATE TRANSFER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _CreateTransferSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTransferSheet({required this.onCreated});

  @override
  ConsumerState<_CreateTransferSheet> createState() => _CreateTransferSheetState();
}

class _CreateTransferSheetState extends ConsumerState<_CreateTransferSheet> {
  String _itemName = '';
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _unit = 'Pcs';
  bool _fromWholesale = true;
  bool _submitting = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _itemName.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (name.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill item name and quantity'),
        backgroundColor: EnhancedTheme.warningAmber,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(posApiProvider).createTransfer(
        itemName: name,
        requestedQty: qty,
        unit: _unit,
        fromWholesale: _fromWholesale,
        notes: _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transfer created'),
          backgroundColor: EnhancedTheme.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        Text('New Transfer', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),

        // Item Name (searchable autocomplete from inventory)
        Text('Item Name', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _ItemAutocomplete(
          sourceStore: _fromWholesale ? 'wholesale' : 'retail',
          onSelected: (name) => setState(() => _itemName = name),
        ),
        const SizedBox(height: 16),

        // Quantity & Unit
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quantity', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.labelColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: context.hintColor),
                filled: true,
                fillColor: context.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Unit', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _unit,
                  dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: context.labelColor, fontSize: 14),
                  items: ['Pcs', 'Pack', 'Carton', 'Box'].map((u) =>
                    DropdownMenuItem(value: u, child: Text(u))
                  ).toList(),
                  onChanged: (v) => setState(() => _unit = v ?? 'Pcs'),
                ),
              ),
            ),
          ])),
        ]),
        const SizedBox(height: 16),

        // Direction Toggle
        Text('Direction', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _directionChip(true, 'Wholesale → Retail', Icons.arrow_forward_rounded),
          const SizedBox(width: 10),
          _directionChip(false, 'Retail → Wholesale', Icons.arrow_back_rounded),
        ]),
        const SizedBox(height: 16),

        // Notes
        Text('Notes (optional)', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          style: TextStyle(color: context.labelColor, fontSize: 14),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Add notes...',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 24),

        // Submit
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        )),
      ])),
    );
  }

  Widget _directionChip(bool isFromWholesale, String label, IconData icon) {
    final active = _fromWholesale == isFromWholesale;
    final color = isFromWholesale ? EnhancedTheme.accentPurple : EnhancedTheme.successGreen;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() { _fromWholesale = isFromWholesale; _itemName = ''; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : context.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? color : context.subLabelColor, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(
              color: active ? color : context.subLabelColor,
              fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ));
  }
}

// ── Inventory Item Autocomplete ───────────────────────────────────────────────

class _ItemAutocomplete extends ConsumerWidget {
  final ValueChanged<String> onSelected;
  final String sourceStore; // 'wholesale' or 'retail'
  const _ItemAutocomplete({required this.onSelected, required this.sourceStore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = sourceStore == 'wholesale'
        ? ref.watch(wholesaleInventoryProvider)
        : ref.watch(retailInventoryProvider);
    final items = inventoryAsync.valueOrNull ?? [];
    final itemNames = items.map((i) => i.name).toSet().toList()..sort();

    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return itemNames;
        return itemNames.where((n) => n.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          onChanged: (v) => onSelected(v),
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search medication...',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.medication_rounded, color: context.hintColor, size: 18),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        );
      },
      optionsViewBuilder: (context, onOptionSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onOptionSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.medication_rounded, color: EnhancedTheme.primaryTeal, size: 16),
                        const SizedBox(width: 10),
                        Expanded(child: Text(option,
                            style: TextStyle(color: context.labelColor, fontSize: 14),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
