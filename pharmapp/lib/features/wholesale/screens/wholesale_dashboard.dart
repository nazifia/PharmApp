import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_api_client.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

class WholesaleDashboard extends ConsumerStatefulWidget {
  const WholesaleDashboard({super.key});

  @override
  ConsumerState<WholesaleDashboard> createState() => _WholesaleDashboardState();
}

class _WholesaleDashboardState extends ConsumerState<WholesaleDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(0)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  void _logout() {
    ref.read(authServiceProvider).logout();
    context.go('/login');
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WholesaleMoreSheet(
        onNavigate: (route) { Navigator.pop(context); context.go(route); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  Widget _buildProfileMenu(String? role) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        switch (val) {
          case 'settings':   context.push('/dashboard/settings'); break;
          case 'reports':    context.push('/dashboard/reports'); break;
          case 'retail':     context.go('/dashboard'); break;
          case 'admin':      context.go('/admin-dashboard'); break;
          case 'logout':     _logout(); break;
        }
      },
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role ?? 'Wholesale', style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 13)),
            const Text('Wholesale dashboard', style: TextStyle(color: Colors.black38, fontSize: 11)),
          ]),
        ),
        const PopupMenuDivider(),
        _menuItem('settings', Icons.settings_outlined, 'Settings'),
        _menuItem('reports',  Icons.bar_chart_rounded,  'Reports'),
        _menuItem('retail',   Icons.storefront_rounded,  'Retail Dashboard'),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18, color: EnhancedTheme.errorRed),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(color: EnhancedTheme.errorRed, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            EnhancedTheme.accentCyan.withValues(alpha: 0.3),
            EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
          ]),
          shape: BoxShape.circle,
          border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.4), width: 1.5),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
          child: const Icon(Icons.store_rounded, size: 18, color: EnhancedTheme.accentCyan),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black, fontSize: 13)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final user            = ref.watch(currentUserProvider);
    final salesTodayAsync  = ref.watch(salesReportProvider('today'));
    final salesMonthAsync  = ref.watch(salesReportProvider('month'));
    final customerAsync    = ref.watch(customerReportProvider);
    final wsInventoryAsync = ref.watch(inventoryListProvider);

    final revenue    = salesTodayAsync.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ?? 0.0;
    final orderCount = salesTodayAsync.whenOrNull(data: (d) => d.topItems.fold<int>(0, (s, i) => s + i.qty)) ?? 0;
    final wsCustomers = customerAsync.whenOrNull(data: (d) => d.wholesale) ?? 0;
    final isLoading   = salesTodayAsync.isLoading || customerAsync.isLoading;

    final stats = [
      {'label': "Today's Revenue", 'value': isLoading ? '—' : _fmt(revenue),   'icon': Icons.trending_up_rounded,   'color': EnhancedTheme.successGreen},
      {'label': 'Units Sold',      'value': isLoading ? '—' : '$orderCount',    'icon': Icons.shopping_cart_rounded,  'color': EnhancedTheme.primaryTeal},
      {'label': 'WS Customers',    'value': isLoading ? '—' : '$wsCustomers',   'icon': Icons.store_rounded,          'color': EnhancedTheme.accentCyan},
      {'label': 'Outstanding',     'value': customerAsync.whenOrNull(data: (d) => _fmt(d.totalDebt)) ?? '—',
          'icon': Icons.money_off_rounded, 'color': EnhancedTheme.warningAmber},
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative glow blobs
        Positioned(top: -80, right: -80,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(top: 200, left: -60,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.10),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(context, user?.role),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── B2B Stats Grid ─────────────────────────────────────────
              _buildStatsGrid(context, stats, isLoading)
                  .animate().fadeIn(delay: 100.ms).slideY(begin: 0.15),
              const SizedBox(height: 24),

              // ── Quick Actions ───────────────────────────────────────────
              _buildQuickActions(context)
                  .animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
              const SizedBox(height: 24),

              // ── Wholesale Inventory ─────────────────────────────────────
              _buildSectionHeader(context, 'Wholesale Inventory',
                  Icons.inventory_2_rounded, EnhancedTheme.accentCyan,
                  onTap: () => context.push('/dashboard/inventory'))
                  .animate().fadeIn(delay: 280.ms),
              const SizedBox(height: 10),
              wsInventoryAsync.when(
                loading: () => EnhancedTheme.loadingShimmer(height: 80, radius: 16),
                error: (e, _) => _errorCard(context, 'Could not load inventory'),
                data: (items) {
                  final total    = items.length;
                  final lowStock = items.where((i) => i.stock > 0 && i.stock <= i.lowStockThreshold).length;
                  final outStock = items.where((i) => i.stock == 0).length;
                  return _inventoryStatsCard(context, total, lowStock, outStock)
                      .animate().fadeIn(delay: 320.ms).slideY(begin: 0.1);
                },
              ),
              if (wsInventoryAsync.valueOrNull?.any((i) => i.stock == 0 || i.stock <= i.lowStockThreshold) == true) ...[
                const SizedBox(height: 8),
                _buildLowStockAlerts(context, wsInventoryAsync.value!),
              ],
              const SizedBox(height: 24),

              // ── Top Customers ────────────────────────────────────────────
              _buildSectionHeader(context, 'Top Customers',
                  Icons.people_rounded, EnhancedTheme.accentPurple)
                  .animate().fadeIn(delay: 380.ms),
              const SizedBox(height: 10),
              customerAsync.when(
                loading: () => Column(children: [
                  EnhancedTheme.loadingShimmer(height: 68, radius: 14),
                  const SizedBox(height: 8),
                  EnhancedTheme.loadingShimmer(height: 68, radius: 14),
                ]),
                error: (e, _) => _errorCard(context, 'Failed to load customer data'),
                data: (report) => report.topCustomers.isEmpty
                    ? _emptyState(context, Icons.people_outline_rounded, 'No customer data yet')
                    : Column(children: report.topCustomers.take(5).toList().asMap().entries.map((e) =>
                        _customerCard(context, e.value, e.key)
                            .animate().fadeIn(delay: (400 + e.key * 60).ms).slideX(begin: -0.05)
                      ).toList()),
              ),
              const SizedBox(height: 24),

              // ── Top Products ─────────────────────────────────────────────
              _buildSectionHeader(context, 'Top Products This Month',
                  Icons.local_pharmacy_rounded, EnhancedTheme.primaryTeal)
                  .animate().fadeIn(delay: 480.ms),
              const SizedBox(height: 10),
              salesMonthAsync.when(
                loading: () => EnhancedTheme.loadingShimmer(height: 220, radius: 16),
                error: (e, _) => _errorCard(context, 'Failed to load products data'),
                data: (report) => report.topItems.isEmpty
                    ? _emptyState(context, Icons.inventory_2_outlined, 'No sales data this month')
                    : _topProductsCard(context, report.topItems.take(5).toList())
                        .animate().fadeIn(delay: 520.ms).slideY(begin: 0.1),
              ),
              const SizedBox(height: 24),

              // ── More button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showMoreSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.labelColor,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(Icons.apps_rounded, color: context.subLabelColor),
                  label: Text('More Features',
                      style: GoogleFonts.inter(color: context.subLabelColor, fontWeight: FontWeight.w600)),
                ),
              ).animate().fadeIn(delay: 560.ms),
              const SizedBox(height: 24),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, String? role) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: context.iconOnBg,
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Wholesale',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  EnhancedTheme.accentCyan.withValues(alpha: 0.25),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                ]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.35)),
              ),
              child: Text('B2B',
                  style: GoogleFonts.outfit(
                      color: EnhancedTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          Text('Bulk order management',
              style: GoogleFonts.inter(color: context.hintColor, fontSize: 12)),
        ])),
        // New Order Button
        GestureDetector(
          onTap: () => context.push('/dashboard/wholesale-pos'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [EnhancedTheme.accentCyan, EnhancedTheme.primaryTeal],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.4),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, color: Colors.black, size: 18),
              const SizedBox(width: 6),
              Text('New Order',
                  style: GoogleFonts.inter(
                      color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        _buildProfileMenu(role),
      ]),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.2);
  }

  Widget _buildStatsGrid(BuildContext context, List<Map<String, Object>> stats, bool isLoading) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12,
          crossAxisSpacing: 12, childAspectRatio: 1.55),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s     = stats[i];
        final color = s['color'] as Color;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.14),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s['icon'] as IconData, color: color, size: 18),
                  ),
                  Icon(Icons.more_horiz_rounded,
                      color: color.withValues(alpha: 0.4), size: 16),
                ]),
                const Spacer(),
                isLoading && s['value'] == '—'
                    ? SizedBox(
                        height: 24,
                        child: LinearProgressIndicator(
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ))
                    : Text(s['value'] as String,
                        style: GoogleFonts.outfit(
                            color: color, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(s['label'] as String,
                    style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 11)),
              ]),
            ),
          ),
        ).animate().fadeIn(delay: (100 + i * 60).ms).scale(begin: const Offset(0.92, 0.92));
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'label': 'Inventory', 'icon': Icons.inventory_2_rounded, 'color': EnhancedTheme.accentCyan, 'route': '/dashboard/inventory'},
      {'label': 'Transfers', 'icon': Icons.swap_horiz_rounded, 'color': EnhancedTheme.accentPurple, 'route': '/wholesale-dashboard/transfers'},
      {'label': 'WS Sales', 'icon': Icons.receipt_long_rounded, 'color': EnhancedTheme.primaryTeal, 'route': '/wholesale-dashboard/sales'},
      {'label': 'Reports', 'icon': Icons.bar_chart_rounded, 'color': EnhancedTheme.successGreen, 'route': '/dashboard/reports'},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [EnhancedTheme.accentCyan, EnhancedTheme.primaryTeal],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text('Quick Actions',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Row(children: actions.map((a) {
        final color = a['color'] as Color;
        return Expanded(child: GestureDetector(
          onTap: () => context.push(a['route'] as String),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.14),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              Icon(a['icon'] as IconData, color: color, size: 22),
              const SizedBox(height: 6),
              Text(a['label'] as String,
                  style: GoogleFonts.inter(
                      color: context.subLabelColor, fontSize: 10, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ]),
          ),
        ));
      }).toList()),
    ]);
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color, {VoidCallback? onTap}) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(title,
          style: GoogleFonts.outfit(
              color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700))),
      if (onTap != null)
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View', style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 10),
            ]),
          ),
        ),
    ]);
  }

  Widget _inventoryStatsCard(BuildContext context, int total, int lowStock, int outStock) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Expanded(child: _invStatCol(context, '$total', 'Total Items', EnhancedTheme.accentCyan)),
            Container(width: 1, height: 40, color: context.dividerColor),
            Expanded(child: _invStatCol(context, '$lowStock', 'Low Stock', EnhancedTheme.warningAmber)),
            Container(width: 1, height: 40, color: context.dividerColor),
            Expanded(child: _invStatCol(context, '$outStock', 'Out of Stock', EnhancedTheme.errorRed)),
            GestureDetector(
              onTap: () => context.push('/dashboard/inventory'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_rounded, color: EnhancedTheme.accentCyan, size: 16),
                  SizedBox(width: 6),
                  Text('View', style: TextStyle(color: EnhancedTheme.accentCyan,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _invStatCol(BuildContext context, String value, String label, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(color: context.hintColor, fontSize: 10),
          textAlign: TextAlign.center),
    ]);
  }

  Widget _customerCard(BuildContext context, TopCustomer c, int index) {
    final initials = c.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final colors = [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple, EnhancedTheme.primaryTeal,
                    EnhancedTheme.successGreen, EnhancedTheme.warningAmber];
    final avatarColor = colors[index % colors.length];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    avatarColor.withValues(alpha: 0.3),
                    avatarColor.withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: avatarColor.withValues(alpha: 0.3)),
              ),
              child: Center(child: Text(initials.isEmpty ? '?' : initials,
                  style: GoogleFonts.outfit(color: avatarColor, fontSize: 14, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  style: GoogleFonts.inter(
                      color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: EnhancedTheme.successGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('Wholesale Customer',
                    style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(c.spent),
                  style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text('total spent',
                  style: GoogleFonts.inter(color: context.hintColor, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _topProductsCard(BuildContext context, List<dynamic> topItems) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            children: topItems.asMap().entries.map((e) =>
              Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          EnhancedTheme.accentCyan.withValues(alpha: 0.25),
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                        ]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text('${e.key + 1}',
                          style: GoogleFonts.outfit(color: EnhancedTheme.accentCyan,
                              fontSize: 13, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.value.name,
                          style: GoogleFonts.inter(color: context.labelColor,
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${e.value.qty} units sold',
                          style: GoogleFonts.inter(color: context.hintColor, fontSize: 11)),
                    ])),
                    Text(_fmt(e.value.revenue),
                        style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (e.key < topItems.length - 1 && e.key < 4)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        context.dividerColor,
                        Colors.transparent,
                      ]),
                    ),
                  ),
              ])
            ).toList(),
          ),
        ),
      ),
    );
  }

  Widget _errorCard(BuildContext context, String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: EnhancedTheme.errorRed, size: 18),
        const SizedBox(width: 10),
        Text(msg, style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13)),
      ]),
    ),
  );

  Widget _emptyState(BuildContext context, IconData icon, String msg) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(children: [
        Icon(icon, color: context.hintColor.withValues(alpha: 0.4), size: 40),
        const SizedBox(height: 10),
        Text(msg, style: GoogleFonts.inter(color: context.hintColor, fontSize: 13)),
      ]),
    ),
  );

  Widget _buildLowStockAlerts(BuildContext context, List<Item> items) {
    final alerts = items.where((i) => i.stock == 0 || i.stock <= i.lowStockThreshold).take(3).toList();
    return Column(children: alerts.map<Widget>((item) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (item.stock == 0 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (item.stock == 0 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(item.stock == 0 ? Icons.remove_circle_rounded : Icons.warning_amber_rounded,
            color: item.stock == 0 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(item.name,
            style: GoogleFonts.inter(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(item.stock == 0 ? 'Out of Stock' : '${item.stock} left',
            style: GoogleFonts.inter(
              color: item.stock == 0 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber,
              fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    )).toList());
  }
}

// ── Wholesale More Sheet ───────────────────────────────────────────────────────

class _WholesaleMoreSheet extends StatelessWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _WholesaleMoreSheet({required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 20),

            Text('Reports',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              _sheetTile(context, Icons.bar_chart_rounded,       'Sales',     EnhancedTheme.primaryTeal,  '/dashboard/reports/sales'),
              _sheetTile(context, Icons.inventory_2_rounded,     'Inventory', EnhancedTheme.accentCyan,   '/dashboard/reports/inventory'),
              _sheetTile(context, Icons.people_rounded,          'Customers', EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
              _sheetTile(context, Icons.savings_rounded,         'Profit',    EnhancedTheme.successGreen, '/dashboard/reports/profit'),
            ]),
            const SizedBox(height: 20),

            Text('Navigate',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              _sheetTile(context, Icons.inventory_2_rounded,     'Inventory',   EnhancedTheme.accentCyan,   '/dashboard/inventory'),
              _sheetTile(context, Icons.storefront_rounded,      'Retail',      EnhancedTheme.primaryTeal,  '/dashboard'),
              _sheetTile(context, Icons.point_of_sale_rounded,   'Retail POS',  EnhancedTheme.accentCyan,   '/dashboard/pos'),
              _sheetTile(context, Icons.settings_rounded,        'Settings',    EnhancedTheme.accentPurple, '/dashboard/settings'),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                  foregroundColor: EnhancedTheme.errorRed,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: Text('Sign Out',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sheetTile(BuildContext context, IconData icon, String label, Color color, String route) =>
      Expanded(child: GestureDetector(
        onTap: () => onNavigate(route),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: context.subLabelColor, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
      ));
}
