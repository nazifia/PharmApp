import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/offline/sync_service.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/features/customers/providers/customer_provider.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly preload inventory and customers so POS/Stock/Customer screens
    // are ready instantly when navigated to.
    ref.watch(inventoryListProvider);
    ref.watch(customerListProvider);

    final user        = ref.watch(currentUserProvider);
    final role        = user?.role ?? '';
    final isAdmin     = role == 'Admin' || role == 'Manager';
    final isWholesale = role.contains('Wholesale') || (user?.isWholesaleOperator ?? false);
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final location    = GoRouterState.of(context).matchedLocation;
    final isOnline    = ref.watch(isOnlineProvider);
    final pending     = ref.watch(offlineQueueProvider);

    // Auto-sync when coming back online
    ref.listen<bool>(isOnlineProvider, (wasOnline, nowOnline) async {
      if (nowOnline && !(wasOnline ?? true)) {
        final result = await ref.read(syncServiceProvider).syncAll();
        if (result.hasWork && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: (result.failed == 0 ? EnhancedTheme.successGreen : EnhancedTheme.warningAmber).withValues(alpha: 0.92),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            content: Row(children: [
              Icon(
                result.failed == 0 ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                color: Colors.black, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(result.failed == 0
                  ? '${result.synced} offline sale${result.synced == 1 ? '' : 's'} synced successfully'
                  : '${result.synced} synced, ${result.failed} still pending',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
            ]),
          ));
        }
      }
    });

    final homeRoute = isAdmin
        ? '/admin-dashboard'
        : isWholesale
            ? '/wholesale-dashboard'
            : '/dashboard';

    final posRoute = isWholesale
        ? '/dashboard/wholesale-pos'
        : '/dashboard/pos';

    final selectedIndex = _getSelectedIndex(location, homeRoute);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        // ── Offline banner ──────────────────────────────────────────────────
        if (!isOnline)
          _OfflineBanner(pendingCount: pending.length),
        Expanded(child: child),
      ]),
      bottomNavigationBar: _AppBottomNav(
        selectedIndex: selectedIndex,
        isDark: isDark,
        homeRoute: homeRoute,
        posRoute: posRoute,
        pendingCount: pending.length,
        onMoreTap: () => _showMoreSheet(context, ref, isAdmin, isWholesale),
      ),
    );
  }

  /// Returns the correct home route for the current user's role.
  /// Use this as the fallback when [context.canPop()] is false.
  static String roleFallback(WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final role = user?.role ?? '';
    if (role == 'Admin' || role == 'Manager') return '/admin-dashboard';
    if (role.contains('Wholesale') || (user?.isWholesaleOperator ?? false)) {
      return '/wholesale-dashboard';
    }
    return '/dashboard';
  }

  static int _getSelectedIndex(String location, String homeRoute) {
    if (location == homeRoute ||
        location == '/dashboard' ||
        location == '/admin-dashboard' ||
        location == '/wholesale-dashboard') { return 0; }
    if (location.contains('/pos')) { return 1; }
    if (location.contains('/inventory') || location.contains('/stock')) { return 2; }
    if (location.contains('/customer')) { return 3; }
    return -1; // detail / misc screens — no tab highlighted
  }

  static void _showMoreSheet(
      BuildContext context, WidgetRef ref, bool isAdmin, bool isWholesale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _MoreSheet(isAdmin: isAdmin, isWholesale: isWholesale, ref: ref),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final int pendingCount;
  const _OfflineBanner({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: EnhancedTheme.warningAmber,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.black, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(
          pendingCount > 0
              ? 'Offline — $pendingCount sale${pendingCount == 1 ? '' : 's'} queued for sync'
              : 'Offline — changes will sync when connected',
          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
        )),
      ]),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final bool isDark;
  final String homeRoute;
  final String posRoute;
  final int pendingCount;
  final VoidCallback onMoreTap;

  const _AppBottomNav({
    required this.selectedIndex,
    required this.isDark,
    required this.homeRoute,
    required this.posRoute,
    required this.pendingCount,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.home_outlined,          Icons.home_rounded,          'Home',      homeRoute),
      _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'POS',       posRoute),
      _NavItem(Icons.inventory_2_outlined,   Icons.inventory_2_rounded,   'Stock',     '/dashboard/inventory'),
      _NavItem(Icons.people_outline,         Icons.people_rounded,        'Customers', '/dashboard/customers'),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  ...items.asMap().entries.map((e) {
                    final idx  = e.key;
                    final item = e.value;
                    final sel  = selectedIndex == idx;
                    // POS is index 1 — show pending badge there
                    final badge = (idx == 1 && pendingCount > 0) ? pendingCount : 0;
                    return Expanded(
                      child: _NavBtn(
                        icon:       sel ? item.activeIcon : item.icon,
                        label:      item.label,
                        isSelected: sel,
                        badgeCount: badge,
                        onTap:      () => context.go(item.route),
                      ),
                    );
                  }),
                  Expanded(
                    child: _NavBtn(
                      icon:       Icons.grid_view_rounded,
                      label:      'More',
                      isSelected: false,
                      onTap:      onMoreTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _NavItem data class ───────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final String   route;
  const _NavItem(this.icon, this.activeIcon, this.label, this.route);
}

// ── _NavBtn widget ────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isSelected;
  final int      badgeCount;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = isSelected
        ? EnhancedTheme.primaryTeal
        : (isDark ? Colors.white54 : Colors.black45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EnhancedTheme.primaryTeal.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(icon, key: ValueKey(icon), color: color, size: 22),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -5, right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: EnhancedTheme.warningAmber,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color:      color,
                  fontSize:   10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── More Bottom Sheet ─────────────────────────────────────────────────────────

class _MoreSheet extends StatelessWidget {
  final bool       isAdmin;
  final bool       isWholesale;
  final WidgetRef  ref;

  const _MoreSheet({
    required this.isAdmin,
    required this.isWholesale,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void nav(String route) {
      Navigator.pop(context);
      context.go(route);
    }

    void logout() {
      Navigator.pop(context);
      ref.read(authServiceProvider).logout();
      context.go('/login');
    }

    final tiles = [
      _MoreTile(Icons.analytics_rounded,              'Reports',     EnhancedTheme.accentPurple,  () => nav('/dashboard/reports')),
      _MoreTile(Icons.receipt_long_rounded,           'Sales',       EnhancedTheme.primaryTeal,   () => nav('/dashboard/sales')),
      _MoreTile(Icons.account_balance_wallet_rounded, 'Expenses',    EnhancedTheme.accentOrange,  () => nav('/dashboard/expenses')),
      _MoreTile(Icons.request_page_rounded,           'Payments',    EnhancedTheme.infoBlue,      () => nav('/dashboard/payment-requests')),
      _MoreTile(Icons.storefront_rounded,             'Suppliers',   EnhancedTheme.successGreen,  () => nav('/dashboard/suppliers')),
      _MoreTile(Icons.fact_check_rounded,             'Stock Check', EnhancedTheme.warningAmber,  () => nav('/dashboard/stock-check')),
      if (isWholesale) ...[
        _MoreTile(Icons.store_rounded,                'WS Sales',    EnhancedTheme.accentCyan,    () => nav('/dashboard/wholesale-sales')),
        _MoreTile(Icons.swap_horiz_rounded,           'Transfers',   EnhancedTheme.accentPurple,  () => nav('/dashboard/transfers')),
      ],
      if (isAdmin) ...[
        _MoreTile(Icons.people_alt_rounded,           'Users',       EnhancedTheme.primaryTeal,   () => nav('/dashboard/users')),
        _MoreTile(Icons.notifications_rounded,        'Alerts',      EnhancedTheme.errorRed,      () => nav('/dashboard/notifications')),
      ],
      _MoreTile(Icons.settings_rounded,               'Settings',    isDark ? Colors.white54 : Colors.black54,  () => nav('/dashboard/settings')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Tile grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles.map((t) => _MoreTileWidget(tile: t, isDark: isDark)).toList(),
              ),

              const SizedBox(height: 16),
              Divider(color: isDark ? Colors.white12 : Colors.black12),
              const SizedBox(height: 8),

              // Logout
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: logout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: EnhancedTheme.errorRed, size: 18),
                        SizedBox(width: 8),
                        Text('Sign Out',
                            style: TextStyle(
                                color: EnhancedTheme.errorRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _MoreTile(this.icon, this.label, this.color, this.onTap);
}

class _MoreTileWidget extends StatelessWidget {
  final _MoreTile tile;
  final bool      isDark;
  const _MoreTileWidget({required this.tile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 40 - 10 * 3) / 4;
    return SizedBox(
      width: w,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: tile.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: tile.color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tile.color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Icon(tile.icon, color: tile.color, size: 24),
                const SizedBox(height: 6),
                Text(
                  tile.label,
                  style: TextStyle(
                    color:      isDark ? Colors.white70 : Colors.black87,
                    fontSize:   11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign:  TextAlign.center,
                  maxLines:   2,
                  overflow:   TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
