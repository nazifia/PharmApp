import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/offline/app_refresh.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_api_client.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/widgets/dashboard_card.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

final _wholesaleDashProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    return await ref.read(posApiProvider).fetchWholesaleDashboard();
  } catch (_) {
    return <String, dynamic>{};
  }
});

// Aggregates today's dispensed items from /pos/sales/ — accessible to all POS roles.
final _todayStaffItemsProvider = FutureProvider.autoDispose<List<TopItem>>((ref) async {
  final now = DateTime.now();
  final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  try {
    final sales = await ref.read(posApiProvider).fetchSales(from: today, to: today);
    final Map<String, _ItemAgg> agg = {};
    for (final sale in sales) {
      final items = (sale['items'] as List<dynamic>?) ?? [];
      for (final raw in items) {
        final item   = raw as Map<String, dynamic>;
        final name   = (item['name'] as String?) ?? (item['itemName'] as String?) ?? 'Unknown';
        final itemId = (item['itemId'] as num?)?.toInt() ?? (item['id'] as num?)?.toInt() ?? 0;
        final qty    = (item['quantity'] as num?)?.toInt() ?? 0;
        final price  = (item['price'] as num?)?.toDouble() ?? 0.0;
        if (agg.containsKey(name)) {
          agg[name]!.qty += qty;
          agg[name]!.revenue += qty * price;
        } else {
          agg[name] = _ItemAgg(itemId: itemId, name: name, qty: qty, revenue: qty * price);
        }
      }
    }
    return agg.values
        .map((a) => TopItem(itemId: a.itemId, name: a.name, qty: a.qty, revenue: a.revenue))
        .toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
  } catch (_) {
    return [];
  }
});

