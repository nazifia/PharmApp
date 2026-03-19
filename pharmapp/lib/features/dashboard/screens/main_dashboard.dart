import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/shared/widgets/dashboard_card.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

final _wholesaleDashProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    return await ref.read(posApiProvider).fetchWholesaleDashboard();
  } catch (_) {
    return <String, dynamic>{};
  }
});

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  bool _showWholesale = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _logout() {
    ref.read(authServiceProvider).logout();
    context.go('/login');
  }

  void _showMoreSheet() {
    final user = ref.read(currentUserProvider);
    final isAdmin     = user?.role == 'Admin' || user?.role == 'Manager';
    final isWholesale = (user?.role.contains('Wholesale') ?? false) || (user?.isWholesaleOperator ?? false) || isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreFeaturesSheet(
        isAdmin: isAdmin,
        isWholesale: isWholesale,
        onNavigate: (route) { Navigator.pop(context); context.go(route); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(child: _content()),
        ],
      ),
    );
  }

  Widget _content() => _homeContent();

  Widget _homeContent() {
    final user      = ref.watch(currentUserProvider);
    final role      = user?.role ?? '';
    final isWsUser  = role.contains('Wholesale') || (user?.isWholesaleOperator ?? false) || role == 'Admin' || role == 'Manager';
    final salesAsync = ref.watch(salesReportProvider('today'));
    final invAsync   = ref.watch(inventoryReportProvider);
    final custAsync  = ref.watch(customerReportProvider);
    final wide2      = MediaQuery.of(context).size.width > 600;
    final hour       = DateTime.now().hour;
    final greeting   = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final revenue   = salesAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final lowStock  = invAsync.whenOrNull(data: (d) => d.lowStockCount) ?? 0;
    final customers = custAsync.whenOrNull(data: (d) => d.total) ?? 0;
    final debt      = custAsync.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final loading   = salesAsync.isLoading || invAsync.isLoading || custAsync.isLoading;

    final retailStats = [
      DashboardCard(title: "Today's Revenue", value: loading ? '…' : _fmt(revenue), subtitle: 'Retail + Wholesale', icon: Icons.monetization_on,  color: const Color(0xFF10B981)),
      DashboardCard(title: 'Low Stock',        value: loading ? '…' : '$lowStock',   subtitle: 'Below threshold',     icon: Icons.warning_amber,    color: const Color(0xFFF59E0B)),
      DashboardCard(title: 'Customers',        value: loading ? '…' : '$customers',  subtitle: 'Total registered',    icon: Icons.people,           color: const Color(0xFF8B5CF6)),
      DashboardCard(title: 'Outstanding Debt', value: loading ? '…' : _fmt(debt),    subtitle: 'Total owed',          icon: Icons.money_off,        color: const Color(0xFFEF4444)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(children: [
            if (!wide2)
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Icon(Icons.menu_rounded, color: context.labelColor, size: 20),
                ),
              ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting!', style: TextStyle(color: context.subLabelColor, fontSize: 13)),
              const SizedBox(height: 2),
              Text(user?.phoneNumber ?? 'User',
                  style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(color: context.hintColor, fontSize: 12)),
            ])),
            _buildProfileMenu(role),
          ]),
          const SizedBox(height: 16),

          // ── Mode Toggle (wholesale users only) ────────────────────────────
          if (isWsUser) ...[
            _modeToggle(),
            const SizedBox(height: 16),
          ],

          // ══ RETAIL MODE ══════════════════════════════════════════════════
          if (!_showWholesale) ...[
            Row(children: [
              _quickBtn(Icons.add_shopping_cart, 'New Sale',   const Color(0xFF0D9488), () => context.go('/dashboard/pos')),
              const SizedBox(width: 10),
              _quickBtn(Icons.inventory_2,        'Inventory',  const Color(0xFF3B82F6), () => context.go('/dashboard/inventory')),
              const SizedBox(width: 10),
              _quickBtn(Icons.people,             'Customers',  const Color(0xFF8B5CF6), () => context.go('/dashboard/customers')),
              const SizedBox(width: 10),
              _quickBtn(Icons.more_horiz_rounded,  'More',       Colors.white38,          _showMoreSheet),
            ]),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: wide2 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide2 ? 1.35 : 1.3,
              children: retailStats,
            ),
            const SizedBox(height: 24),
            _quickAccessPanel(wide2),
            const SizedBox(height: 24),
            _sectionHeader('Sales Trend', () => context.go('/dashboard/reports/sales')),
            const SizedBox(height: 12),
            _salesTrendChart(salesAsync),
            const SizedBox(height: 24),
            _sectionHeader('Top Items Today', () => context.go('/dashboard/reports/sales')),
            const SizedBox(height: 12),
            salesAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              )),
              error: (e, _) => _glassRow(child: Text('Failed to load sales data',
                  style: TextStyle(color: context.hintColor, fontSize: 13))),
              data: (report) {
                if (report.topItems.isEmpty) {
                  return _glassRow(child: Text('No sales today',
                      style: TextStyle(color: context.hintColor, fontSize: 13)));
                }
                return Column(children: report.topItems.take(4).map((item) =>
                  _glassRow(child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.medication_rounded, color: Color(0xFF0D9488), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.name, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${item.qty} units sold', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    ])),
                    Text(_fmt(item.revenue),
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 14)),
                  ]))
                ).toList());
              },
            ),
            const SizedBox(height: 24),
            _sectionHeader('Low Stock Alerts', () => context.go('/dashboard/inventory')),
            const SizedBox(height: 12),
            invAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              )),
              error: (e, _) => _glassRow(child: Text('Failed to load inventory data',
                  style: TextStyle(color: context.hintColor, fontSize: 13))),
              data: (report) {
                if (report.lowStockItems.isEmpty) {
                  return _glassRow(child: Text('All items adequately stocked',
                      style: TextStyle(color: context.hintColor, fontSize: 13)));
                }
                return Column(children: report.lowStockItems.take(4).map((s) {
                  final pct = s.stock / (s.lowStockThreshold > 0 ? s.lowStockThreshold : 1);
                  final c   = pct < 0.3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
                  return _glassRow(child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: c.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.warning_amber_rounded, color: c, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Threshold: ${s.lowStockThreshold}', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${s.stock} units', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                  ]));
                }).toList());
              },
            ),
          ],

          // ══ WHOLESALE MODE ════════════════════════════════════════════════
          if (_showWholesale)
            _wholesaleBody(wide2),
        ],
      ),
    );
  }

  // ── Mode Toggle ────────────────────────────────────────────────────────────

  Widget _modeToggle() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            _toggleChip('Retail', !_showWholesale, EnhancedTheme.primaryTeal,
                () => setState(() => _showWholesale = false)),
            const SizedBox(width: 4),
            _toggleChip('Wholesale', _showWholesale, EnhancedTheme.accentCyan,
                () => setState(() => _showWholesale = true)),
          ]),
        ),
      ),
    );
  }

  Widget _toggleChip(String label, bool active, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: active ? color : context.hintColor,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
            )),
          ),
        ),
      ),
    );
  }

  // ── Wholesale Body ─────────────────────────────────────────────────────────

  Widget _wholesaleBody(bool wide2) {
    final wsAsync = ref.watch(_wholesaleDashProvider);
    return wsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: EnhancedTheme.accentCyan),
        ),
      ),
      error: (e, _) => _glassRow(
        child: Text('Failed to load wholesale data',
            style: TextStyle(color: context.hintColor, fontSize: 13))),
      data: (data) {
        final todayRevenue    = (data['todayRevenue']      as num?)?.toDouble() ?? 0.0;
        final totalSales      = (data['totalSales']        as num?)?.toInt()    ?? 0;
        final wsCustomers     = (data['wholesaleCustomers'] as num?)?.toInt()   ?? 0;
        final outstandingDebt = (data['outstandingDebt']   as num?)?.toDouble() ?? 0.0;
        final topProducts     = (data['topProducts']       as List?) ?? [];
        final lowStockItems   = (data['lowStockItems']     as List?) ?? [];
        final pendingTransfers = (data['pendingTransfers'] as List?) ?? [];

        final wsStats = [
          DashboardCard(title: "Today's Revenue", value: _fmt(todayRevenue), subtitle: 'Wholesale',       icon: Icons.monetization_on, color: const Color(0xFF10B981)),
          DashboardCard(title: 'Total Sales',     value: '$totalSales',      subtitle: 'All time',        icon: Icons.receipt_long,    color: EnhancedTheme.infoBlue),
          DashboardCard(title: 'WS Customers',    value: '$wsCustomers',     subtitle: 'Wholesale clients', icon: Icons.people,        color: const Color(0xFF8B5CF6)),
          DashboardCard(title: 'Outstanding Debt',value: _fmt(outstandingDebt), subtitle: 'Total owed',   icon: Icons.money_off,       color: const Color(0xFFEF4444)),
        ];

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Quick actions
          Row(children: [
            _quickBtn(Icons.point_of_sale_rounded, 'WS Sale',    EnhancedTheme.accentCyan,    () => context.go('/dashboard/wholesale-pos')),
            const SizedBox(width: 10),
            _quickBtn(Icons.receipt_long_rounded,  'WS Sales',   EnhancedTheme.successGreen,  () => context.go('/dashboard/wholesale-sales')),
            const SizedBox(width: 10),
            _quickBtn(Icons.swap_horiz_rounded,    'Transfers',  EnhancedTheme.warningAmber,  () => context.go('/dashboard/transfers')),
            const SizedBox(width: 10),
            _quickBtn(Icons.more_horiz_rounded,    'More',       Colors.white38,              _showMoreSheet),
          ]),
          const SizedBox(height: 24),

          // Stats grid
          GridView.count(
            crossAxisCount: wide2 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: wide2 ? 1.35 : 1.3,
            children: wsStats,
          ),
          const SizedBox(height: 24),

          // Wholesale quick access panel
          _wholesaleQuickAccess(wide2),
          const SizedBox(height: 24),

          // Top products
          _sectionHeader('Top Products Today', () => context.go('/dashboard/wholesale-sales')),
          const SizedBox(height: 12),
          if (topProducts.isEmpty)
            _glassRow(child: Text('No wholesale sales today',
                style: TextStyle(color: context.hintColor, fontSize: 13)))
          else
            Column(children: topProducts.take(4).map((p) {
              final name = p['name'] as String? ?? '';
              final qty  = (p['qty']     as num?)?.toInt()    ?? 0;
              final rev  = (p['revenue'] as num?)?.toDouble() ?? 0.0;
              return _glassRow(child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$qty units sold', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
                Text(_fmt(rev), style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 14)),
              ]));
            }).toList()),
          const SizedBox(height: 24),

          // Pending transfers
          _sectionHeader('Pending Transfers', () => context.go('/dashboard/transfers')),
          const SizedBox(height: 12),
          if (pendingTransfers.isEmpty)
            _glassRow(child: Text('No pending transfers',
                style: TextStyle(color: context.hintColor, fontSize: 13)))
          else
            Column(children: pendingTransfers.take(4).map((t) {
              final itemName = t['itemName'] as String? ?? '';
              final reqQty   = t['requestedQty'] ?? 0;
              final unit     = t['unit'] as String? ?? 'Pcs';
              return _glassRow(child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.swap_horiz_rounded, color: EnhancedTheme.warningAmber, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(itemName, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Requested: $reqQty $unit', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                  child: const Text('Pending',
                      style: TextStyle(color: EnhancedTheme.warningAmber, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]));
            }).toList()),
          const SizedBox(height: 24),

          // Low stock
          _sectionHeader('Low Stock Alerts', () => context.go('/dashboard/inventory')),
          const SizedBox(height: 12),
          if (lowStockItems.isEmpty)
            _glassRow(child: Text('All items adequately stocked',
                style: TextStyle(color: context.hintColor, fontSize: 13)))
          else
            Column(children: lowStockItems.take(4).map((s) {
              final name      = s['name']      as String? ?? '';
              final stock     = (s['stock']    as num?)?.toInt() ?? 0;
              final threshold = (s['threshold'] as num?)?.toInt() ?? 1;
              final pct = stock / (threshold > 0 ? threshold : 1);
              final c   = pct < 0.3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
              return _glassRow(child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.warning_amber_rounded, color: c, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Threshold: $threshold', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
                Text('$stock units', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
              ]));
            }).toList()),
        ]);
      },
    );
  }

  Widget _wholesaleQuickAccess(bool wide) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 18),
              const SizedBox(width: 8),
              Text('Wholesale Quick Access',
                  style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            wide
                ? Row(children: [
                    Expanded(child: _quickAccessCard(
                      'Wholesale Operations', 'Sales & Customers',
                      Icons.storefront_rounded, EnhancedTheme.accentCyan,
                      [(Icons.point_of_sale_rounded, 'WS POS', '/dashboard/wholesale-pos'),
                       (Icons.people_rounded, 'WS Customers', '/dashboard/customers')],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'Inventory & Transfers', 'Stock Management',
                      Icons.inventory_2_rounded, EnhancedTheme.warningAmber,
                      [(Icons.swap_horiz_rounded, 'Transfers', '/dashboard/transfers'),
                       (Icons.inventory_rounded, 'Inventory', '/dashboard/inventory')],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'Sales History', 'Records & Reports',
                      Icons.receipt_long_rounded, EnhancedTheme.successGreen,
                      [(Icons.history_rounded, 'WS Sales', '/dashboard/wholesale-sales'),
                       (Icons.analytics_rounded, 'WS Dashboard', '/wholesale-dashboard')],
                    )),
                  ])
                : Column(children: [
                    _quickAccessCard(
                      'Wholesale Operations', 'Sales & Customers',
                      Icons.storefront_rounded, EnhancedTheme.accentCyan,
                      [(Icons.point_of_sale_rounded, 'WS POS', '/dashboard/wholesale-pos'),
                       (Icons.people_rounded, 'WS Customers', '/dashboard/customers')],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'Inventory & Transfers', 'Stock Management',
                      Icons.inventory_2_rounded, EnhancedTheme.warningAmber,
                      [(Icons.swap_horiz_rounded, 'Transfers', '/dashboard/transfers'),
                       (Icons.inventory_rounded, 'Inventory', '/dashboard/inventory')],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'Sales History', 'Records & Reports',
                      Icons.receipt_long_rounded, EnhancedTheme.successGreen,
                      [(Icons.history_rounded, 'WS Sales', '/dashboard/wholesale-sales'),
                       (Icons.analytics_rounded, 'WS Dashboard', '/wholesale-dashboard')],
                    ),
                  ]),
          ]),
        ),
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: _PressableCard(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha:0.25)),
              ),
              child: Column(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Quick Access Panel (matching Pharm dashboard) ─────────────────────────

  Widget _quickAccessPanel(bool wide) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.dashboard_rounded, color: EnhancedTheme.primaryTeal, size: 18),
              const SizedBox(width: 8),
              Text('Quick Access',
                  style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            wide
                ? Row(children: [
                    Expanded(child: _quickAccessCard(
                      'Dispensing Management', 'Track & Analyze',
                      Icons.medication_rounded, EnhancedTheme.primaryTeal,
                      [(Icons.list_alt_rounded, 'Disp. Log', '/dashboard/dispensing-log'),
                       (Icons.point_of_sale_rounded, 'New Sale', '/dashboard/pos')],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'Store Operations', 'Retail & Wholesale',
                      Icons.storefront_rounded, EnhancedTheme.successGreen,
                      [(Icons.shopping_cart_rounded, 'Retail', '/dashboard/pos'),
                       (Icons.store_rounded, 'Wholesale', '/dashboard/wholesale-pos')],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'Reports & Analytics', 'Business Insights',
                      Icons.analytics_rounded, EnhancedTheme.accentCyan,
                      [(Icons.today_rounded, 'Daily Sales', '/dashboard/reports/sales'),
                       (Icons.calendar_month_rounded, 'Monthly', '/dashboard/reports/profit')],
                    )),
                  ])
                : Column(children: [
                    _quickAccessCard(
                      'Dispensing Management', 'Track & Analyze',
                      Icons.medication_rounded, EnhancedTheme.primaryTeal,
                      [(Icons.list_alt_rounded, 'Disp. Log', '/dashboard/dispensing-log'),
                       (Icons.point_of_sale_rounded, 'New Sale', '/dashboard/pos')],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'Store Operations', 'Retail & Wholesale',
                      Icons.storefront_rounded, EnhancedTheme.successGreen,
                      [(Icons.shopping_cart_rounded, 'Retail', '/dashboard/pos'),
                       (Icons.store_rounded, 'Wholesale', '/dashboard/wholesale-pos')],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'Reports & Analytics', 'Business Insights',
                      Icons.analytics_rounded, EnhancedTheme.accentCyan,
                      [(Icons.today_rounded, 'Daily Sales', '/dashboard/reports/sales'),
                       (Icons.calendar_month_rounded, 'Monthly', '/dashboard/reports/profit')],
                    ),
                  ]),
          ]),
        ),
      ),
    );
  }

  Widget _quickAccessCard(String title, String subtitle, IconData icon, Color color, List<(IconData, String, String)> actions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: context.labelColor, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text(subtitle, style: TextStyle(color: context.subLabelColor, fontSize: 9), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 4),
          Icon(icon, color: color.withValues(alpha: 0.4), size: 20),
        ]),
        const SizedBox(height: 10),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () => context.go(a.$3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(a.$1, color: color, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a.$2, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Sales Trend Chart ────────────────────────────────────────────────────

  Widget _salesTrendChart(AsyncValue salesAsync) {
    return salesAsync.when(
      loading: () => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor)),
            child: const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2)),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (report) {
        final topItems = report.topItems ?? [];
        if (topItems.isEmpty) return const SizedBox.shrink();

        final maxRevenue = topItems.fold<double>(0.0, (max, item) => item.revenue > max ? item.revenue : max);
        if (maxRevenue <= 0) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Today\'s Top Revenue Items',
                      style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_fmt(report.totalRevenue ?? 0),
                      style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 16),
                ...topItems.take(5).map((item) {
                  final pct = item.revenue / maxRevenue;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(item.name,
                          style: TextStyle(color: context.subLabelColor, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.7 + 0.3 * pct)),
                          minHeight: 12),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 70, child: Text(_fmt(item.revenue),
                          style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.right)),
                    ]),
                  );
                }),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      GestureDetector(
        onTap: onSeeAll,
        child: const Text('See all', style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _buildProfileMenu(String role) {
    final isAdmin     = role == 'Admin' || role == 'Manager';
    final isWholesale = role.contains('Wholesale') || isAdmin;
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E293B),
      onSelected: (val) {
        switch (val) {
          case 'settings':   context.go('/dashboard/settings');    break;
          case 'admin':      context.go('/admin-dashboard');       break;
          case 'wholesale':  context.go('/wholesale-dashboard');   break;
          case 'reports':    context.go('/dashboard/reports');     break;
          case 'logout':     _logout();                            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF0D9488).withValues(alpha:0.2),
            child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U',
                style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const Text('Logged in', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ])),
        const PopupMenuDivider(),
        _menuItem('settings',  Icons.settings_outlined,       'Settings'),
        _menuItem('reports',   Icons.bar_chart_outlined,      'Reports'),
        if (isAdmin)
          _menuItem('admin',     Icons.admin_panel_settings_outlined, 'Admin Dashboard'),
        if (isWholesale)
          _menuItem('wholesale', Icons.store_outlined,         'Wholesale Dashboard'),
        const PopupMenuDivider(),
        _menuItem('logout',    Icons.logout_rounded,          'Sign Out',  color: const Color(0xFFEF4444)),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0D9488), width: 2),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF0D9488).withValues(alpha:0.15),
          child: Text(
            role.isNotEmpty ? role[0].toUpperCase() : 'U',
            style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.white70;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, color: c, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c, fontSize: 13)),
      ]),
    );
  }

  Widget _glassRow({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Pressable card (scale on tap) ────────────────────────────────────────────

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// ── More Features Bottom Sheet ────────────────────────────────────────────────

class _MoreFeaturesSheet extends StatelessWidget {
  final bool isAdmin;
  final bool isWholesale;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _MoreFeaturesSheet({
    required this.isAdmin,
    required this.isWholesale,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('More Features', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),

            // Reports section
            _sectionLabel(context, 'Reports'),
            const SizedBox(height: 8),
            Row(children: [
              _featureCard(context, Icons.show_chart,          'Sales',      EnhancedTheme.successGreen, '/dashboard/reports/sales'),
              const SizedBox(width: 10),
              _featureCard(context, Icons.inventory_2_outlined, 'Inventory', EnhancedTheme.infoBlue,    '/dashboard/reports/inventory'),
              const SizedBox(width: 10),
              _featureCard(context, Icons.people_outline,       'Customers', EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
              const SizedBox(width: 10),
              _featureCard(context, Icons.trending_up,          'Profit',    EnhancedTheme.warningAmber, '/dashboard/reports/profit'),
            ]),
            const SizedBox(height: 20),

            // Dashboards section
            _sectionLabel(context, 'Dashboards'),
            const SizedBox(height: 8),
            Row(children: [
              _featureCard(context, Icons.storefront_outlined,  'Retail',    EnhancedTheme.primaryTeal, '/dashboard'),
              const SizedBox(width: 10),
              if (isAdmin) ...[
                _featureCard(context, Icons.admin_panel_settings_outlined, 'Admin', EnhancedTheme.errorRed, '/admin-dashboard'),
                const SizedBox(width: 10),
              ],
              if (isWholesale) ...[
                _featureCard(context, Icons.store_outlined, 'Wholesale', EnhancedTheme.accentCyan, '/wholesale-dashboard'),
                const SizedBox(width: 10),
              ],
              _featureCard(context, Icons.settings_outlined, 'Settings', context.subLabelColor, '/dashboard/settings'),
            ]),
            const SizedBox(height: 20),

            // Logout
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 11,
        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
  );

  Widget _featureCard(BuildContext context, IconData icon, String label, Color color, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onNavigate(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
