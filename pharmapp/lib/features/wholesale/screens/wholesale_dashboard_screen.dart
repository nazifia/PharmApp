import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final wholesaleDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchWholesaleDashboard();
});

final wholesaleLowStockProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchWholesaleLowStock();
});

final wholesaleExpiryAlertProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchWholesaleExpiryAlert();
});

final wholesaleInventoryValueProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchWholesaleInventoryValue();
});

final pendingTransfersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchTransfers(status: 'pending');
});

// ── Screen ───────────────────────────────────────────────────────────────────

class WholesaleDashboardScreen extends ConsumerStatefulWidget {
  const WholesaleDashboardScreen({super.key});

  @override
  ConsumerState<WholesaleDashboardScreen> createState() => _WholesaleDashboardScreenState();
}

class _WholesaleDashboardScreenState extends ConsumerState<WholesaleDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(wholesaleDashboardProvider);
    ref.invalidate(wholesaleLowStockProvider);
    ref.invalidate(wholesaleExpiryAlertProvider);
    ref.invalidate(wholesaleInventoryValueProvider);
    ref.invalidate(pendingTransfersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final dashboardAsync = ref.watch(wholesaleDashboardProvider);
    final lowStockAsync = ref.watch(wholesaleLowStockProvider);
    final expiryAsync = ref.watch(wholesaleExpiryAlertProvider);
    final inventoryAsync = ref.watch(wholesaleInventoryValueProvider);
    final transfersAsync = ref.watch(pendingTransfersProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context, user?.role),
          Expanded(child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _statsCards(dashboardAsync),
                const SizedBox(height: 20),
                _quickAccess(context),
                const SizedBox(height: 20),
                _topProducts(dashboardAsync),
                const SizedBox(height: 20),
                _lowStockAlerts(lowStockAsync),
                const SizedBox(height: 20),
                _expiryAlerts(expiryAsync),
                const SizedBox(height: 20),
                _pendingTransfers(transfersAsync),
                const SizedBox(height: 20),
                _inventoryValue(inventoryAsync),
                const SizedBox(height: 32),
              ]),
            ),
          )),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, String? role) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.menu_rounded),
        color: context.iconOnBg,
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Wholesale Dashboard',
            style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('Bulk order management',
            style: TextStyle(color: context.hintColor, fontSize: 11)),
      ])),
      CircleAvatar(
        radius: 18,
        backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
        child: const Icon(Icons.store_rounded, size: 18, color: EnhancedTheme.accentCyan),
      ),
    ]),
  );

  // ── Stats Cards ────────────────────────────────────────────────────────────

  int _crossAxisCount(double width) {
    if (width >= 900) return 5;
    if (width >= 600) return 3;
    return 2;
  }

  Widget _statsCards(AsyncValue<Map<String, dynamic>> async) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = _crossAxisCount(constraints.maxWidth);
      final isWide = cols >= 4;
      return async.when(
        loading: () => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10,
            childAspectRatio: isWide ? 1.8 : 1.5,
          ),
          itemCount: 5,
          itemBuilder: (_, __) => EnhancedTheme.loadingShimmer(height: 80, radius: 14),
        ),
        error: (e, _) => _errorCard('Failed to load dashboard stats'),
        data: (data) {
          final revenue = (data['todayRevenue'] as num?)?.toDouble() ?? 0;
          final salesCount = data['salesToday'] ?? 0;
          final unitsSold = data['unitsSold'] ?? 0;
          final customers = data['wholesaleCustomers'] ?? 0;
          final debt = (data['outstandingDebt'] as num?)?.toDouble() ?? 0;

          final stats = [
            {'label': "Today's Revenue", 'value': _fmtNaira(revenue), 'icon': Icons.trending_up_rounded, 'color': EnhancedTheme.successGreen},
            {'label': 'Sales Today', 'value': '$salesCount', 'icon': Icons.receipt_long_rounded, 'color': EnhancedTheme.primaryTeal},
            {'label': 'Units Sold', 'value': '$unitsSold', 'icon': Icons.shopping_cart_rounded, 'color': EnhancedTheme.accentCyan},
            {'label': 'WS Customers', 'value': '$customers', 'icon': Icons.people_rounded, 'color': EnhancedTheme.accentPurple},
            {'label': 'Outstanding Debt', 'value': _fmtNaira(debt), 'icon': Icons.money_off_rounded, 'color': EnhancedTheme.warningAmber},
          ];

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: isWide ? 1.8 : 1.5,
            ),
            itemCount: stats.length,
            itemBuilder: (_, i) {
              final s = stats[i];
              final color = s['color'] as Color;
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.all(isWide ? 12 : 16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(s['icon'] as IconData, color: color, size: isWide ? 18 : 22),
                      const Spacer(),
                      Text(s['value'] as String,
                          style: TextStyle(color: color, fontSize: isWide ? 16 : 20, fontWeight: FontWeight.w800)),
                      Text(s['label'] as String,
                          style: TextStyle(color: context.subLabelColor, fontSize: isWide ? 10 : 11)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  // ── Quick Access ───────────────────────────────────────────────────────────

  Widget _quickAccess(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Access',
          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _quickGroup(context, 'Dispensing', [
          _quickItem(context, Icons.point_of_sale_rounded, 'Wholesale POS', EnhancedTheme.primaryTeal, () => context.push('/dashboard/wholesale-pos')),
          _quickItem(context, Icons.history_rounded, 'Sales History', EnhancedTheme.accentCyan, () => context.push('/dashboard/wholesale-sales')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: _quickGroup(context, 'Inventory', [
          _quickItem(context, Icons.warning_amber_rounded, 'Low Stock', EnhancedTheme.warningAmber, () => context.push('/dashboard/inventory')),
          _quickItem(context, Icons.hourglass_bottom_rounded, 'Expiry Alerts', EnhancedTheme.errorRed, () => context.push('/dashboard/inventory')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: _quickGroup(context, 'Transfers', [
          _quickItem(context, Icons.arrow_upward_rounded, 'Outgoing', EnhancedTheme.accentPurple, () => context.push('/dashboard/transfers')),
          _quickItem(context, Icons.arrow_downward_rounded, 'Incoming', EnhancedTheme.successGreen, () => context.push('/dashboard/transfers')),
        ])),
      ]),
    ]);
  }

  Widget _quickGroup(BuildContext context, String title, List<Widget> items) {
    return ClipRRect(
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
            Text(title, style: TextStyle(color: context.hintColor, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...items,
          ]),
        ),
      ),
    );
  }

  Widget _quickItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: TextStyle(color: context.labelColor, fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  // ── Top Products ───────────────────────────────────────────────────────────

  Widget _topProducts(AsyncValue<Map<String, dynamic>> async) {
    return async.when(
      loading: () => EnhancedTheme.loadingShimmer(height: 120, radius: 16),
      error: (e, _) => const SizedBox.shrink(),
      data: (data) {
        final products = (data['topProducts'] as List<dynamic>?) ?? [];
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top Products Today',
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
                child: Column(children: products.take(5).toList().asMap().entries.map((e) {
                  final p = e.value as Map<String, dynamic>;
                  final name = p['name'] as String? ?? 'Unknown';
                  final qty = p['quantity'] ?? p['qty'] ?? 0;
                  final revenue = (p['revenue'] as num?)?.toDouble() ?? 0;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('$qty units', style: TextStyle(color: context.hintColor, fontSize: 11)),
                        ])),
                        Text(_fmtNaira(revenue),
                            style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (e.key < products.length - 1 && e.key < 4) Divider(height: 1, color: context.dividerColor),
                  ]);
                }).toList()),
              ),
            ),
          ),
        ]);
      },
    );
  }

  // ── Low Stock Alerts ───────────────────────────────────────────────────────

  Widget _lowStockAlerts(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.warningAmber, size: 18),
            const SizedBox(width: 6),
            Text('Low Stock Alerts',
                style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...items.take(5).map((item) {
            final m = item as Map<String, dynamic>;
            final name = m['name'] as String? ?? m['itemName'] as String? ?? 'Unknown';
            final qty = m['quantity'] ?? m['stock'] ?? 0;
            final threshold = m['threshold'] ?? m['minStock'] ?? 10;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(name,
                          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('$qty / $threshold',
                          style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ]);
      },
    );
  }

  // ── Expiry Alerts ──────────────────────────────────────────────────────────

  Widget _expiryAlerts(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hourglass_bottom_rounded, color: EnhancedTheme.errorRed, size: 18),
            const SizedBox(width: 6),
            Text('Expiry Alerts',
                style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...items.take(5).map((item) {
            final m = item as Map<String, dynamic>;
            final name = m['name'] as String? ?? m['itemName'] as String? ?? 'Unknown';
            final expiry = m['expiryDate'] as String? ?? m['expiry_date'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(name,
                          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(expiry.isNotEmpty ? _fmtDate(expiry) : 'N/A',
                          style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ]);
      },
    );
  }

  // ── Pending Transfers ──────────────────────────────────────────────────────

  Widget _pendingTransfers(AsyncValue<List<dynamic>> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (transfers) {
        if (transfers.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.swap_horiz_rounded, color: EnhancedTheme.accentPurple, size: 18),
            const SizedBox(width: 6),
            Text('Pending Transfers',
                style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/dashboard/transfers'),
              child: Text('View All',
                  style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          ...transfers.take(3).map((item) {
            final m = item as Map<String, dynamic>;
            final id = m['id'] ?? 0;
            final name = m['itemName'] as String? ?? m['item_name'] as String? ?? 'Unknown';
            final requestedQty = m['requestedQty'] ?? m['requested_qty'] ?? 0;
            final direction = m['fromWholesale'] == true || m['from_wholesale'] == true ? 'Outgoing' : 'Incoming';
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
                      Icon(
                        direction == 'Outgoing' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: direction == 'Outgoing' ? EnhancedTheme.accentPurple : EnhancedTheme.successGreen,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('$requestedQty units · $direction',
                            style: TextStyle(color: context.hintColor, fontSize: 11)),
                      ])),
                      _transferAction(id is int ? id : int.tryParse('$id') ?? 0, 'approve'),
                      const SizedBox(width: 6),
                      _transferAction(id is int ? id : int.tryParse('$id') ?? 0, 'reject'),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ]);
      },
    );
  }

  Widget _transferAction(int id, String action) {
    final isApprove = action == 'approve';
    final color = isApprove ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
    return GestureDetector(
      onTap: () async {
        try {
          if (isApprove) {
            await ref.read(posApiProvider).approveTransfer(id, 0);
          } else {
            await ref.read(posApiProvider).rejectTransfer(id);
          }
          ref.invalidate(pendingTransfersProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isApprove ? 'Transfer approved' : 'Transfer rejected'),
              backgroundColor: color,
            ));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Action failed: $e'),
              backgroundColor: EnhancedTheme.errorRed,
            ));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(isApprove ? 'Approve' : 'Reject',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Inventory Value ────────────────────────────────────────────────────────

  Widget _inventoryValue(AsyncValue<Map<String, dynamic>> async) {
    return async.when(
      loading: () => EnhancedTheme.loadingShimmer(height: 100, radius: 16),
      error: (e, _) => const SizedBox.shrink(),
      data: (data) {
        final totalValue = (data['totalStockValue'] as num?)?.toDouble() ?? (data['total_stock_value'] as num?)?.toDouble() ?? 0;
        final purchaseValue = (data['totalPurchaseValue'] as num?)?.toDouble() ?? (data['total_purchase_value'] as num?)?.toDouble() ?? 0;
        final profit = (data['potentialProfit'] as num?)?.toDouble() ?? (data['potential_profit'] as num?)?.toDouble() ?? (totalValue - purchaseValue);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inventory Value',
              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _invRow('Total Stock Value', _fmtNaira(totalValue), EnhancedTheme.primaryTeal),
                  Divider(color: context.dividerColor, height: 20),
                  _invRow('Purchase Value', _fmtNaira(purchaseValue), EnhancedTheme.accentCyan),
                  Divider(color: context.dividerColor, height: 20),
                  _invRow('Potential Profit', _fmtNaira(profit), profit >= 0 ? EnhancedTheme.successGreen : EnhancedTheme.errorRed),
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _invRow(String label, String value, Color color) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13)),
      Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _errorCard(String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
      ),
      child: Text(msg, style: TextStyle(color: context.subLabelColor, fontSize: 13)),
    ),
  );
}