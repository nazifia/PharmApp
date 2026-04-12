import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

String _apiError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    if (data is String && data.isNotEmpty) return data;
  }
  return e.toString();
}

// ── Providers ────────────────────────────────────────────────────────────────

final transfersListProvider = FutureProvider.autoDispose
    .family<List<dynamic>, TransfersParams>((ref, params) {
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
      other is TransfersParams &&
      other.status == status &&
      other.direction == direction;

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
      case 1:
        return 'pending';
      case 2:
        return 'approved';
      case 3:
        return 'received';
      case 4:
        return 'rejected';
      default:
        return null;
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
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text('New Transfer',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative glow
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.16),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(
            child: Column(children: [
          _buildHeader(context),
          _buildFilterChips(),
          Expanded(
              child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: _buildTransfersList(transfersAsync),
          )),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppShell.roleFallback(ref));
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Transfers',
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                Text('Manage stock transfers',
                    style: GoogleFonts.inter(
                        color: context.subLabelColor, fontSize: 12)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.swap_horiz_rounded,
                  color: EnhancedTheme.primaryTeal, size: 14),
              const SizedBox(width: 5),
              Text('Stock',
                  style: GoogleFonts.inter(
                      color: EnhancedTheme.primaryTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.15);

  // ── Filter Chips ───────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    const filters = ['All', 'Pending', 'Approved', 'Received', 'Rejected'];
    final filterColors = [
      context.labelColor,
      EnhancedTheme.warningAmber,
      EnhancedTheme.successGreen,
      EnhancedTheme.infoBlue,
      EnhancedTheme.errorRed,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: filters.asMap().entries.map((e) {
          final active = e.key == _statusFilter;
          final color = filterColors[e.key];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.12),
                        ])
                      : null,
                  color: active ? null : context.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? color.withValues(alpha: 0.6)
                        : context.borderColor,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(e.value,
                    style: GoogleFonts.inter(
                        color: active ? color : context.subLabelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }).toList()),
      ),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: -0.1);
  }

  // ── Transfers List ─────────────────────────────────────────────────────────

  Widget _buildTransfersList(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EnhancedTheme.loadingShimmer(height: 100, radius: 18),
        ),
      ),
      error: (e, _) => Center(
          child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_off_rounded,
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.6),
                      size: 36),
                ),
                const SizedBox(height: 14),
                Text('Could not load transfers',
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('$e',
                    style: GoogleFonts.inter(
                        color: context.subLabelColor, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded,
                      color: EnhancedTheme.primaryTeal, size: 16),
                  label: const Text('Retry',
                      style: TextStyle(color: EnhancedTheme.primaryTeal)),
                ),
              ]),
        ),
      )),
      data: (transfers) {
        if (transfers.isEmpty) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                      EnhancedTheme.accentCyan.withValues(alpha: 0.06),
                    ]),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.swap_horiz_rounded,
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.6),
                      size: 40),
                ),
                const SizedBox(height: 16),
                Text('No transfers found',
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Tap + to create a new transfer',
                    style: GoogleFonts.inter(
                        color: context.subLabelColor, fontSize: 12)),
              ]));
        }
        if (transfers.length == 1) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _transferCard(transfers[0] as Map<String, dynamic>, 0),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: transfers.length,
          itemBuilder: (_, i) =>
              _transferCard(transfers[i] as Map<String, dynamic>, i),
        );
      },
    );
  }

  Widget _transferCard(Map<String, dynamic> t, int index) {
    final id = t['id'] ?? 0;
    final itemName =
        t['itemName'] as String? ?? t['item_name'] as String? ?? 'Unknown';
    final requestedQty = t['requestedQty'] ?? t['requested_qty'] ?? 0;
    final approvedQty = t['approvedQty'] ?? t['approved_qty'];
    final unit = t['unit'] as String? ?? 'Pcs';
    final isFromWholesale =
        t['fromWholesale'] == true || t['from_wholesale'] == true;
    final status = (t['status'] as String? ?? 'pending').toLowerCase();
    final dateStr =
        t['createdAt'] as String? ?? t['created_at'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = EnhancedTheme.successGreen;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Approved';
        break;
      case 'received':
        statusColor = EnhancedTheme.infoBlue;
        statusIcon = Icons.inventory_rounded;
        statusLabel = 'Received';
        break;
      case 'rejected':
        statusColor = EnhancedTheme.errorRed;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = EnhancedTheme.warningAmber;
        statusIcon = Icons.hourglass_bottom_rounded;
        statusLabel = 'Pending';
    }

    final directionColor = isFromWholesale
        ? EnhancedTheme.accentPurple
        : EnhancedTheme.successGreen;
    final directionIcon = isFromWholesale
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final directionLabel =
        isFromWholesale ? 'Wholesale → Retail' : 'Retail → Wholesale';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
            ),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Timeline left strip
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [statusColor, statusColor.withValues(alpha: 0.4)],
                  ),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18)),
                ),
              ),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Direction icon + name + status
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                directionColor.withValues(alpha: 0.25),
                                directionColor.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: directionColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(directionIcon,
                              color: directionColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(itemName,
                                  style: GoogleFonts.inter(
                                      color: context.labelColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(Icons.swap_horiz_rounded,
                                    color: directionColor, size: 12),
                                const SizedBox(width: 4),
                                Text(directionLabel,
                                    style: GoogleFonts.inter(
                                        color: context.hintColor,
                                        fontSize: 11)),
                              ]),
                            ])),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.08),
                            ]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.35)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: GoogleFonts.inter(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),

                      // Row 2: Qty + date info
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: directionColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$requestedQty $unit requested',
                              style: GoogleFonts.inter(
                                  color: directionColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (approvedQty != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.successGreen
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$approvedQty $unit approved',
                                style: GoogleFonts.inter(
                                    color: EnhancedTheme.successGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const Spacer(),
                        if (dateStr.isNotEmpty)
                          Text(_formatDate(dateStr),
                              style: GoogleFonts.inter(
                                  color: context.hintColor, fontSize: 10)),
                      ]),

                      // Action buttons
                      if (status == 'pending') ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _actionBtn(
                                  context,
                                  'Approve',
                                  EnhancedTheme.successGreen,
                                  Icons.check_rounded,
                                  () {
                                    // Look up available stock from the source store
                                    final srcInv = isFromWholesale
                                        ? ref.read(wholesaleInventoryProvider)
                                        : ref.read(retailInventoryProvider);
                                    final srcItems =
                                        srcInv.valueOrNull ?? [];
                                    final matches = srcItems
                                        .where((i) => i.name == itemName);
                                    final availableQty = matches.isNotEmpty
                                        ? matches.first.stock
                                        : null;
                                    _showApproveDialog(
                                        id is int
                                            ? id
                                            : int.tryParse('$id') ?? 0,
                                        itemName,
                                        requestedQty is int
                                            ? requestedQty
                                            : int.tryParse('$requestedQty') ??
                                                0,
                                        availableQty);
                                  })),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _actionBtn(
                                  context,
                                  'Reject',
                                  EnhancedTheme.errorRed,
                                  Icons.close_rounded,
                                  () => _rejectTransfer(id is int
                                      ? id
                                      : int.tryParse('$id') ?? 0))),
                        ]),
                      ],
                      if (status == 'approved') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                            width: double.infinity,
                            child: _actionBtn(
                                context,
                                'Mark Received',
                                EnhancedTheme.infoBlue,
                                Icons.inventory_rounded,
                                () => _showReceiveDialog(
                                      id is int ? id : int.tryParse('$id') ?? 0,
                                      itemName,
                                      approvedQty ?? requestedQty,
                                      unit,
                                      isFromWholesale,
                                    ))),
                      ],
                    ]),
              )),
            ])),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.08);
  }

  Widget _actionBtn(BuildContext context, String label, Color color,
      IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _showApproveDialog(
      int id, String itemName, int requestedQty, int? availableQty) {
    final qtyCtrl = TextEditingController(text: '$requestedQty');
    // Dispose the controller when the sheet closes, regardless of how it closes
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Use builder context (ctx) for MediaQuery / theme — NOT the outer screen
      // context — so the sheet correctly tracks keyboard insets
      builder: (ctx) => Padding(
        // ctx.viewInsets reflects the keyboard opening inside this sheet
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: ctx.hintColor,
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          EnhancedTheme.successGreen.withValues(alpha: 0.25),
                          EnhancedTheme.successGreen.withValues(alpha: 0.1),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: EnhancedTheme.successGreen, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Approve Transfer',
                              style: GoogleFonts.outfit(
                                  color: ctx.labelColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          Text(itemName,
                              style: GoogleFonts.inter(
                                  color: ctx.subLabelColor, fontSize: 13)),
                        ])),
                  ]),
                  const SizedBox(height: 20),
                  Text('Approved Quantity',
                      style: GoogleFonts.inter(
                          color: ctx.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                        color: ctx.labelColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      hintStyle: GoogleFonts.inter(color: ctx.hintColor),
                      filled: true,
                      fillColor: ctx.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ctx.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ctx.borderColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide(
                            color: EnhancedTheme.primaryTeal, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('Requested: $requestedQty',
                        style: GoogleFonts.inter(
                            color: ctx.hintColor, fontSize: 12)),
                    if (availableQty != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (availableQty > 0
                                  ? EnhancedTheme.successGreen
                                  : EnhancedTheme.errorRed)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (availableQty > 0
                                    ? EnhancedTheme.successGreen
                                    : EnhancedTheme.errorRed)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 11,
                            color: availableQty > 0
                                ? EnhancedTheme.successGreen
                                : EnhancedTheme.errorRed,
                          ),
                          const SizedBox(width: 4),
                          Text('In stock: $availableQty',
                              style: GoogleFonts.inter(
                                  color: availableQty > 0
                                      ? EnhancedTheme.successGreen
                                      : EnhancedTheme.errorRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final qty = int.tryParse(qtyCtrl.text) ?? 0;
                          if (qty <= 0) return;
                          if (availableQty != null && qty > availableQty) {
                            // Use outer context's ScaffoldMessenger so the
                            // snackbar appears on the main scaffold
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: EnhancedTheme.warningAmber
                                  .withValues(alpha: 0.92),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              content: Row(children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.black, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        'Qty exceeds available stock ($availableQty)',
                                        style: GoogleFonts.inter(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600))),
                              ]),
                            ));
                            return;
                          }
                          Navigator.pop(ctx);
                          await _approveTransfer(id, qty);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.successGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Confirm Approve',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      )),
                ]),
          ),
        ),
      ),
    ).whenComplete(qtyCtrl.dispose);
  }

  Future<void> _approveTransfer(int id, int qty) async {
    try {
      await ref.read(posApiProvider).approveTransfer(id, qty);
      ref.invalidate(transfersListProvider(_params));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Transfer approved',
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_apiError(e),
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  Future<void> _rejectTransfer(int id) async {
    try {
      await ref.read(posApiProvider).rejectTransfer(id);
      ref.invalidate(transfersListProvider(_params));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.cancel_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Transfer rejected',
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_apiError(e),
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  void _showReceiveDialog(
      int id, String itemName, dynamic qty, String unit, bool isFromWholesale) {
    final src = isFromWholesale ? 'Wholesale' : 'Retail';
    final dst = isFromWholesale ? 'Retail' : 'Wholesale';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: EnhancedTheme.infoBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        EnhancedTheme.infoBlue.withValues(alpha: 0.25),
                        EnhancedTheme.infoBlue.withValues(alpha: 0.1),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.inventory_rounded,
                        color: EnhancedTheme.infoBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text('Confirm Receive',
                          style: GoogleFonts.outfit(
                              color: ctx.labelColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 16),
                Text(itemName,
                    style: GoogleFonts.inter(
                        color: ctx.labelColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.infoBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: EnhancedTheme.infoBlue.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Text(src,
                        style: GoogleFonts.outfit(
                            color: EnhancedTheme.accentPurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: EnhancedTheme.infoBlue, size: 16),
                    const SizedBox(width: 8),
                    Text(dst,
                        style: GoogleFonts.outfit(
                            color: EnhancedTheme.successGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.infoBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$qty $unit',
                          style: GoogleFonts.inter(
                              color: EnhancedTheme.infoBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('Stock will be updated in both stores.',
                    style:
                        GoogleFonts.inter(color: ctx.hintColor, fontSize: 12)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: ctx.borderColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: ctx.subLabelColor,
                            fontWeight: FontWeight.w600)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _receiveTransfer(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.infoBlue,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Receive',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ]),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.infoBlue.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.inventory_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Transfer received — stock updated',
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_apiError(e),
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour12:$m $ampm';
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
  ConsumerState<_CreateTransferSheet> createState() =>
      _CreateTransferSheetState();
}

class _CreateTransferSheetState extends ConsumerState<_CreateTransferSheet> {
  String _itemName = '';
  int? _availableStock; // null = no matching item selected yet
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Please fill item name and quantity',
                  style: GoogleFonts.inter(
                      color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Transfer created',
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_apiError(e),
                    style: GoogleFonts.inter(
                        color: Colors.black, fontWeight: FontWeight.w600))),
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
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.hintColor,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),

            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.25),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: EnhancedTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: 14),
              Text('New Transfer',
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 24),

            // Item Name
            Text('Item Name',
                style: GoogleFonts.inter(
                    color: context.labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ItemAutocomplete(
              key: ValueKey(_fromWholesale ? 'wholesale' : 'retail'),
              sourceStore: _fromWholesale ? 'wholesale' : 'retail',
              // Fired only when user picks a suggestion — update stock display
              onSelected: (name) {
                setState(() {
                  _itemName = name;
                  final inventoryAsync = _fromWholesale
                      ? ref.read(wholesaleInventoryProvider)
                      : ref.read(retailInventoryProvider);
                  final items = inventoryAsync.valueOrNull ?? [];
                  final matches = items.where((i) => i.name == name);
                  _availableStock =
                      matches.isNotEmpty ? matches.first.stock : null;
                });
              },
              // Fired on every keystroke — keep _itemName in sync for submit,
              // but clear the stock badge so stale "Available" isn't shown
              onTextChanged: (text) {
                setState(() {
                  _itemName = text;
                  _availableStock = null; // badge hidden until a match is picked
                });
              },
            ),
            if (_itemName.isNotEmpty && _availableStock != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_availableStock! > 0
                          ? EnhancedTheme.successGreen
                          : EnhancedTheme.errorRed)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_availableStock! > 0
                            ? EnhancedTheme.successGreen
                            : EnhancedTheme.errorRed)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _availableStock! > 0
                        ? Icons.inventory_2_rounded
                        : Icons.warning_amber_rounded,
                    color: _availableStock! > 0
                        ? EnhancedTheme.successGreen
                        : EnhancedTheme.errorRed,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text('Available in stock: $_availableStock $_unit',
                      style: GoogleFonts.inter(
                          color: _availableStock! > 0
                              ? EnhancedTheme.successGreen
                              : EnhancedTheme.errorRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            const SizedBox(height: 16),

            // Quantity & Unit
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Quantity',
                        style: GoogleFonts.inter(
                            color: context.labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(
                          color: context.labelColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.inter(color: context.hintColor),
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
                          borderSide: BorderSide(
                              color: EnhancedTheme.primaryTeal, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Unit',
                        style: GoogleFonts.inter(
                            color: context.labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
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
                          dropdownColor: context.isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          style: GoogleFonts.inter(
                              color: context.labelColor, fontSize: 14),
                          items: ['Pcs', 'Pack', 'Carton', 'Box']
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => _unit = v ?? 'Pcs'),
                        ),
                      ),
                    ),
                  ])),
            ]),
            const SizedBox(height: 16),

            // Direction Toggle
            Text('Direction',
                style: GoogleFonts.inter(
                    color: context.labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              _directionChip(
                  true, 'Wholesale → Retail', Icons.arrow_forward_rounded),
              const SizedBox(width: 10),
              _directionChip(
                  false, 'Retail → Wholesale', Icons.arrow_back_rounded),
            ]),
            const SizedBox(height: 16),

            // Notes
            Text('Notes (optional)',
                style: GoogleFonts.inter(
                    color: context.labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              style: GoogleFonts.inter(color: context.labelColor, fontSize: 14),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add notes...',
                hintStyle:
                    GoogleFonts.inter(color: context.hintColor, fontSize: 13),
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
                  borderSide:
                      BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2))
                      : Text('Create Transfer',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                )),
          ])),
    );
  }

  Widget _directionChip(bool isFromWholesale, String label, IconData icon) {
    final active = _fromWholesale == isFromWholesale;
    final color = isFromWholesale
        ? EnhancedTheme.accentPurple
        : EnhancedTheme.successGreen;
    return Expanded(
        child: GestureDetector(
      onTap: () => setState(() {
        _fromWholesale = isFromWholesale;
        _itemName = '';
        _availableStock = null;
      }),
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
          color: active ? null : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : context.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? color : context.subLabelColor, size: 16),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: GoogleFonts.inter(
                      color: active ? color : context.subLabelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ));
  }
}

// ── Inventory Item Autocomplete ───────────────────────────────────────────────

class _ItemAutocomplete extends ConsumerWidget {
  /// Called when the user picks a suggestion from the dropdown.
  final ValueChanged<String> onSelected;

  /// Called on every keystroke so the parent can track the raw typed text
  /// (used in submit validation). Separate from [onSelected] so that selecting
  /// from the dropdown doesn't fire both callbacks and cause a double-setState.
  final ValueChanged<String> onTextChanged;

  final String sourceStore; // 'wholesale' or 'retail'
  const _ItemAutocomplete({
    super.key,
    required this.onSelected,
    required this.onTextChanged,
    required this.sourceStore,
  });

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
          onChanged: onTextChanged,
          style: GoogleFonts.inter(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search medication...',
            hintStyle:
                GoogleFonts.inter(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.medication_rounded,
                color: context.hintColor, size: 18),
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
              borderSide:
                  BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
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
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.medication_rounded,
                            color: EnhancedTheme.primaryTeal, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(option,
                                style: GoogleFonts.inter(
                                    color: context.labelColor, fontSize: 14),
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
