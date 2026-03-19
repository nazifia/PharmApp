import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';

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
        onPressed: () => context.pop(),
      ),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Wholesale Sales',
            style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('View wholesale receipts & transactions',
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
              color: active ? EnhancedTheme.primaryTeal : Colors.white.withValues(alpha: 0.07),
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
                Icon(Icons.receipt_long_rounded, color: Colors.white.withValues(alpha: 0.2), size: 56),
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
                if (dateStr.isNotEmpty)
                  Text(_formatDateTime(dateStr),
                      style: TextStyle(color: context.hintColor, fontSize: 10)),
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
