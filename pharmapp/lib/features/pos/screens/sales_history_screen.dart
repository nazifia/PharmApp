import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/pos_api_provider.dart';
import 'receipt_screen.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final salesListProvider = FutureProvider.autoDispose.family<List<dynamic>, SalesParams>((ref, params) {
  return ref.watch(posApiProvider).fetchSales(
    search: params.search,
    from: params.from,
    to: params.to,
  );
});

final saleDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) {
  return ref.watch(posApiProvider).fetchSaleDetail(id);
});

class SalesParams {
  final String? search;
  final String? from;
  final String? to;
  const SalesParams({this.search, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is SalesParams &&
      other.search == search && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(search, from, to);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _dateFilter = 3; // default to All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  SalesParams get _params {
    final now = DateTime.now();
    String? from;
    String? to;
    switch (_dateFilter) {
      case 0:
        from = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
        to = now.toIso8601String().split('T').first;
        break;
      case 1:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String().split('T').first;
        to = now.toIso8601String().split('T').first;
        break;
      case 2:
        from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
        to = now.toIso8601String().split('T').first;
        break;
      default:
        break;
    }
    return SalesParams(search: _searchQuery.isEmpty ? null : _searchQuery, from: from, to: to);
  }

  Future<void> _refresh() async {
    ref.invalidate(salesListProvider(_params));
  }

  void _showSaleDetail(int saleId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SaleDetailSheet(saleId: saleId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesListProvider(_params));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blobs
        Positioned(top: -60, right: -40,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(bottom: 100, left: -60,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(child: Column(children: [
          _header(context),
          _searchBar(context),
          _dateFilterChips(),
          Expanded(child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: _salesList(salesAsync),
          )),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sales History',
            style: TextStyle(color: context.labelColor, fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        Text('View receipts & manage returns',
            style: TextStyle(color: context.subLabelColor, fontSize: 12)),
      ])),
      // Receipt count badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4), blurRadius: 8)],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_rounded, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text('Receipts', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    ]),
  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _searchBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by receipt ID or customer name...',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ),
  ).animate().fadeIn(duration: 350.ms, delay: 50.ms);

  // ── Date Filter Chips ──────────────────────────────────────────────────────

  Widget _dateFilterChips() {
    const filters = ['Today', 'This Week', 'This Month', 'All'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(children: filters.asMap().entries.map((e) {
        final active = e.key == _dateFilter;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _dateFilter = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? EnhancedTheme.primaryTeal : context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? EnhancedTheme.primaryTeal : context.borderColor,
                width: active ? 1.5 : 1,
              ),
              boxShadow: active ? [
                BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                    blurRadius: 8, offset: const Offset(0, 2))
              ] : null,
            ),
            child: Text(e.value, textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? Colors.white : context.subLabelColor,
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ));
      }).toList()),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // ── Sales List ─────────────────────────────────────────────────────────────

  Widget _salesList(AsyncValue<List<dynamic>> salesAsync) {
    return salesAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EnhancedTheme.loadingShimmer(height: 90, radius: 18),
        ),
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
        Text('Connection error', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ])),
      data: (sales) {
        if (sales.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                  EnhancedTheme.accentCyan.withValues(alpha: 0.05),
                ]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.primaryTeal, size: 48),
            ),
            const SizedBox(height: 16),
            Text('No sales found',
                style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Try adjusting your date filter or search',
                style: TextStyle(color: context.subLabelColor, fontSize: 13)),
          ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sales.length,
          itemBuilder: (_, i) => _saleCard(sales[i] as Map<String, dynamic>, i),
        );
      },
    );
  }

  Widget _saleCard(Map<String, dynamic> sale, int index) {
    final id = sale['id'] ?? 0;
    final receiptId = sale['receiptId'] as String? ?? sale['receipt_id'] as String? ?? '#$id';
    final customerName = sale['customerName'] as String? ?? sale['customer_name'] as String? ?? 'Walk-in';
    final totalAmount = (sale['totalAmount'] as num?)?.toDouble() ?? (sale['total_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = sale['paymentMethod'] as String? ?? sale['payment_method'] as String? ?? 'cash';
    final status = (sale['status'] as String? ?? 'completed').toLowerCase();
    final dateStr = sale['createdAt'] as String? ?? sale['created_at'] as String? ?? sale['created'] as String? ?? '';
    final isWholesale = sale['isWholesale'] as bool? ?? false;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        statusIcon = Icons.undo_rounded;
        break;
      case 'partial_return':
      case 'partially_returned':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial';
        statusIcon = Icons.remove_circle_outline_rounded;
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showSaleDetail(id is int ? id : int.tryParse('$id') ?? 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: [
                // colored top accent bar
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.7), statusColor.withValues(alpha: 0.2)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    // Icon
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        isWholesale ? Icons.business_center_rounded : Icons.receipt_rounded,
                        color: EnhancedTheme.accentCyan, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(receiptId,
                            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (isWholesale)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('B2B', style: TextStyle(color: EnhancedTheme.accentPurple,
                                fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.person_outline_rounded, color: context.hintColor, size: 12),
                        const SizedBox(width: 4),
                        Expanded(child: Text(customerName,
                            style: TextStyle(color: context.subLabelColor, fontSize: 12),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        _paymentBadge(paymentMethod),
                        const SizedBox(width: 6),
                        if (dateStr.isNotEmpty) ...[
                          Icon(Icons.access_time_rounded, color: context.hintColor, size: 11),
                          const SizedBox(width: 3),
                          Text(_formatDateTime(dateStr),
                              style: TextStyle(color: context.hintColor, fontSize: 10)),
                        ],
                      ]),
                    ])),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_fmtNaira(totalAmount),
                          style: const TextStyle(color: EnhancedTheme.primaryTeal,
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(statusIcon, color: statusColor, size: 10),
                          const SizedBox(width: 3),
                          Text(statusLabel,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 60 * index)).slideY(begin: 0.05);
  }

  Widget _paymentBadge(String method) {
    Color color;
    IconData icon;
    switch (method.toLowerCase()) {
      case 'card':
      case 'pos':
        color = EnhancedTheme.accentPurple;
        icon = Icons.credit_card_rounded;
        break;
      case 'wallet':
        color = EnhancedTheme.warningAmber;
        icon = Icons.account_balance_wallet_rounded;
        break;
      case 'bank_transfer':
      case 'transfer':
        color = EnhancedTheme.infoBlue;
        icon = Icons.account_balance_rounded;
        break;
      default:
        color = EnhancedTheme.accentCyan;
        icon = Icons.payments_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 3),
        Text(method.toUpperCase(),
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, $h:$m';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SALE DETAIL BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _SaleDetailSheet extends ConsumerStatefulWidget {
  final int saleId;
  const _SaleDetailSheet({required this.saleId});

  @override
  ConsumerState<_SaleDetailSheet> createState() => _SaleDetailSheetState();
}

class _SaleDetailSheetState extends ConsumerState<_SaleDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(saleDetailProvider(widget.saleId));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: EnhancedTheme.errorRed, size: 36),
            ),
            const SizedBox(height: 12),
            Text('Failed to load details', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12),
                textAlign: TextAlign.center),
          ])),
        ),
        data: (data) => _buildDetail(context, data),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Map<String, dynamic> data) {
    final receiptId = data['receiptId'] as String? ?? data['receipt_id'] as String? ?? '#${widget.saleId}';
    final customerName = data['customerName'] as String? ?? data['customer_name'] as String? ?? 'Walk-in';
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? (data['total_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = data['paymentMethod'] as String? ?? data['payment_method'] as String? ?? 'cash';
    final status = (data['status'] as String? ?? 'completed').toLowerCase();
    final dateStr = data['createdAt'] as String? ?? data['created_at'] as String? ?? data['created'] as String? ?? '';
    final items = (data['items'] as List<dynamic>?) ?? [];
    final returns = (data['returns'] as List<dynamic>?) ?? [];

    final payments = <String, double>{};
    final paymentsList = data['payments'] as List<dynamic>? ?? [];
    for (final p in paymentsList) {
      final pm = p as Map<String, dynamic>;
      final method = pm['paymentMethod'] as String? ?? 'cash';
      final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
      if (amount > 0) payments[method] = (payments[method] ?? 0) + amount;
    }
    if (payments.isEmpty) {
      final pc = (data['paymentCash'] as num?)?.toDouble() ?? 0;
      final pp = (data['paymentPos'] as num?)?.toDouble() ?? 0;
      final pt = (data['paymentTransfer'] as num?)?.toDouble() ?? 0;
      final pw = (data['paymentWallet'] as num?)?.toDouble() ?? 0;
      if (pc > 0) payments['cash'] = pc;
      if (pp > 0) payments['pos'] = pp;
      if (pt > 0) payments['transfer'] = pt;
      if (pw > 0) payments['wallet'] = pw;
    }

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        statusIcon = Icons.undo_rounded;
        break;
      case 'partial_return':
      case 'partially_returned':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial Return';
        statusIcon = Icons.remove_circle_outline_rounded;
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Drag handle
        Center(child: Container(
          width: 44, height: 4,
          decoration: BoxDecoration(
            color: context.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        const SizedBox(height: 20),

        // Header card
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.08),
                    statusColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(receiptId,
                        style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.person_outline_rounded, color: context.hintColor, size: 14),
                      const SizedBox(width: 5),
                      Text(customerName,
                          style: TextStyle(color: context.subLabelColor, fontSize: 14)),
                    ]),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 5),
                      Text(statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.access_time_rounded, color: context.hintColor, size: 12),
                    const SizedBox(width: 5),
                    Text(_formatDateTime(dateStr),
                        style: TextStyle(color: context.hintColor, fontSize: 12)),
                  ]),
                ],
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Items section
        _sectionLabel('Items', Icons.inventory_2_rounded, EnhancedTheme.accentCyan),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text('No items data', style: TextStyle(color: context.subLabelColor, fontSize: 13))
        else
          ...items.map((item) => _itemRow(context, item as Map<String, dynamic>, status)),
        const SizedBox(height: 20),

        // Payments summary
        if (payments.isNotEmpty) ...[
          _sectionLabel('Payment Breakdown', Icons.payments_rounded, EnhancedTheme.successGreen),
          const SizedBox(height: 10),
          _paymentsSummary(context, payments),
          const SizedBox(height: 20),
        ],

        // Returns
        if (returns.isNotEmpty) ...[
          _sectionLabel('Returns', Icons.undo_rounded, EnhancedTheme.errorRed),
          const SizedBox(height: 10),
          ...returns.map((r) => _returnRow(context, r as Map<String, dynamic>)),
          const SizedBox(height: 20),
        ],

        // Total bar
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Amount',
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.credit_card_rounded, color: context.hintColor, size: 13),
                    const SizedBox(width: 5),
                    Text(paymentMethod.toUpperCase(),
                        style: TextStyle(color: context.hintColor, fontSize: 11, fontWeight: FontWeight.w500)),
                  ]),
                ]),
                const Spacer(),
                Text(_fmtNaira(totalAmount),
                    style: const TextStyle(color: EnhancedTheme.primaryTeal,
                        fontSize: 24, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Receipt button
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            showReceiptSheet(context, data);
          },
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('View & Print Receipt',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        )),
      ]),
    );
  }

  Widget _sectionLabel(String title, IconData icon, Color color) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 14),
    ),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
  ]);

  Widget _itemRow(BuildContext context, Map<String, dynamic> item, String saleStatus) {
    final name = item['name'] as String? ?? item['itemName'] as String? ?? 'Unknown';
    final qty = item['quantity'] ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (price * (qty as int));
    final returned = item['returned'] == true || (item['returnedQuantity'] ?? 0) > 0;
    final itemId = item['id'] ?? item['itemId'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: returned
                    ? EnhancedTheme.errorRed.withValues(alpha: 0.2)
                    : context.borderColor,
              ),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (returned ? EnhancedTheme.errorRed : EnhancedTheme.accentCyan).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  returned ? Icons.undo_rounded : Icons.medication_rounded,
                  color: returned ? EnhancedTheme.errorRed : EnhancedTheme.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Qty: $qty  ·  ${_fmtNaira(price)} each',
                    style: TextStyle(color: context.hintColor, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmtNaira(subtotal),
                    style: const TextStyle(color: EnhancedTheme.primaryTeal,
                        fontSize: 13, fontWeight: FontWeight.w700)),
                if (!returned && saleStatus != 'returned') ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showReturnDialog(
                        itemId is int ? itemId : int.tryParse('$itemId') ?? 0,
                        name,
                        qty is int ? qty : int.tryParse('$qty') ?? 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Return',
                          style: TextStyle(color: EnhancedTheme.warningAmber,
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _paymentsSummary(BuildContext context, Map<String, dynamic> payments) {
    final entries = <MapEntry<String, double>>[];
    for (final e in payments.entries) {
      final val = (e.value as num?)?.toDouble() ?? 0;
      if (val > 0) entries.add(MapEntry(e.key, val));
    }
    if (entries.isEmpty) {
      return Text('No payment breakdown', style: TextStyle(color: context.subLabelColor, fontSize: 12));
    }

    final methodColors = {
      'cash': EnhancedTheme.successGreen,
      'pos': EnhancedTheme.accentPurple,
      'card': EnhancedTheme.accentPurple,
      'transfer': EnhancedTheme.infoBlue,
      'bank_transfer': EnhancedTheme.infoBlue,
      'wallet': EnhancedTheme.warningAmber,
    };
    final methodIcons = {
      'cash': Icons.payments_rounded,
      'pos': Icons.credit_card_rounded,
      'card': Icons.credit_card_rounded,
      'transfer': Icons.account_balance_rounded,
      'bank_transfer': Icons.account_balance_rounded,
      'wallet': Icons.account_balance_wallet_rounded,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: entries.asMap().entries.map((entry) {
            final e = entry.value;
            final color = methodColors[e.key.toLowerCase()] ?? EnhancedTheme.primaryTeal;
            final icon = methodIcons[e.key.toLowerCase()] ?? Icons.payments_rounded;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.key.toUpperCase(),
                      style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600))),
                  Text(_fmtNaira(e.value),
                      style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
              if (entry.key < entries.length - 1) Divider(height: 1, color: context.dividerColor),
            ]);
          }).toList()),
        ),
      ),
    );
  }

  Widget _returnRow(BuildContext context, Map<String, dynamic> ret) {
    final itemName = ret['itemName'] as String? ?? ret['item_name'] as String? ?? 'Unknown';
    final qty = ret['quantity'] ?? 0;
    final refundMethod = ret['refundMethod'] as String? ?? ret['refund_method'] as String? ?? '';
    final reason = ret['reason'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.undo_rounded, color: EnhancedTheme.errorRed, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(itemName, style: TextStyle(color: context.labelColor, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('Qty: $qty  ·  ${refundMethod.toUpperCase()}${reason.isNotEmpty ? '  ·  $reason' : ''}',
                style: TextStyle(color: context.hintColor, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }

  // ── Return Dialog ──────────────────────────────────────────────────────────

  void _showReturnDialog(int saleItemId, String itemName, int maxQty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReturnDialog(
        saleId: widget.saleId,
        saleItemId: saleItemId,
        itemName: itemName,
        maxQty: maxQty,
      ),
    );
  }

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _formatDateTime(String raw) {
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
//  RETURN DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _ReturnDialog extends ConsumerStatefulWidget {
  final int saleId;
  final int saleItemId;
  final String itemName;
  final int maxQty;

  const _ReturnDialog({
    required this.saleId,
    required this.saleItemId,
    required this.itemName,
    required this.maxQty,
  });

  @override
  ConsumerState<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends ConsumerState<_ReturnDialog> {
  int _quantity = 1;
  String _refundMethod = 'wallet';
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReturn() async {
    setState(() => _submitting = true);
    try {
      await ref.read(posApiProvider).returnItem(
        widget.saleId,
        saleItemId: widget.saleItemId,
        quantity: _quantity,
        refundMethod: _refundMethod,
        reason: _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(saleDetailProvider(widget.saleId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text('Item returned successfully', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ]),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Return failed: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ]),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
            width: 44, height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 20),

          // Warning header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EnhancedTheme.warningAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.undo_rounded, color: EnhancedTheme.warningAmber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Return Item', style: TextStyle(color: context.labelColor,
                    fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(widget.itemName, style: TextStyle(color: context.subLabelColor, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // Quantity selector
          Text('Return Quantity',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: [
              _qtyBtn(Icons.remove_rounded, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Expanded(child: Center(child: Text('$_quantity',
                  style: TextStyle(color: context.labelColor, fontSize: 28, fontWeight: FontWeight.w900)))),
              _qtyBtn(Icons.add_rounded, () {
                if (_quantity < widget.maxQty) setState(() => _quantity++);
              }),
            ]),
          ),
          Center(child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Maximum: ${widget.maxQty} units',
                style: TextStyle(color: context.hintColor, fontSize: 12)),
          )),
          const SizedBox(height: 24),

          // Refund method
          Text('Refund Method',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _refundChip('wallet', 'Wallet', Icons.account_balance_wallet_rounded),
            const SizedBox(width: 10),
            _refundChip('cash', 'Cash', Icons.payments_rounded),
          ]),
          const SizedBox(height: 24),

          // Reason
          Text('Reason (optional)',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonCtrl,
            style: TextStyle(color: context.labelColor, fontSize: 14),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Damaged packaging, wrong item...',
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
          const SizedBox(height: 28),

          // Submit
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _submitting ? null : _submitReturn,
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.warningAmber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Process Return',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: EnhancedTheme.primaryTeal, size: 22),
    ),
  );

  Widget _refundChip(String value, String label, IconData icon) {
    final active = _refundMethod == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _refundMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active ? EnhancedTheme.warningAmber.withValues(alpha: 0.15) : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? EnhancedTheme.warningAmber : context.borderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? EnhancedTheme.warningAmber : context.subLabelColor, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: active ? EnhancedTheme.warningAmber : context.subLabelColor,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ));
  }
}