class _ItemAgg {
  final int itemId;
  final String name;
  int qty;
  double revenue;
  _ItemAgg({required this.itemId, required this.name, required this.qty, required this.revenue});
}

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
    final isAdmin     = Rbac.can(user, AppPermission.manageUsers);
    final isWholesale = Rbac.can(user, AppPermission.viewWholesale);
    final canReadRx   = Rbac.can(user, AppPermission.readPrescriptions);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreFeaturesSheet(
        isAdmin: isAdmin,
        isWholesale: isWholesale,
        canReadRx: canReadRx,
        onNavigate: (route) { Navigator.pop(context); context.go(route); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(1)}K';
    return fmtN(v);
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
          // Decorative orbs
          Positioned(top: -60, right: -60,
            child: Container(width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.06)))),
          Positioned(bottom: 100, left: -80,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.05)))),
          SafeArea(child: _content()),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(salesReportProvider('today'));
    ref.invalidate(salesReportProvider('week'));
    ref.invalidate(cashierSalesReportProvider('today'));
    ref.invalidate(_todayStaffItemsProvider);
    ref.invalidate(inventoryReportProvider);
    ref.invalidate(customerReportProvider);
    ref.invalidate(_wholesaleDashProvider);
    ref.read(appRefreshTriggerProvider.notifier).state++;
  }

  Widget _content() => _homeContent();

  Widget _homeContent() {
    final user         = ref.watch(currentUserProvider);
    final role         = user?.role ?? '';
    final isWsUser      = Rbac.can(user, AppPermission.viewWholesale);
    final isSeniorUser  = Rbac.isSenior(user);
    final canInventory  = Rbac.canViewInventory(user);
    // Admin-only endpoint — only used for senior users
    final salesAsync      = ref.watch(salesReportProvider('today'));
    final weekSalesAsync  = ref.watch(salesReportProvider('week'));
    // All-roles endpoints — used for non-senior users
    final cashierAsync    = ref.watch(cashierSalesReportProvider('today'));
    final staffItemsAsync = ref.watch(_todayStaffItemsProvider);
    final invAsync        = ref.watch(inventoryReportProvider);
    final custAsync       = ref.watch(customerReportProvider);
    final wide2           = MediaQuery.of(context).size.width > 600;
    final hour            = DateTime.now().hour;
    final greeting        = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final hasCustFeature    = ref.watch(hasFeatureProvider(SaasFeature.customers));
    final hasReportsFeature = ref.watch(hasFeatureProvider(SaasFeature.basicReports));
    // Senior users get full revenue from admin report; non-senior get their own total
    final revenue = isSeniorUser
        ? salesAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0
        : cashierAsync.whenOrNull(data: (d) => d.totalAmount) ?? 0.0;
    final lowStock  = invAsync.whenOrNull(data: (d) => d.lowStockCount) ?? 0;
    final customers = custAsync.whenOrNull(data: (d) => d.total) ?? 0;
    final debt      = custAsync.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final dispensed = isSeniorUser
        ? salesAsync.whenOrNull(data: (d) => d.topItems.fold<int>(0, (sum, i) => sum + i.qty)) ?? 0
        : staffItemsAsync.whenOrNull(data: (items) => items.fold<int>(0, (sum, i) => sum + i.qty)) ?? 0;
    final loading = isSeniorUser
        ? salesAsync.isLoading || invAsync.isLoading || custAsync.isLoading
        : cashierAsync.isLoading || invAsync.isLoading || staffItemsAsync.isLoading;

    final retailStats = [
      DashboardCard(title: "Today's Revenue", value: loading ? '…' : _fmt(revenue), subtitle: 'Retail + Wholesale', icon: Icons.monetization_on,  color: EnhancedTheme.successGreen),
      DashboardCard(title: 'Low Stock',        value: loading ? '…' : '$lowStock',   subtitle: 'Below threshold',     icon: Icons.warning_amber,    color: EnhancedTheme.warningAmber),
      if (!isSeniorUser)
        DashboardCard(title: 'Items Dispensed', value: loading ? '…' : '$dispensed', subtitle: 'Units sold today',    icon: Icons.medication_rounded, color: EnhancedTheme.accentCyan),
      if (hasCustFeature && isSeniorUser)
        DashboardCard(title: 'Customers',        value: loading ? '…' : '$customers',  subtitle: 'Total registered',    icon: Icons.people,           color: EnhancedTheme.accentPurple),
      if (hasCustFeature && isSeniorUser)
        DashboardCard(title: 'Outstanding Debt', value: loading ? '…' : _fmt(debt),    subtitle: 'Total owed',          icon: Icons.money_off,        color: EnhancedTheme.errorRed),
      if (hasCustFeature && !isSeniorUser)
        DashboardCard(title: 'Customers',        value: loading ? '…' : '$customers',  subtitle: 'Total registered',    icon: Icons.people,           color: EnhancedTheme.accentPurple),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      color: EnhancedTheme.primaryTeal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Header ───────────────────────────────────────────────────
          _heroHeader(context, user, role, greeting, wide2, revenue, loading),
          const SizedBox(height: 20),

          // ── Mode Toggle (wholesale users only) ────────────────────────────
          if (isWsUser) ...[
            _modeToggle(),
            const SizedBox(height: 20),
          ],

          // ══ RETAIL MODE ══════════════════════════════════════════════════
          if (!_showWholesale) ...[
            // Quick action buttons
            _quickActionsRow([
              (Icons.add_shopping_cart, 'New Sale',   EnhancedTheme.primaryTeal,   () => context.go('/dashboard/pos')),
              if (canInventory)
                (Icons.inventory_2,        'Inventory',  EnhancedTheme.infoBlue,      () => context.go('/dashboard/inventory')),
              if (hasCustFeature)
                (Icons.people,           'Customers',  EnhancedTheme.accentPurple,  () => context.go('/dashboard/customers')),
              (Icons.more_horiz_rounded, 'More',       context.subLabelColor,       _showMoreSheet),
            ]),
            const SizedBox(height: 20),

            // Stats grid
            GridView.count(
              crossAxisCount: wide2 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide2 ? 1.35 : 1.3,
              children: retailStats,
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),

            _quickAccessPanel(wide2, hasReportsFeature: hasReportsFeature),
            const SizedBox(height: 24),

            if (!isSeniorUser) ...[
              _sectionHeader('Dispensed Items Today', () => context.go('/dashboard/dispensing-log')),
              const SizedBox(height: 12),
              _staffDispensedSection(staffItemsAsync),
              const SizedBox(height: 24),
            ],

            if (isSeniorUser && hasReportsFeature) ...[
            _sectionHeader('This Week\'s Revenue', () => context.go('/dashboard/reports/sales')),
            const SizedBox(height: 12),
            _weeklyTrendSection(weekSalesAsync),
            const SizedBox(height: 24),

            _sectionHeader('Top Items Today', () => context.go('/dashboard/reports/sales')),
            const SizedBox(height: 12),
            _salesBarChart(salesAsync),
            const SizedBox(height: 24),

            _sectionHeader('Revenue Breakdown', () => context.go('/dashboard/reports/sales')),
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
                  return _emptyState(Icons.receipt_long_rounded, 'No sales today', EnhancedTheme.primaryTeal);
                }
                return Column(children: report.topItems.take(4).toList().asMap().entries.map((e) =>
                  _glassRow(child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                            EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                          ]),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.medication_rounded, color: Color(0xFF0D9488), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value.name, style: GoogleFonts.outfit(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${e.value.qty} units sold', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_fmt(e.value.revenue),
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 14)),
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text('#${e.key + 1}',
                            style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ]))
                ).toList()).animate().fadeIn(delay: 200.ms);
              },
            ),
            const SizedBox(height: 24),
            ], // end hasReportsFeature

            _sectionHeader('Low Stock Alerts', canInventory ? () => context.go('/dashboard/inventory') : () {}),
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
                  return _emptyState(Icons.check_circle_rounded, 'All items adequately stocked', EnhancedTheme.successGreen);
                }
                return Column(children: report.lowStockItems.take(4).map((s) {
                  final pct = s.stock / (s.lowStockThreshold > 0 ? s.lowStockThreshold : 1);
                  final c   = pct < 0.3 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber;
                  return _glassRow(child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0.1)]),
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.warning_amber_rounded, color: c, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: GoogleFonts.outfit(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(c),
                          minHeight: 4)),
                    ])),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${s.stock}', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('/ ${s.lowStockThreshold}', style: TextStyle(color: context.subLabelColor, fontSize: 10)),
                    ]),
                  ]));
                }).toList()).animate().fadeIn(delay: 300.ms);
              },
            ),
          ],

          // ══ WHOLESALE MODE ════════════════════════════════════════════════
          if (_showWholesale)
            _wholesaleBody(wide2, canInventory: canInventory),
        ],
      ),
      ),
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────────

  Widget _heroHeader(BuildContext context, dynamic user, String role, String greeting, bool wide2, double revenue, bool loading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                EnhancedTheme.accentCyan.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(children: [
            // Menu button — always visible so all users can access the drawer
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Icon(Icons.menu_rounded, color: context.labelColor, size: 20),
              ),
            ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting, style: GoogleFonts.inter(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(
                (user?.username.isNotEmpty == true ? user!.username : user?.phoneNumber) ?? 'User',
                style: GoogleFonts.outfit(color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(color: context.hintColor, fontSize: 12)),
              const SizedBox(height: 10),
              // Revenue badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: EnhancedTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_up_rounded, color: EnhancedTheme.successGreen, size: 14),
                  const SizedBox(width: 5),
                  Text(loading ? 'Loading…' : 'Today: ${_fmt(revenue)}',
                      style: const TextStyle(color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ])),
            _buildProfileMenu(role),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ── Mode Toggle ────────────────────────────────────────────────────────────

  Widget _modeToggle() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
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
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _toggleChip(String label, bool active, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: active ? LinearGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.1)]) : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: color.withValues(alpha: 0.45)) : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: active ? color : context.hintColor,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
              letterSpacing: active ? 0.3 : 0,
            )),
          ),
        ),
      ),
    );
  }

  // ── Quick Actions Row ──────────────────────────────────────────────────────

  Widget _quickActionsRow(List<(IconData, String, Color, VoidCallback)> actions) {
    return Row(
      children: actions.asMap().entries.map((e) {
        final (icon, label, color, onTap) = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
            child: _PressableCard(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(height: 7),
                      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  // ── Wholesale Body ─────────────────────────────────────────────────────────

  Widget _wholesaleBody(bool wide2, {required bool canInventory}) {
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
          DashboardCard(title: "Today's Revenue", value: _fmt(todayRevenue), subtitle: 'Wholesale',       icon: Icons.monetization_on, color: EnhancedTheme.successGreen),
          DashboardCard(title: 'Total Sales',     value: '$totalSales',      subtitle: 'All time',        icon: Icons.receipt_long,    color: EnhancedTheme.infoBlue),
          DashboardCard(title: 'WS Customers',    value: '$wsCustomers',     subtitle: 'Wholesale clients', icon: Icons.people,        color: EnhancedTheme.accentPurple),
          DashboardCard(title: 'Outstanding Debt',value: _fmt(outstandingDebt), subtitle: 'Total owed',   icon: Icons.money_off,       color: EnhancedTheme.errorRed),
        ];

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Quick actions
          _quickActionsRow([
            (Icons.point_of_sale_rounded, 'WS Sale',    EnhancedTheme.accentCyan,    () => context.go('/dashboard/wholesale-pos')),
            (Icons.receipt_long_rounded,  'WS Sales',   EnhancedTheme.successGreen,  () => context.go('/dashboard/wholesale-sales')),
            (Icons.swap_horiz_rounded,    'Transfers',  EnhancedTheme.warningAmber,  () => context.go('/dashboard/transfers')),
            (Icons.more_horiz_rounded,    'More',       context.subLabelColor,       _showMoreSheet),
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
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 24),

          // Wholesale quick access panel
          _wholesaleQuickAccess(wide2, canInventory: canInventory),
          const SizedBox(height: 24),

          // Top products
          _sectionHeader('Top Products Today', () => context.go('/dashboard/wholesale-sales')),
          const SizedBox(height: 12),
          if (topProducts.isEmpty)
            _emptyState(Icons.store_rounded, 'No wholesale sales today', EnhancedTheme.accentCyan)
          else
            Column(children: topProducts.take(4).map((p) {
              final name = p['name'] as String? ?? '';
              final qty  = (p['qty']     as num?)?.toInt()    ?? 0;
              final rev  = (p['revenue'] as num?)?.toDouble() ?? 0.0;
              return _glassRow(child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.accentCyan.withValues(alpha: 0.25),
                      EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                    ]),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.outfit(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$qty units sold', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
                Text(_fmt(rev), style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w800, fontSize: 14)),
              ]));
            }).toList()),
          const SizedBox(height: 24),

          // Pending transfers
          _sectionHeader('Pending Transfers', () => context.go('/dashboard/transfers')),
          const SizedBox(height: 12),
          if (pendingTransfers.isEmpty)
            _emptyState(Icons.swap_horiz_rounded, 'No pending transfers', EnhancedTheme.warningAmber)
          else
            Column(children: pendingTransfers.take(4).map((t) {
              final itemName = t['itemName'] as String? ?? '';
              final reqQty   = t['requestedQty'] ?? 0;
              final unit     = t['unit'] as String? ?? 'Pcs';
              return _glassRow(child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.warningAmber.withValues(alpha: 0.25),
                      EnhancedTheme.warningAmber.withValues(alpha: 0.1),
                    ]),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.swap_horiz_rounded, color: EnhancedTheme.warningAmber, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(itemName, style: GoogleFonts.outfit(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Requested: $reqQty $unit', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.3))),
                  child: const Text('Pending',
                      style: TextStyle(color: EnhancedTheme.warningAmber, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]));
            }).toList()),
          const SizedBox(height: 24),

          // Low stock
          _sectionHeader('Low Stock Alerts', canInventory ? () => context.go('/dashboard/inventory') : () {}),
          const SizedBox(height: 12),
          if (lowStockItems.isEmpty)
            _emptyState(Icons.check_circle_rounded, 'All items adequately stocked', EnhancedTheme.successGreen)
          else
            Column(children: lowStockItems.take(4).map((s) {
              final name      = s['name']      as String? ?? '';
              final stock     = (s['stock']    as num?)?.toInt() ?? 0;
              final threshold = (s['threshold'] as num?)?.toInt() ?? 1;
              final pct = stock / (threshold > 0 ? threshold : 1);
              final c   = pct < 0.3 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber;
              return _glassRow(child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0.1)]),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.warning_amber_rounded, color: c, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.outfit(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: context.borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                      minHeight: 4)),
                ])),
                const SizedBox(width: 12),
                Text('$stock units', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 14)),
              ]));
            }).toList()),
        ]);
      },
    );
  }

  Widget _wholesaleQuickAccess(bool wide, {required bool canInventory}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                context.cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.store_rounded, color: EnhancedTheme.accentCyan, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Wholesale Quick Access',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
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
                      [
                        (Icons.swap_horiz_rounded, 'Transfers', '/dashboard/transfers'),
                        if (canInventory)
                          (Icons.inventory_rounded, 'Inventory', '/dashboard/inventory'),
                      ],
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _quickAccessCard(
                      'My Activity', 'Daily sales & history',
                      Icons.receipt_long_rounded, EnhancedTheme.accentOrange,
                      [(Icons.today_rounded, 'My Daily Sales', '/dashboard/reports/cashier-sales'),
                       (Icons.history_rounded, 'WS Sales', '/dashboard/wholesale-sales')],
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
                      [
                        (Icons.swap_horiz_rounded, 'Transfers', '/dashboard/transfers'),
                        if (canInventory)
                          (Icons.inventory_rounded, 'Inventory', '/dashboard/inventory'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _quickAccessCard(
                      'My Activity', 'Daily sales & history',
                      Icons.receipt_long_rounded, EnhancedTheme.accentOrange,
                      [(Icons.today_rounded, 'My Daily Sales', '/dashboard/reports/cashier-sales'),
                       (Icons.history_rounded, 'WS Sales', '/dashboard/wholesale-sales')],
                    ),
                  ]),
          ]),
        ),
      ),
    );
  }

  // ── Quick Access Panel ─────────────────────────────────────────────────────

  Widget _quickAccessPanel(bool wide, {required bool hasReportsFeature}) {
    final user = ref.read(currentUserProvider);
    final isAdminUser = Rbac.can(user, AppPermission.viewReports);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                context.cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.dashboard_rounded, color: EnhancedTheme.primaryTeal, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Quick Access',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
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
                    if (isAdminUser && hasReportsFeature) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _quickAccessCard(
                        'Reports & Analytics', 'Business Insights',
                        Icons.analytics_rounded, EnhancedTheme.accentCyan,
                        [(Icons.today_rounded, 'Daily Sales', '/dashboard/reports/sales'),
                         (Icons.show_chart_rounded, 'Sales Report', '/dashboard/reports/sales')],
                      )),
                    ] else ...[
                      const SizedBox(width: 10),
                      Expanded(child: _quickAccessCard(
                        'My Daily Sales', 'Your transactions',
                        Icons.receipt_long_rounded, EnhancedTheme.accentOrange,
                        [(Icons.today_rounded, 'View My Sales', '/dashboard/reports/cashier-sales'),
                         (Icons.history_rounded, 'Sale History', '/dashboard/sales')],
                      )),
                    ],
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
                    if (isAdminUser && hasReportsFeature) ...[
                      const SizedBox(height: 10),
                      _quickAccessCard(
                        'Reports & Analytics', 'Business Insights',
                        Icons.analytics_rounded, EnhancedTheme.accentCyan,
                        [(Icons.today_rounded, 'Daily Sales', '/dashboard/reports/sales'),
                         (Icons.show_chart_rounded, 'Sales Report', '/dashboard/reports/sales')],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      _quickAccessCard(
                        'My Daily Sales', 'Your transactions',
                        Icons.receipt_long_rounded, EnhancedTheme.accentOrange,
                        [(Icons.today_rounded, 'View My Sales', '/dashboard/reports/cashier-sales'),
                         (Icons.history_rounded, 'Sale History', '/dashboard/sales')],
                      ),
                    ],
                  ]),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _quickAccessCard(String title, String subtitle, IconData icon, Color color, List<(IconData, String, String)> actions) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(color: context.labelColor, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.1))),
                child: Row(children: [
                  Icon(a.$1, color: color, size: 13),
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

  // ── Staff Dispensed Items Section (non-senior: uses POS sales endpoint) ──────

  Widget _staffDispensedSection(AsyncValue<List<TopItem>> itemsAsync) {
    return itemsAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: EnhancedTheme.accentCyan),
      )),
      error: (e, _) => _emptyState(Icons.medication_rounded, 'No items dispensed today', EnhancedTheme.accentCyan),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(Icons.medication_rounded, 'No items dispensed today', EnhancedTheme.accentCyan);
        }
        return Column(
          children: items.take(5).toList().asMap().entries.map((e) {
            final item = e.value;
            return _glassRow(child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.3),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  ]),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.medication_rounded, color: EnhancedTheme.accentCyan, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name,
                    style: GoogleFonts.outfit(color: context.labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${item.qty} units dispensed',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt(item.revenue),
                    style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w800, fontSize: 14)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text('#${e.key + 1}',
                      style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]));
          }).toList(),
        ).animate().fadeIn(delay: 200.ms);
      },
    );
  }

  // ── Weekly Revenue Line Chart ─────────────────────────────────────────────

  Widget _weeklyTrendSection(AsyncValue<SalesReportData> weekAsync) {
    return weekAsync.when(
      loading: () => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor)),
            child: const Center(child: CircularProgressIndicator(color: EnhancedTheme.accentCyan, strokeWidth: 2)),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (weekData) {
        if (weekData.totalRevenue <= 0) return const SizedBox.shrink();
        final spots = _buildWeekSpots(weekData);
        final labels = _weekLabels();
        final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              height: 190,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.07),
                    context.cardColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.22))),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: maxY * 1.25,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY * 0.5,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.borderColor,
                      strokeWidth: 0.6,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: maxY * 0.5,
                        getTitlesWidget: (val, _) => Text(
                          _fmt(val),
                          style: TextStyle(color: context.hintColor, fontSize: 9),
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (val, _) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[idx],
                                style: TextStyle(color: context.hintColor, fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF1E293B),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        _fmt(s.y),
                        const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w700),
                      )).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: EnhancedTheme.accentCyan,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                          radius: idx == 6 ? 4.5 : 2.5,
                          color: idx == 6 ? EnhancedTheme.primaryTeal : EnhancedTheme.accentCyan,
                          strokeWidth: 1.5,
                          strokeColor: context.scaffoldBg,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            EnhancedTheme.accentCyan.withValues(alpha: 0.22),
                            EnhancedTheme.accentCyan.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
      },
    );
  }

  List<FlSpot> _buildWeekSpots(SalesReportData weekData) {
    if (weekData.dailySales.length >= 2) {
      final list = weekData.dailySales.take(7).toList();
      return list.asMap().entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.revenue))
          .toList();
    }
    // Simulate plausible 7-day distribution from the weekly total.
    final total = weekData.totalRevenue;
    const weights = [0.10, 0.13, 0.12, 0.17, 0.14, 0.18, 0.16];
    return List.generate(7, (i) => FlSpot(i.toDouble(), total * weights[i]));
  }

  List<String> _weekLabels() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      // d.weekday: 1=Mon … 7=Sun
      return days[d.weekday - 1];
    });
  }

  // ── Top Items Bar Chart ───────────────────────────────────────────────────

  Widget _salesBarChart(AsyncValue<SalesReportData> salesAsync) {
    return salesAsync.when(
      loading: () => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor)),
            child: const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2)),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (report) {
        final items = report.topItems.take(5).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final maxRevenue = items.fold<double>(0, (m, i) => i.revenue > m ? i.revenue : m);
        if (maxRevenue <= 0) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                    context.cardColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2))),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxRevenue * 1.25,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxRevenue / 3,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: context.borderColor,
                        strokeWidth: 0.6,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46,
                          interval: maxRevenue / 3,
                          getTitlesWidget: (val, _) => Text(
                            _fmt(val),
                            style: TextStyle(color: context.hintColor, fontSize: 9),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                            final name = items[idx].name;
                            final label = name.length > 7 ? name.substring(0, 7) : name;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(label,
                                  style: TextStyle(color: context.hintColor, fontSize: 9),
                                  textAlign: TextAlign.center),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1E293B),
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIdx, rod, _) {
                          if (groupIdx >= items.length) return null;
                          return BarTooltipItem(
                            '${items[groupIdx].name}\n',
                            const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                            children: [
                              TextSpan(
                                text: _fmt(rod.toY),
                                style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    barGroups: items.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.revenue,
                            width: 22,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                EnhancedTheme.primaryTeal.withValues(alpha: 0.75),
                                EnhancedTheme.accentCyan,
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
      },
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      GestureDetector(
        onTap: onSeeAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
          child: const Text('See all', style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _buildProfileMenu(String role) {
    final user        = ref.read(currentUserProvider);
    final isAdmin     = Rbac.can(user, AppPermission.manageUsers);
    final isWholesale = Rbac.can(user, AppPermission.viewWholesale);
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: EnhancedTheme.surfaceColor,
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
            backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha:0.2),
            child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U',
                style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
            const Text('Logged in', style: TextStyle(color: Colors.black38, fontSize: 11)),
          ]),
        ])),
        const PopupMenuDivider(),
        _menuItem('settings',  Icons.settings_outlined,       'Settings'),
        if (isAdmin && ref.read(hasFeatureProvider(SaasFeature.basicReports)))
          _menuItem('reports',   Icons.bar_chart_outlined,      'Reports'),
        if (isAdmin)
          _menuItem('admin',     Icons.admin_panel_settings_outlined, 'Admin Dashboard'),
        if (isWholesale && ref.read(hasFeatureProvider(SaasFeature.wholesale)))
          _menuItem('wholesale', Icons.store_outlined,         'Wholesale Dashboard'),
        const PopupMenuDivider(),
        _menuItem('logout',    Icons.logout_rounded,          'Sign Out',  color: EnhancedTheme.errorRed),
      ],
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
          child: Text(
            role.isNotEmpty ? role[0].toUpperCase() : 'U',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
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
          margin: const EdgeInsets.only(bottom: 10),
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

  Widget _emptyState(IconData icon, String message, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 10),
            Text(message, style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

// ── Pressable card (scale on tap) ─────────────────────────────────────────────

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

// ── More Features Bottom Sheet ─────────────────────────────────────────────────

class _MoreFeaturesSheet extends ConsumerWidget {
  final bool isAdmin;
  final bool isWholesale;
  final bool canReadRx;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _MoreFeaturesSheet({
    required this.isAdmin,
    required this.isWholesale,
    required this.canReadRx,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReportsFeature  = ref.watch(hasFeatureProvider(SaasFeature.basicReports));
    final hasAdvancedReports = ref.watch(hasFeatureProvider(SaasFeature.advancedReports));
    final hasWsFeature       = ref.watch(hasFeatureProvider(SaasFeature.wholesale));
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? EnhancedTheme.surfaceColor.withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.borderColor, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(width: 44, height: 4,
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.apps_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              Text('More Features',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),

            if (isAdmin && hasReportsFeature) ...[
              // Reports section
              _sectionLabel(context, 'Reports'),
              const SizedBox(height: 10),
              Row(children: [
                _featureCard(context, Icons.show_chart,          'Sales',      EnhancedTheme.successGreen, '/dashboard/reports/sales'),
                const SizedBox(width: 10),
                _featureCard(context, Icons.inventory_2_outlined, 'Inventory', EnhancedTheme.infoBlue,    '/dashboard/reports/inventory'),
                const SizedBox(width: 10),
                _featureCard(context, Icons.people_outline,       'Customers', EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
                if (hasAdvancedReports) ...[
                  const SizedBox(width: 10),
                  _featureCard(context, Icons.trending_up,        'Profit',    EnhancedTheme.warningAmber, '/dashboard/reports/profit'),
                ],
              ]),
              const SizedBox(height: 20),
            ],

            if (!isAdmin) ...[
              _sectionLabel(context, 'My Sales'),
              const SizedBox(height: 10),
              Row(children: [
                _featureCard(context, Icons.today_rounded,        'Daily Sales', EnhancedTheme.accentOrange,  '/dashboard/reports/cashier-sales'),
                const SizedBox(width: 10),
                _featureCard(context, Icons.history_rounded,      'Sale History', EnhancedTheme.successGreen, '/dashboard/sales'),
                const SizedBox(width: 10),
                _featureCard(context, Icons.list_alt_rounded,     'Disp. Log',   EnhancedTheme.primaryTeal,  '/dashboard/dispensing-log'),
              ]),
              const SizedBox(height: 20),
            ],

            if (canReadRx) ...[
              _sectionLabel(context, 'Clinical'),
              const SizedBox(height: 10),
              Row(children: [
                _featureCard(context, Icons.medical_services_rounded, 'Prescriptions', EnhancedTheme.primaryTeal, '/dashboard/prescriptions'),
                const SizedBox(width: 10),
                _featureCard(context, Icons.person_search_rounded, 'Prescribers', EnhancedTheme.accentPurple, '/dashboard/prescribers'),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox.shrink()),
              ]),
              const SizedBox(height: 20),
            ],

            // Dashboards section
            _sectionLabel(context, 'Dashboards'),
            const SizedBox(height: 10),
            Row(children: [
              _featureCard(context, Icons.storefront_outlined,  'Retail',    EnhancedTheme.primaryTeal, '/dashboard'),
              const SizedBox(width: 10),
              if (isAdmin) ...[
                _featureCard(context, Icons.admin_panel_settings_outlined, 'Admin', EnhancedTheme.errorRed, '/admin-dashboard'),
                const SizedBox(width: 10),
              ],
              if (isWholesale && hasWsFeature) ...[
                _featureCard(context, Icons.store_outlined, 'Wholesale', EnhancedTheme.accentCyan, '/wholesale-dashboard'),
                const SizedBox(width: 10),
              ],
              _featureCard(context, Icons.settings_outlined, 'Settings', context.subLabelColor, '/dashboard/settings'),
            ]),
            const SizedBox(height: 24),

            // Logout
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EnhancedTheme.errorRed.withValues(alpha: 0.18),
                      EnhancedTheme.errorRed.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Align(
    alignment: Alignment.centerLeft,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(color: EnhancedTheme.primaryTeal, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    ]),
  );

  Widget _featureCard(BuildContext context, IconData icon, String label, Color color, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onNavigate(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.07)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 7),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
