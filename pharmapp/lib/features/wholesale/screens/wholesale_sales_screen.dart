import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final wholesaleSalesListProvider = FutureProvider.autoDispose.family<List<dynamic>, WholesaleSalesParams>((ref, params) {
  final branch   = ref.watch(activeBranchProvider);
  final branchId = (branch != null && branch.id > 0) ? branch.id : null;
  return ref.watch(posApiProvider).fetchWholesaleSales(
    search: params.search,
    from: params.from,
    to: params.to,
    branchId: branchId,
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
    final salesAsync  = ref.watch(wholesaleSalesListProvider(_params));
    final byUserAsync = ref.watch(wholesaleSalesByUserProvider(_byUserParams));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative glow
        Positioned(top: -40, right: -60,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.14),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(child: Column(children: [
          _buildHeader(context),
          _buildSearchBar(context),
          _buildDateFilterChips(),
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
                const SizedBox(height: 24),
              ],
            ),
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Wholesale Sales',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w700)),
        Text('View receipts & manage returns',
            style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
            EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.primaryTeal, size: 14),
          const SizedBox(width: 5),
          Text('B2B', style: GoogleFonts.inter(
              color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]),
  ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.15);

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: GoogleFonts.inter(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by receipt ID or customer name...',
            hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 13),
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
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ),
  ).animate().fadeIn(delay: 80.ms).slideY(begin: -0.1);

  // ── Date Filter Chips ──────────────────────────────────────────────────────

  Widget _buildDateFilterChips() {
    const filters = ['Today', 'This Week', 'This Month', 'All'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: filters.asMap().entries.map((e) {
              final active = e.key == _dateFilter;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _dateFilter = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: active ? const LinearGradient(
                      colors: [EnhancedTheme.primaryTeal, Color(0xFF0B8276)],
                    ) : null,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active ? [
                      BoxShadow(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                        blurRadius: 8, offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Text(e.value, textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: active ? Colors.black : context.subLabelColor,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ));
            }).toList()),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 140.ms).slideY(begin: -0.1);
  }

  // ── Sales By User ──────────────────────────────────────────────────────────

  Widget _salesByUser(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [EnhancedTheme.accentCyan, EnhancedTheme.primaryTeal],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Sales by Rep',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(children: users.take(5).toList().asMap().entries.map((e) {
                  final u = e.value as Map<String, dynamic>;
                  final name = u['userName'] as String? ?? u['user_name'] as String? ?? u['name'] as String? ?? u['user'] as String? ?? 'Unknown';
                  final itemsCount = u['itemsCount'] ?? u['items_count'] ?? u['totalItems'] ?? u['total_items'] ?? 0;
                  final total = (u['totalAmount'] as num?)?.toDouble() ?? (u['total_amount'] as num?)?.toDouble() ?? (u['total'] as num?)?.toDouble() ?? 0.0;

                  final avatarColors = [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple,
                                        EnhancedTheme.primaryTeal, EnhancedTheme.successGreen, EnhancedTheme.warningAmber];
                  final avatarColor = avatarColors[e.key % avatarColors.length];
                  final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [avatarColor.withValues(alpha: 0.3), avatarColor.withValues(alpha: 0.12)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: avatarColor.withValues(alpha: 0.3)),
                          ),
                          child: Center(child: Text(initials.isEmpty ? '?' : initials,
                              style: GoogleFonts.outfit(color: avatarColor, fontSize: 13, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name,
                              style: GoogleFonts.inter(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('$itemsCount items sold',
                              style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
                        ])),
                        Text(_fmtNaira(total),
                            style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (e.key < users.length - 1 && e.key < 4)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent, context.dividerColor, Colors.transparent,
                          ]),
                        ),
                      ),
                  ]);
                }).toList()),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
      },
    );
  }

  // ── Sales List ─────────────────────────────────────────────────────────────

  Widget _salesList(AsyncValue<List<dynamic>> async) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentPurple],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text('All Sales',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
      async.when(
        loading: () => Column(children: List.generate(4, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EnhancedTheme.loadingShimmer(height: 95, radius: 16),
        ))),
        error: (e, _) => Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  color: EnhancedTheme.errorRed.withValues(alpha: 0.6), size: 32),
            ),
            const SizedBox(height: 14),
            Text('Could not load sales',
                style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('$e',
                style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: EnhancedTheme.primaryTeal, size: 16),
              label: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal)),
            ),
          ]),
        )),
        data: (sales) {
          if (sales.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Icon(Icons.receipt_long_rounded,
                      color: context.hintColor.withValues(alpha: 0.5), size: 36),
                ),
                const SizedBox(height: 14),
                Text('No sales found',
                    style: GoogleFonts.outfit(
                        color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Try adjusting the date filter',
                    style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12)),
              ]),
            ));
          }
          return Column(children: sales.asMap().entries.map((e) =>
              _saleCard(e.value as Map<String, dynamic>)
                  .animate().fadeIn(delay: (e.key * 50).ms).slideY(begin: 0.08)
          ).toList());
        },
      ),
    ]);
  }

  Widget _saleCard(Map<String, dynamic> sale) {
    final id = sale['id'] ?? 0;
    final receiptId     = sale['receiptId'] as String? ?? sale['receipt_id'] as String? ?? '#$id';
    final customerName  = sale['customerName'] as String? ?? sale['customer_name'] as String? ?? 'Walk-in';
    final totalAmount   = (sale['totalAmount'] as num?)?.toDouble() ?? (sale['total_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = sale['paymentMethod'] as String? ?? sale['payment_method'] as String? ?? 'bank_transfer';
    final status        = (sale['status'] as String? ?? 'completed').toLowerCase();
    final dateStr       = sale['createdAt'] as String? ?? sale['created_at'] as String? ?? sale['created'] as String? ?? '';
    final dispenserName = sale['dispenserName'] as String? ?? sale['dispenser_name'] as String? ?? '';
    final saleItems     = sale['items'] as List<dynamic>?;
    final itemsCount    = saleItems?.length ?? 0;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        statusIcon  = Icons.undo_rounded;
        break;
      case 'partial_return':
      case 'partially_returned':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial';
        statusIcon  = Icons.compare_arrows_rounded;
        break;
      case 'pending':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Pending';
        statusIcon  = Icons.hourglass_bottom_rounded;
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Completed';
        statusIcon  = Icons.check_circle_rounded;
    }

    final initials = customerName.split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showSaleDetail(id is int ? id : int.tryParse('$id') ?? 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: IntrinsicHeight(
              child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Status color strip
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [statusColor, statusColor.withValues(alpha: 0.5)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    // Customer avatar
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [
                            EnhancedTheme.accentCyan.withValues(alpha: 0.25),
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
                      ),
                      child: Center(child: initials.isEmpty
                          ? const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 20)
                          : Text(initials,
                              style: GoogleFonts.outfit(color: EnhancedTheme.accentCyan,
                                  fontSize: 14, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(receiptId,
                          style: GoogleFonts.outfit(color: context.labelColor,
                              fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(customerName,
                          style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(children: [
                        _paymentBadge(paymentMethod),
                        const SizedBox(width: 6),
                        if (dateStr.isNotEmpty)
                          Text(_formatDateTime(dateStr),
                              style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
                      ]),
                      if (dispenserName.isNotEmpty || itemsCount > 0) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          if (dispenserName.isNotEmpty) ...[
                            Icon(Icons.person_rounded, color: context.hintColor, size: 10),
                            const SizedBox(width: 3),
                            Text(dispenserName,
                                style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
                          ],
                          if (dispenserName.isNotEmpty && itemsCount > 0)
                            Text(' \u00B7 ', style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
                          if (itemsCount > 0) ...[
                            Icon(Icons.shopping_cart_rounded, color: context.hintColor, size: 10),
                            const SizedBox(width: 3),
                            Text('$itemsCount item${itemsCount > 1 ? "s" : ""}',
                                style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
                          ],
                        ]),
                      ],
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_fmtNaira(totalAmount),
                          style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                              fontSize: 15, fontWeight: FontWeight.w700)),
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
                              style: GoogleFonts.inter(color: statusColor,
                                  fontSize: 10, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ]),
                )),
              ]),
            ),
            ), // IntrinsicHeight
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
        icon  = Icons.credit_card_rounded;
        break;
      case 'wallet':
        color = EnhancedTheme.warningAmber;
        icon  = Icons.account_balance_wallet_rounded;
        break;
      case 'bank_transfer':
      case 'transfer':
        color = EnhancedTheme.infoBlue;
        icon  = Icons.account_balance_rounded;
        break;
      default:
        color = EnhancedTheme.accentCyan;
        icon  = Icons.payments_rounded;
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
            style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, $hour12:$m $ampm';
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
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: EnhancedTheme.errorRed, size: 28),
            ),
            const SizedBox(height: 12),
            Text('$e', style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13),
                textAlign: TextAlign.center),
          ])),
        ),
        data: (data) => _buildDetail(context, data),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Map<String, dynamic> data) {
    final receiptId     = data['receiptId'] as String? ?? data['receipt_id'] as String? ?? '#${widget.saleId}';
    final customerName  = data['customerName'] as String? ?? data['customer_name'] as String? ?? 'Walk-in';
    final totalAmount   = (data['totalAmount'] as num?)?.toDouble() ?? (data['total_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = data['paymentMethod'] as String? ?? data['payment_method'] as String? ?? 'bank_transfer';
    final status        = (data['status'] as String? ?? 'completed').toLowerCase();
    final dateStr       = data['createdAt'] as String? ?? data['created_at'] as String? ?? '';
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

    final initials = customerName.split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

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

        // Header card
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  EnhancedTheme.accentCyan.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      EnhancedTheme.accentCyan.withValues(alpha: 0.3),
                      EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: initials.isEmpty
                    ? const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 22)
                    : Text(initials, style: GoogleFonts.outfit(
                        color: EnhancedTheme.accentCyan, fontSize: 16, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(receiptId,
                    style: GoogleFonts.outfit(color: context.labelColor,
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(customerName,
                    style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13)),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_formatDateTime(dateStr),
                      style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
                ],
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmtNaira(totalAmount),
                    style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel,
                      style: GoogleFonts.inter(color: statusColor,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Items
        _sectionLabel(context, 'Items', Icons.shopping_bag_rounded, EnhancedTheme.primaryTeal),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text('No items data', style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13))
        else
          ...items.map((item) => _itemRow(context, item as Map<String, dynamic>, status)),
        const SizedBox(height: 20),

        // Payments summary
        if (payments.isNotEmpty) ...[
          _sectionLabel(context, 'Payment Breakdown',
              Icons.account_balance_wallet_rounded, EnhancedTheme.accentCyan),
          const SizedBox(height: 10),
          _paymentsList(context, payments),
          const SizedBox(height: 20),
        ],

        // Returns
        if (returns.isNotEmpty) ...[
          _sectionLabel(context, 'Returns', Icons.undo_rounded, EnhancedTheme.errorRed),
          const SizedBox(height: 10),
          ...returns.map((r) => _returnRow(context, r as Map<String, dynamic>)),
          const SizedBox(height: 20),
        ],

        // Total footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                EnhancedTheme.accentCyan.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Amount',
                  style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.credit_card_rounded, color: context.hintColor, size: 14),
                const SizedBox(width: 6),
                Text(paymentMethod.toUpperCase(),
                    style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ]),
            Text(_fmtNaira(totalAmount),
                style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                    fontSize: 24, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(BuildContext context, String label, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _itemRow(BuildContext context, Map<String, dynamic> item, String saleStatus) {
    final name     = item['name'] as String? ?? item['itemName'] as String? ?? 'Unknown';
    final qty      = item['quantity'] ?? 0;
    final price    = (item['price'] as num?)?.toDouble() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (price * (qty as int));
    final returned = item['returned'] == true || (item['returnedQuantity'] ?? 0) > 0;
    final itemId   = item['id'] ?? item['itemId'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medication_rounded,
                    color: EnhancedTheme.primaryTeal, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.inter(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Qty: $qty  \u00B7  ${_fmtNaira(price)} each',
                    style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
              ])),
              Text(_fmtNaira(subtotal),
                  style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (!returned && saleStatus != 'returned')
                GestureDetector(
                  onTap: () => _showReturnDialog(
                    itemId is int ? itemId : int.tryParse('$itemId') ?? 0,
                    name,
                    qty is int ? qty : int.tryParse('$qty') ?? 1,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.3)),
                    ),
                    child: Text('Return',
                        style: GoogleFonts.inter(color: EnhancedTheme.warningAmber,
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
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: payments.map((p) {
            final pm     = p as Map<String, dynamic>;
            final method = (pm['paymentMethod'] as String? ?? pm['payment_method'] as String? ?? '').toUpperCase();
            final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(method,
                    style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(_fmtNaira(amount),
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            );
          }).toList()),
        ),
      ),
    );
  }

  Widget _returnRow(BuildContext context, Map<String, dynamic> ret) {
    final itemName    = ret['itemName'] as String? ?? ret['item_name'] as String? ?? 'Unknown';
    final qty         = ret['quantity'] ?? 0;
    final refundMethod = ret['refundMethod'] as String? ?? ret['refund_method'] as String? ?? '';
    final reason      = ret['reason'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.undo_rounded, color: EnhancedTheme.errorRed, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(itemName,
                style: GoogleFonts.inter(color: context.labelColor, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('Qty: $qty  \u00B7  ${refundMethod.toUpperCase()}${reason.isNotEmpty ? '  \u00B7  $reason' : ''}',
                style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
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
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
  double _quantity = 1.0;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Item returned successfully',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600))),
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
          const Icon(Icons.error_outline_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Return failed: $e',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
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
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  EnhancedTheme.warningAmber.withValues(alpha: 0.25),
                  EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.undo_rounded, color: EnhancedTheme.warningAmber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Return Item',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(widget.itemName,
                  style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 24),

          // Quantity selector
          Text('Quantity',
              style: GoogleFonts.inter(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(children: [
                _qtyBtn(Icons.remove_rounded, () {
                  if (_quantity > 0.5) setState(() => _quantity = (_quantity - 0.5).clamp(0.5, widget.maxQty.toDouble()));
                }),
                Expanded(child: Center(child: Text(_quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(1),
                    style: GoogleFonts.outfit(color: context.labelColor,
                        fontSize: 24, fontWeight: FontWeight.w800)))),
                _qtyBtn(Icons.add_rounded, () {
                  if (_quantity < widget.maxQty) setState(() => _quantity = (_quantity + 0.5).clamp(0.5, widget.maxQty.toDouble()));
                }),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text('Maximum: ${widget.maxQty}',
              style: GoogleFonts.inter(color: context.hintColor, fontSize: 12)),
          const SizedBox(height: 24),

          // Refund method
          Text('Refund Method',
              style: GoogleFonts.inter(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            _refundChip('wallet', 'Wallet', Icons.account_balance_wallet_rounded),
            const SizedBox(width: 10),
            _refundChip('cash', 'Cash', Icons.payments_rounded),
          ]),
          const SizedBox(height: 24),

          // Reason
          Text('Reason (optional)',
              style: GoogleFonts.inter(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonCtrl,
            style: GoogleFonts.inter(color: context.labelColor, fontSize: 14),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Damaged packaging, wrong item...',
              hintStyle: GoogleFonts.inter(color: context.hintColor, fontSize: 13),
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
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text('Process Return',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
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
        gradient: LinearGradient(colors: [
          EnhancedTheme.warningAmber.withValues(alpha: 0.15),
          EnhancedTheme.warningAmber.withValues(alpha: 0.06),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: EnhancedTheme.warningAmber, size: 20),
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
          gradient: active ? LinearGradient(colors: [
            EnhancedTheme.warningAmber.withValues(alpha: 0.2),
            EnhancedTheme.warningAmber.withValues(alpha: 0.08),
          ]) : null,
          color: active ? null : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? EnhancedTheme.warningAmber : context.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: active ? EnhancedTheme.warningAmber : context.subLabelColor, size: 18),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(
              color: active ? EnhancedTheme.warningAmber : context.subLabelColor,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
