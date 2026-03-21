import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final wholesaleSalesListProvider = FutureProvider.autoDispose.family<List<dynamic>, WholesaleSalesParams>((ref, params) {
  return ref.watch(posApiProvider).fetchWholesaleSales(
    search: params.search,
    from: params.from,
    to: params.to,
  );
});

final wholesaleSalesByUserProvider = FutureProvider.autoDispose.family<List<dynamic>, WholesaleSalesByUserParams>((ref, params) {
  return ref.watch(posApiProvider).fetchWholesaleSalesByUser(
    from: params.from,
    to: params.to,
  );
});

final wholesaleSaleDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) {
  return ref.watch(posApiProvider).fetchWholesaleSaleDetail(id);
});

class WholesaleSalesParams {
  final String? search;
  final String? from;
  final String? to;
  const WholesaleSalesParams({this.search, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is WholesaleSalesParams &&
      other.search == search && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(search, from, to);
}

class WholesaleSalesByUserParams {
  final String? from;
  final String? to;
  const WholesaleSalesByUserParams({this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is WholesaleSalesByUserParams && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class WholesaleSalesScreen extends ConsumerStatefulWidget {
  const WholesaleSalesScreen({super.key});

  @override
  ConsumerState<WholesaleSalesScreen> createState() => _WholesaleSalesScreenState();
}

class _WholesaleSalesScreenState extends ConsumerState<WholesaleSalesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _dateFilter = 0; // 0=Today, 1=This Week, 2=This Month, 3=All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ({String? from, String? to}) get _dateRange {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 0:
        return (
          from: DateTime(now.year, now.month, now.day).toIso8601String().split('T').first,
          to: now.toIso8601String().split('T').first,
        );
      case 1:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return (
          from: DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String().split('T').first,
          to: now.toIso8601String().split('T').first,
        );
      case 2:
        return (
          from: DateTime(now.year, now.month, 1).toIso8601String().split('T').first,
          to: now.toIso8601String().split('T').first,
        );
      default:
        return (from: null, to: null);
    }
  }

  WholesaleSalesParams get _params => WholesaleSalesParams(
    search: _searchQuery.isEmpty ? null : _searchQuery,
    from: _dateRange.from,
    to: _dateRange.to,
  );

  WholesaleSalesByUserParams get _byUserParams => WholesaleSalesByUserParams(
    from: _dateRange.from,
    to: _dateRange.to,
  );

  Future<void> _refresh() async {
    ref.invalidate(wholesaleSalesListProvider(_params));
    ref.invalidate(wholesaleSalesByUserProvider(_byUserParams));
  }

  void _showSaleDetail(int saleId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WholesaleSaleDetailSheet(saleId: saleId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(wholesaleSalesListProvider(_params));
    final byUserAsync = ref.watch(wholesaleSalesByUserProvider(_byUserParams));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context),
          _searchBar(context),
          _dateFilterChips(),
          Expanded(child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _salesByUser(byUserAsync),
                const SizedBox(height: 16),
                _salesList(salesAsync),
              ],
            ),
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
        Text('Wholesale Sales',
            style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('View receipts & manage returns',
            style: TextStyle(color: context.subLabelColor, fontSize: 11)),
      ])),
    ]),
  );

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _searchBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );

  // ── Date Filter Chips ──────────────────────────────────────────────────────

  Widget _dateFilterChips() {
    const filters = ['Today', 'This Week', 'This Month', 'All'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(children: filters.asMap().entries.map((e) {
        final active = e.key == _dateFilter;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _dateFilter = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? EnhancedTheme.primaryTeal : context.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(e.value, textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? Colors.white : Colors.white54,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ));
      }).toList()),
    );
  }

  // ── Sales By User ──────────────────────────────────────────────────────────

  Widget _salesByUser(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sales by User',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(children: users.take(5).toList().asMap().entries.map((e) {
                  final u = e.value as Map<String, dynamic>;
                  final name = u['userName'] as String? ?? u['user_name'] as String? ?? u['name'] as String? ?? 'Unknown';
                  final itemsCount = u['itemsCount'] ?? u['items_count'] ?? u['totalItems'] ?? 0;
                  final total = (u['totalAmount'] as num?)?.toDouble() ?? (u['total_amount'] as num?)?.toDouble() ?? u['total'] as num? ?? 0;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('$itemsCount items', style: TextStyle(color: context.hintColor, fontSize: 11)),
                        ])),
                        Text(_fmtNaira(total.toDouble()),
                            style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (e.key < users.length - 1 && e.key < 4) Divider(height: 1, color: context.dividerColor),
                  ]);
                }).toList()),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ]);
      },
    );
  }

  // ── Sales List ─────────────────────────────────────────────────────────────

  Widget _salesList(AsyncValue<List<dynamic>> async) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('All Sales',
          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      async.when(
        loading: () => Column(children: List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EnhancedTheme.loadingShimmer(height: 90, radius: 16),
        ))),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          Text('$e', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _refresh,
            child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal)),
          ),
        ])),
        data: (sales) {
          if (sales.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Icon(Icons.receipt_long_rounded, color: context.hintColor, size: 56),
                const SizedBox(height: 12),
                Text('No sales found',
                    style: TextStyle(color: context.subLabelColor, fontSize: 14)),
              ]),
            ));
          }
          return Column(children: sales.map((s) => _saleCard(s as Map<String, dynamic>)).toList());
        },
      ),
    ]);
  }

  Widget _saleCard(Map<String, dynamic> sale) {
    final id = sale['id'] ?? 0;
    final receiptId = sale['receiptId'] as String? ?? sale['receipt_id'] as String? ?? '#$id';
    final customerName = sale['customerName'] as String? ?? sale['customer_name'] as String? ?? 'Walk-in';
    final totalAmount = (sale['totalAmount'] as num?)?.toDouble() ?? (sale['total_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = sale['paymentMethod'] as String? ?? sale['payment_method'] as String? ?? 'bank_transfer';
    final status = (sale['status'] as String? ?? 'completed').toLowerCase();
    final dateStr = sale['createdAt'] as String? ?? sale['created_at'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        break;
      case 'partial_return':
      case 'partially_returned':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial';
        break;
      case 'pending':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Pending';
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Completed';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showSaleDetail(id is int ? id : int.tryParse('$id') ?? 0),
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
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_rounded, color: EnhancedTheme.accentCyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(receiptId,
                      style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(customerName,
                      style: TextStyle(color: context.subLabelColor, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    _paymentBadge(paymentMethod),
                    const SizedBox(width: 6),
                    if (dateStr.isNotEmpty)
                      Text(_formatDateTime(dateStr),
                          style: TextStyle(color: context.hintColor, fontSize: 10)),
                  ]),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmtNaira(totalAmount),
                      style: const TextStyle(color: EnhancedTheme.primaryTeal,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 3),
        Text(method.toUpperCase(),
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
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
//  WHOLESALE SALE DETAIL BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _WholesaleSaleDetailSheet extends ConsumerStatefulWidget {
  final int saleId;
  const _WholesaleSaleDetailSheet({required this.saleId});

  @override
  ConsumerState<_WholesaleSaleDetailSheet> createState() => _WholesaleSaleDetailSheetState();
}

class _WholesaleSaleDetailSheetState extends ConsumerState<_WholesaleSaleDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(wholesaleSaleDetailProvider(widget.saleId));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
            const Icon(Icons.error_outline, color: EnhancedTheme.errorRed, size: 40),
            const SizedBox(height: 12),
            Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13),
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
    final paymentMethod = data['paymentMethod'] as String? ?? data['payment_method'] as String? ?? 'bank_transfer';
    final status = (data['status'] as String? ?? 'completed').toLowerCase();
    final dateStr = data['createdAt'] as String? ?? data['created_at'] as String? ?? '';
    final items    = (data['items']    as List<dynamic>?) ?? [];
    final payments = (data['payments'] as List<dynamic>?) ?? [];
    final returns  = (data['returns']  as List<dynamic>?) ?? [];

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        break;
      case 'partial_return':
      case 'partially_returned':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial Return';
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Completed';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: context.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(receiptId,
                style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(customerName,
                style: TextStyle(color: context.subLabelColor, fontSize: 14)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        if (dateStr.isNotEmpty)
          Text(_formatDateTime(dateStr),
              style: TextStyle(color: context.hintColor, fontSize: 12)),
        const SizedBox(height: 20),

        // Items
        Text('Items',
            style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text('No items data', style: TextStyle(color: context.subLabelColor, fontSize: 13))
        else
          ...items.map((item) => _itemRow(context, item as Map<String, dynamic>, status)),
        const SizedBox(height: 20),

        // Payments summary (split payments list)
        if (payments.isNotEmpty) ...[
          Text('Payment Breakdown',
              style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _paymentsList(context, payments),
          const SizedBox(height: 20),
        ],

        // Returns
        if (returns.isNotEmpty) ...[
          Text('Returns',
              style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...returns.map((r) => _returnRow(context, r as Map<String, dynamic>)),
          const SizedBox(height: 20),
        ],

        // Total
        Divider(color: context.dividerColor),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total',
              style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(_fmtNaira(totalAmount),
              style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.credit_card_rounded, color: context.subLabelColor, size: 14),
          const SizedBox(width: 6),
          Text(paymentMethod.toUpperCase(),
              style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

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
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Qty: $qty  \u00B7  ${_fmtNaira(price)} each',
                    style: TextStyle(color: context.hintColor, fontSize: 11)),
              ])),
              Text(_fmtNaira(subtotal),
                  style: const TextStyle(color: EnhancedTheme.primaryTeal,
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (!returned && saleStatus != 'returned')
                GestureDetector(
                  onTap: () => _showReturnDialog(itemId is int ? itemId : int.tryParse('$itemId') ?? 0, name, qty is int ? qty : int.tryParse('$qty') ?? 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.3)),
                    ),
                    child: const Text('Return',
                        style: TextStyle(color: EnhancedTheme.warningAmber,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _paymentsList(BuildContext context, List<dynamic> payments) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: payments.map((p) {
            final pm = p as Map<String, dynamic>;
            final method = (pm['paymentMethod'] as String? ?? pm['payment_method'] as String? ?? '').toUpperCase();
            final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(method, style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                Text(_fmtNaira(amount),
                    style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            );
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.undo_rounded, color: EnhancedTheme.errorRed, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(itemName, style: TextStyle(color: context.labelColor, fontSize: 12, fontWeight: FontWeight.w500)),
          Text('Qty: $qty  \u00B7  ${refundMethod.toUpperCase()}${reason.isNotEmpty ? '  \u00B7  $reason' : ''}',
              style: TextStyle(color: context.hintColor, fontSize: 10)),
        ])),
      ]),
    );
  }

  // ── Return Dialog ──────────────────────────────────────────────────────────

  void _showReturnDialog(int saleItemId, String itemName, int maxQty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WholesaleReturnDialog(
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
//  WHOLESALE RETURN DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _WholesaleReturnDialog extends ConsumerStatefulWidget {
  final int saleId;
  final int saleItemId;
  final String itemName;
  final int maxQty;

  const _WholesaleReturnDialog({
    required this.saleId,
    required this.saleItemId,
    required this.itemName,
    required this.maxQty,
  });

  @override
  ConsumerState<_WholesaleReturnDialog> createState() => _WholesaleReturnDialogState();
}

class _WholesaleReturnDialogState extends ConsumerState<_WholesaleReturnDialog> {
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
      await ref.read(posApiProvider).returnWholesaleItem(
        widget.saleId,
        saleItemId: widget.saleItemId,
        quantity: _quantity,
        refundMethod: _refundMethod,
        reason: _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(wholesaleSaleDetailProvider(widget.saleId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Item returned successfully'),
        backgroundColor: EnhancedTheme.successGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Return failed: $e'),
        backgroundColor: EnhancedTheme.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 20),

          // Title
          Text('Return Item',
              style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(widget.itemName,
              style: TextStyle(color: context.subLabelColor, fontSize: 14)),
          const SizedBox(height: 24),

          // Quantity selector
          Text('Quantity',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _qtyBtn(Icons.remove_rounded, () {
              if (_quantity > 1) setState(() => _quantity--);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('$_quantity',
                  style: TextStyle(color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            _qtyBtn(Icons.add_rounded, () {
              if (_quantity < widget.maxQty) setState(() => _quantity++);
            }),
            const Spacer(),
            Text('of ${widget.maxQty}',
                style: TextStyle(color: context.hintColor, fontSize: 13)),
          ]),
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
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Icon(icon, color: context.labelColor, size: 20),
    ),
  );

  Widget _refundChip(String value, String label, IconData icon) {
    final active = _refundMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _refundMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? EnhancedTheme.warningAmber.withValues(alpha: 0.15) : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? EnhancedTheme.warningAmber : context.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? EnhancedTheme.warningAmber : context.subLabelColor, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: active ? EnhancedTheme.warningAmber : context.subLabelColor,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
