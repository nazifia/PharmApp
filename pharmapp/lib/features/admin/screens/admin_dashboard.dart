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
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _fmt(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
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
      builder: (_) => _AdminMoreSheet(
        onNavigate: (route) {
          Navigator.pop(context);
          context.go(route);
        },
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final salesToday = ref.watch(salesReportProvider('today'));
    final inventoryRpt = ref.watch(inventoryReportProvider);
    final customerRpt = ref.watch(customerReportProvider);
    final retailInvAsync = ref.watch(retailInventoryProvider);
    final wholesaleInvAsync = ref.watch(wholesaleInventoryProvider);

    final revenue =
        salesToday.whenOrNull(data: (d) => d.totalRetail + d.totalWholesale) ??
            0.0;
    final lowStock = inventoryRpt.whenOrNull(data: (d) => d.lowStockCount) ?? 0;
    final customers = customerRpt.whenOrNull(data: (d) => d.total) ?? 0;
    final debt = customerRpt.whenOrNull(data: (d) => d.totalDebt) ?? 0.0;
    final stockValue =
        inventoryRpt.whenOrNull(data: (d) => d.stockValue) ?? 0.0;
    final topItemCount =
        salesToday.whenOrNull(data: (d) => d.topItems.length) ?? 0;
    final isLoading =
        salesToday.isLoading || inventoryRpt.isLoading || customerRpt.isLoading;

    String kpiVal(String val) => isLoading ? '—' : val;

    final kpis = [
      {
        'label': 'Today\'s Revenue',
        'value': kpiVal(_fmt(revenue)),
        'sub': 'Retail + Wholesale',
        'color': EnhancedTheme.successGreen,
        'icon': Icons.trending_up_rounded
      },
      {
        'label': 'Top Items Today',
        'value': kpiVal('$topItemCount'),
        'sub': 'Distinct items sold',
        'color': EnhancedTheme.primaryTeal,
        'icon': Icons.receipt_long_rounded
      },
      {
        'label': 'Low Stock Items',
        'value': kpiVal('$lowStock'),
        'sub': 'Need reorder',
        'color': EnhancedTheme.warningAmber,
        'icon': Icons.warning_amber_rounded
      },
      {
        'label': 'Customers',
        'value': kpiVal('$customers'),
        'sub': 'Total registered',
        'color': EnhancedTheme.accentCyan,
        'icon': Icons.people_rounded
      },
      {
        'label': 'Outstanding Debt',
        'value': kpiVal(_fmt(debt)),
        'sub': 'Total customer debt',
        'color': EnhancedTheme.errorRed,
        'icon': Icons.money_off_rounded
      },
      {
        'label': 'Inventory Value',
        'value': kpiVal(_fmt(stockValue)),
        'sub': inventoryRpt.whenOrNull(data: (d) => '${d.totalItems} items') ??
            'Across all items',
        'color': EnhancedTheme.accentPurple,
        'icon': Icons.inventory_2_rounded
      },
    ];

    final quickActions = [
      {
        'label': 'POS',
        'icon': Icons.point_of_sale_rounded,
        'color': EnhancedTheme.primaryTeal,
        'route': '/dashboard/pos'
      },
      {
        'label': 'Inventory',
        'icon': Icons.inventory_2_rounded,
        'color': EnhancedTheme.infoBlue,
        'route': '/dashboard/inventory'
      },
      {
        'label': 'Customers',
        'icon': Icons.people_rounded,
        'color': EnhancedTheme.accentPurple,
        'route': '/dashboard/customers'
      },
      {
        'label': 'Reports',
        'icon': Icons.bar_chart_rounded,
        'color': EnhancedTheme.successGreen,
        'route': '/dashboard/reports'
      },
      {
        'label': 'Wholesale',
        'icon': Icons.store_rounded,
        'color': EnhancedTheme.accentCyan,
        'route': '/wholesale-dashboard'
      },
      {
        'label': 'More',
        'icon': Icons.more_horiz_rounded,
        'color': EnhancedTheme.primaryTeal,
        'route': ''
      },
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),

          // Decorative background elements
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.errorRed.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
              child: Column(children: [
            // ── Header ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Icon(Icons.menu_rounded,
                        color: context.iconOnBg, size: 22),
                  ),
                ),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Admin Dashboard',
                          style: GoogleFonts.outfit(
                              color: context.labelColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      Row(children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: EnhancedTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Welcome back, ${user?.role ?? 'Admin'}',
                            style: TextStyle(
                                color: context.hintColor, fontSize: 12)),
                      ]),
                    ])),
                _buildProfileMenu(user?.role ?? 'Admin'),
              ]),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KPI grid ─────────────────────────────────────────────────
                    _sectionHeader(context, 'Key Metrics',
                        Icons.analytics_rounded, EnhancedTheme.primaryTeal),
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 960;
                      final isMid = constraints.maxWidth > 600;
                      final cols = isWide ? 6 : isMid ? 3 : 2;
                      final cardPad = isWide ? 10.0 : isMid ? 16.0 : 10.0;
                      final iconSize = isWide ? 15.0 : 18.0;
                      final iconPad = isWide ? 5.0 : 7.0;
                      final valueSize = isWide ? 16.0 : isMid ? 20.0 : 16.0;
                      final labelSize = isWide ? 10.0 : 11.0;
                      final subSize = isWide ? 8.0 : 9.0;
                      final radius = isWide ? 14.0 : 20.0;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: isWide ? 1.3 : isMid ? 1.4 : 1.0),
                        itemCount: kpis.length,
                        itemBuilder: (_, i) {
                          final k = kpis[i];
                          final color = k['color'] as Color;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: EdgeInsets.all(cardPad),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      color.withValues(alpha: 0.15),
                                      color.withValues(alpha: 0.04),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(radius),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: color.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(iconPad),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(k['icon'] as IconData,
                                            color: color, size: iconSize),
                                      ),
                                      const Spacer(),
                                      isLoading
                                          ? SizedBox(
                                              height: 6,
                                              child: LinearProgressIndicator(
                                                  color: color,
                                                  backgroundColor: color
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(3)))
                                          : Text(k['value'] as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                  color: color,
                                                  fontSize: valueSize,
                                                  fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 2),
                                      Text(k['label'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: context.labelColor,
                                              fontSize: labelSize,
                                              fontWeight: FontWeight.w600)),
                                      Text(k['sub'] as String,
                                          style: TextStyle(
                                              color: context.hintColor,
                                              fontSize: subSize),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ]),
                              ),
                            ),
                          )
                              .animate(delay: (i * 50).ms)
                              .fadeIn(duration: 350.ms)
                              .scale(begin: const Offset(0.92, 0.92));
                        },
                      );
                    }),
                    const SizedBox(height: 24),

                    // ── Quick actions ─────────────────────────────────────────────
                    _sectionHeader(context, 'Quick Actions',
                        Icons.flash_on_rounded, EnhancedTheme.accentOrange),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 960
                                  ? 6
                                  : MediaQuery.of(context).size.width > 600
                                      ? 4
                                      : 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              MediaQuery.of(context).size.width > 960
                                  ? 1.0
                                  : 0.85),
                      itemCount: quickActions.length,
                      itemBuilder: (_, i) {
                        final a = quickActions[i];
                        final color = a['color'] as Color;
                        return GestureDetector(
                          onTap: () {
                            final route = a['route'] as String;
                            if (route.isEmpty) {
                              _showMoreSheet();
                            } else {
                              context.push(route);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      color.withValues(alpha: 0.14),
                                      color.withValues(alpha: 0.04)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(a['icon'] as IconData,
                                            color: color, size: 24),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(a['label'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                              ),
                            ),
                          ),
                        )
                            .animate(delay: (i * 40).ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.15, end: 0);
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Inventory by Store ────────────────────────────────────────
                    Row(children: [
                      Expanded(
                          child: _sectionHeader(
                              context,
                              'Inventory by Store',
                              Icons.inventory_2_rounded,
                              EnhancedTheme.infoBlue)),
                      TextButton.icon(
                        onPressed: () => context.push('/dashboard/inventory'),
                        icon: const Icon(Icons.open_in_new_rounded,
                            size: 13, color: EnhancedTheme.infoBlue),
                        label: const Text('Manage',
                            style: TextStyle(
                                color: EnhancedTheme.infoBlue, fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _invStoreCard(context, 'Retail',
                              retailInvAsync, EnhancedTheme.primaryTeal)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _invStoreCard(context, 'Wholesale',
                              wholesaleInvAsync, EnhancedTheme.accentCyan)),
                    ]),
                    ..._buildStockAlerts(
                        context, retailInvAsync, wholesaleInvAsync),
                    const SizedBox(height: 24),

                    // ── Top Items Today ───────────────────────────────────────────
                    _sectionHeader(context, 'Top Items Today',
                        Icons.leaderboard_rounded, EnhancedTheme.successGreen),
                    const SizedBox(height: 12),
                    salesToday.when(
                      loading: () => const Center(
                          child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.primaryTeal),
                      )),
                      error: (e, _) => _infoTile(
                          'Failed to load sales data', EnhancedTheme.errorRed),
                      data: (report) {
                        if (report.topItems.isEmpty) {
                          return _infoTile(
                              'No sales recorded today', context.hintColor);
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Column(
                                children: report.topItems
                                    .take(5)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((e) {
                                  final rank = e.key + 1;
                                  final rankColors = [
                                    EnhancedTheme.warningAmber,
                                    const Color(0xFFB0B0B0),
                                    const Color(0xFFCD7F32),
                                  ];
                                  final rankColor = rank <= 3
                                      ? rankColors[rank - 1]
                                      : context.hintColor;
                                  return Column(children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 13),
                                      child: Row(children: [
                                        // Rank badge
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: rankColor.withValues(
                                                alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text('$rank',
                                                style: TextStyle(
                                                    color: rankColor,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  EnhancedTheme.primaryTeal
                                                      .withValues(alpha: 0.2),
                                                  EnhancedTheme.accentCyan
                                                      .withValues(alpha: 0.1),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: const Icon(
                                              Icons.medication_rounded,
                                              color: EnhancedTheme.primaryTeal,
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(e.value.name,
                                                  style: GoogleFonts.outfit(
                                                      color: context.labelColor,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              Text('${e.value.qty} units sold',
                                                  style: TextStyle(
                                                      color:
                                                          context.subLabelColor,
                                                      fontSize: 11)),
                                            ])),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(_fmt(e.value.revenue),
                                                  style: GoogleFonts.outfit(
                                                      color: EnhancedTheme
                                                          .successGreen,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ]),
                                      ]),
                                    ),
                                    if (e.key < report.topItems.length - 1 &&
                                        e.key < 4)
                                      Divider(
                                          height: 1,
                                          color: context.dividerColor,
                                          indent: 16,
                                          endIndent: 16),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ]),
            )),
          ])),
        ],
      ),
    );
  }

  Widget _sectionHeader(
          BuildContext context, String title, IconData icon, Color color) =>
      Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.outfit(
                  color: context.labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      );

  // ── Profile dropdown ──────────────────────────────────────────────────────

  Widget _buildProfileMenu(String role) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFF1E293B),
      onSelected: (val) {
        switch (val) {
          case 'settings':
            context.go('/admin-dashboard/settings');
            break;
          case 'retail':
            context.go('/dashboard');
            break;
          case 'wholesale':
            context.go('/wholesale-dashboard');
            break;
          case 'reports':
            context.go('/dashboard/reports');
            break;
          case 'more':
            _showMoreSheet();
            break;
          case 'logout':
            _logout();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
            enabled: false,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: EnhancedTheme.errorRed, width: 2),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      EnhancedTheme.errorRed.withValues(alpha: 0.15),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: EnhancedTheme.errorRed, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(role,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Text('Admin Dashboard',
                    style: TextStyle(color: Colors.black38, fontSize: 11)),
              ]),
            ])),
        const PopupMenuDivider(),
        _menuItem('settings', Icons.settings_outlined, 'Settings'),
        _menuItem('reports', Icons.bar_chart_outlined, 'Reports'),
        _menuItem('retail', Icons.storefront_outlined, 'Retail Dashboard'),
        _menuItem('wholesale', Icons.store_outlined, 'Wholesale Dashboard'),
        _menuItem('more', Icons.more_horiz_rounded, 'More Features'),
        const PopupMenuDivider(),
        _menuItem('logout', Icons.logout_rounded, 'Sign Out',
            color: EnhancedTheme.errorRed),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: EnhancedTheme.errorRed, width: 2),
          boxShadow: [
            BoxShadow(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.15),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: EnhancedTheme.errorRed, size: 20),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) {
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

  Widget _infoTile(String msg, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 12),
          Text(msg, style: TextStyle(color: color, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _invStoreCard(BuildContext context, String storeLabel,
      AsyncValue<List<Item>> async, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.12),
                color.withValues(alpha: 0.04)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: async.when(
            loading: () => SizedBox(
              height: 70,
              child: Center(
                  child: LinearProgressIndicator(
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3))),
            ),
            error: (_, __) => Text('Error',
                style: TextStyle(color: context.hintColor, fontSize: 12)),
            data: (items) {
              final total = items.length;
              final lowStock = items
                  .where((i) => i.stock > 0 && i.stock <= i.lowStockThreshold)
                  .length;
              final outStock = items.where((i) => i.stock == 0).length;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory_2_rounded,
                            color: color, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(storeLabel,
                          style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _invStat(context, '$total', 'Items', color),
                          _invStat(context, '$lowStock', 'Low',
                              EnhancedTheme.warningAmber),
                          _invStat(context, '$outStock', 'Out',
                              EnhancedTheme.errorRed),
                        ]),
                  ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _invStat(
          BuildContext context, String value, String label, Color color) =>
      Column(children: [
        Text(value,
            style: GoogleFonts.outfit(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(
                color: context.hintColor,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]);

  List<Widget> _buildStockAlerts(
      BuildContext context,
      AsyncValue<List<Item>> retailAsync,
      AsyncValue<List<Item>> wholesaleAsync) {
    final retail = retailAsync.valueOrNull ?? [];
    final wholesale = wholesaleAsync.valueOrNull ?? [];
    final alerts = [
      ...retail
          .where((i) => i.stock == 0 || i.stock <= i.lowStockThreshold)
          .map((i) => (item: i, store: 'Retail')),
      ...wholesale
          .where((i) => i.stock == 0 || i.stock <= i.lowStockThreshold)
          .map((i) => (item: i, store: 'Wholesale')),
    ]..sort((a, b) => a.item.stock.compareTo(b.item.stock));

    if (alerts.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      ...alerts.take(4).map(
        (a) {
          final alertColor = a.item.stock == 0
              ? EnhancedTheme.errorRed
              : EnhancedTheme.warningAmber;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: alertColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    a.item.stock == 0
                        ? Icons.remove_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: alertColor,
                    size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(a.item.name,
                      style: TextStyle(
                          color: context.labelColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: (a.store == 'Wholesale'
                            ? EnhancedTheme.accentCyan
                            : EnhancedTheme.primaryTeal)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(a.store,
                    style: TextStyle(
                        color: a.store == 'Wholesale'
                            ? EnhancedTheme.accentCyan
                            : EnhancedTheme.primaryTeal,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(a.item.stock == 0 ? 'Out' : '${a.item.stock} left',
                    style: TextStyle(
                        color: alertColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          );
        },
      ),
    ];
  }
}

// ── More Features Bottom Sheet ────────────────────────────────────────────────

class _AdminMoreSheet extends StatelessWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const _AdminMoreSheet({required this.onNavigate, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
                top: BorderSide(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                    width: 1.5)),
          ),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 36),
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 22),
            Row(children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      EnhancedTheme.primaryTeal,
                      EnhancedTheme.accentCyan
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text('More Features',
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),
            _sectionLabel(context, 'Reports', Icons.analytics_outlined,
                EnhancedTheme.successGreen),
            const SizedBox(height: 10),
            Row(children: [
              _card(context, Icons.show_chart, 'Sales',
                  EnhancedTheme.successGreen, '/dashboard/reports/sales'),
              const SizedBox(width: 10),
              _card(context, Icons.inventory_2_outlined, 'Inventory',
                  EnhancedTheme.infoBlue, '/dashboard/reports/inventory'),
              const SizedBox(width: 10),
              _card(context, Icons.people_outline, 'Customers',
                  EnhancedTheme.accentPurple, '/dashboard/reports/customers'),
              const SizedBox(width: 10),
              _card(context, Icons.trending_up, 'Profit',
                  EnhancedTheme.warningAmber, '/dashboard/reports/profit'),
            ]),
            const SizedBox(height: 22),
            _sectionLabel(context, 'Navigate', Icons.navigation_outlined,
                EnhancedTheme.infoBlue),
            const SizedBox(height: 10),
            Row(children: [
              _card(context, Icons.storefront_outlined, 'Retail',
                  EnhancedTheme.primaryTeal, '/dashboard'),
              const SizedBox(width: 10),
              _card(context, Icons.store_outlined, 'Wholesale',
                  EnhancedTheme.accentCyan, '/wholesale-dashboard'),
              const SizedBox(width: 10),
              _card(context, Icons.point_of_sale_outlined, 'POS',
                  EnhancedTheme.successGreen, '/dashboard/pos'),
              const SizedBox(width: 10),
              _card(context, Icons.settings_outlined, 'Settings',
                  context.subLabelColor, '/admin-dashboard/settings'),
            ]),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EnhancedTheme.errorRed.withValues(alpha: 0.15),
                      EnhancedTheme.errorRed.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.4),
                      width: 1.5),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout_rounded,
                      color: EnhancedTheme.errorRed, size: 18),
                  const SizedBox(width: 10),
                  Text('Sign Out',
                      style: GoogleFonts.outfit(
                          color: EnhancedTheme.errorRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ]),
              ),
            ),
          ])),
        ),
      ),
    );
  }

  Widget _sectionLabel(
          BuildContext context, String label, IconData icon, Color color) =>
      Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0)),
        ],
      );

  Widget _card(BuildContext context, IconData icon, String label, Color color,
      String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onNavigate(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.14),
                color.withValues(alpha: 0.04)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
