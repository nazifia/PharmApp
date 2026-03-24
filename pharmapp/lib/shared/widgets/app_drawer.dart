import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final Set<String> _expanded = {};

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user        = ref.watch(currentUserProvider);
    final role        = user?.role ?? '';
    final isAdmin     = role == 'Admin' || role == 'Manager';
    final isWholesale = role.contains('Wholesale') || (user?.isWholesaleOperator ?? false) || isAdmin;
    final isDark      = context.isDark;
    final notifCount  = ref.watch(notificationCountProvider).valueOrNull ?? 0;

    void navigate(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    void logout() {
      Navigator.of(context).pop();
      ref.read(authServiceProvider).logout();
      context.go('/login');
    }

    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.97)
                  : const Color(0xFFE2E8F0).withValues(alpha: 0.97),
              border: Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Profile header ─────────────────────────────────────────
                  _DrawerHeader(
                    role: role,
                    username: user?.username ?? '',
                    phoneNumber: user?.phoneNumber ?? '',
                    orgName: ref.watch(currentOrganizationProvider)?.name ?? '',
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),

                  // ── Nav items ──────────────────────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      children: [
                        // ══ DASHBOARD ═════════════════════════════════════════
                        _NavItem(icon: Icons.home_rounded, label: 'Dashboard', route: AppShell.roleFallback(ref), onTap: navigate),

                        const SizedBox(height: 4),
                        _SectionDivider(label: 'Operations'),

                        // ══ DISPENSING ═════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.medication_rounded, label: 'Dispensing',
                          isExpanded: _expanded.contains('dispensing'),
                          onToggle: () => _toggle('dispensing'),
                          children: [
                            _SubNavItem(icon: Icons.point_of_sale_rounded, label: 'Retail Dispense', route: '/dashboard/pos', onTap: navigate),
                            if (isWholesale)
                              _SubNavItem(icon: Icons.store_rounded, label: 'Wholesale Dispense', route: '/dashboard/wholesale-pos', onTap: navigate),
                          ],
                        ),

                        // ══ CUSTOMERS ═════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.people_rounded, label: 'Customers',
                          isExpanded: _expanded.contains('customers'),
                          onToggle: () => _toggle('customers'),
                          children: [
                            _SubNavItem(icon: Icons.list_rounded, label: 'Customer List', route: '/dashboard/customers', onTap: navigate),
                          ],
                        ),

                        // ══ PAYMENTS ═════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.credit_card_rounded, label: 'Payments',
                          isExpanded: _expanded.contains('payments'),
                          onToggle: () => _toggle('payments'),
                          children: [
                            _SubNavItem(icon: Icons.request_page_rounded, label: 'Payment Requests', route: '/dashboard/payment-requests', onTap: navigate),
                          ],
                        ),

                        // ══ SALES ═════════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.receipt_long_rounded, label: 'Sales',
                          isExpanded: _expanded.contains('sales'),
                          onToggle: () => _toggle('sales'),
                          children: [
                            _SubNavItem(icon: Icons.history_rounded, label: 'Sales History', route: '/dashboard/sales', onTap: navigate),
                            _SubNavItem(icon: Icons.list_alt_rounded, label: 'Dispensing Log', route: '/dashboard/dispensing-log', onTap: navigate),
                            if (isWholesale)
                              _SubNavItem(icon: Icons.store_rounded, label: 'Wholesale Sales', route: '/dashboard/wholesale-sales', onTap: navigate),
                          ],
                        ),

                        // ══ WHOLESALE ─────────────────────────────────────────
                        if (isWholesale) ...[
                          const SizedBox(height: 4),
                          _SectionDivider(label: 'Wholesale'),
                          _ExpandableSection(
                            icon: Icons.store_rounded, label: 'Wholesale',
                            isExpanded: _expanded.contains('wholesale'),
                            onToggle: () => _toggle('wholesale'),
                            children: [
                              _SubNavItem(icon: Icons.dashboard_rounded, label: 'WS Dashboard', route: '/wholesale-dashboard', onTap: navigate),
                              _SubNavItem(icon: Icons.point_of_sale_rounded, label: 'WS POS', route: '/dashboard/wholesale-pos', onTap: navigate),
                              _SubNavItem(icon: Icons.receipt_long_rounded, label: 'WS Sales', route: '/dashboard/wholesale-sales', onTap: navigate),
                              _SubNavItem(icon: Icons.swap_horiz_rounded, label: 'Transfers', route: '/dashboard/transfers', onTap: navigate),
                              _SubNavItem(icon: Icons.inventory_rounded, label: 'Adjust WS Stock', route: '/dashboard/inventory', onTap: navigate),
                              _SubNavItem(icon: Icons.warning_amber_rounded, label: 'Low Stock Alerts', route: '/dashboard/inventory', onTap: navigate),
                              _SubNavItem(icon: Icons.hourglass_bottom_rounded, label: 'Expiry Alerts', route: '/dashboard/inventory', onTap: navigate),
                              _SubNavItem(icon: Icons.fact_check_rounded, label: 'WS Stock Check', route: '/dashboard/stock-check', onTap: navigate),
                              _SubNavItem(icon: Icons.star_rounded, label: 'Top Products', route: '/wholesale-dashboard', onTap: navigate),
                              _SubNavItem(icon: Icons.account_balance_wallet_rounded, label: 'Inventory Value', route: '/wholesale-dashboard', onTap: navigate),
                            ],
                          ),
                        ],

                        const SizedBox(height: 4),
                        _SectionDivider(label: 'Inventory'),

                        // ══ INVENTORY ═════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.inventory_2_rounded, label: 'Inventory',
                          isExpanded: _expanded.contains('inventory'),
                          onToggle: () => _toggle('inventory'),
                          children: [
                            _SubNavItem(icon: Icons.inventory_rounded, label: 'Item List', route: '/dashboard/inventory', onTap: navigate),
                            _SubNavItem(icon: Icons.checklist_rtl_rounded, label: 'Stock Check', route: '/dashboard/stock-check', onTap: navigate),
                            if (isWholesale) ...[
                              _SubNavItem(icon: Icons.swap_horiz_rounded, label: 'Transfers', route: '/dashboard/transfers', onTap: navigate),
                              _SubNavItem(icon: Icons.warning_amber_rounded, label: 'Low Stock Alert', route: '/dashboard/inventory', onTap: navigate),
                              _SubNavItem(icon: Icons.timer_rounded, label: 'Expiry Alerts', route: '/dashboard/inventory', onTap: navigate),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),
                        _SectionDivider(label: 'Reports & Analytics'),

                        // ══ REPORTS ═══════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.analytics_rounded, label: 'Reports',
                          isExpanded: _expanded.contains('reports'),
                          onToggle: () => _toggle('reports'),
                          children: [
                            _SubNavItem(icon: Icons.show_chart_rounded, label: 'Sales Report', route: '/dashboard/reports/sales', onTap: navigate),
                            _SubNavItem(icon: Icons.inventory_2_outlined, label: 'Inventory Report', route: '/dashboard/reports/inventory', onTap: navigate),
                            _SubNavItem(icon: Icons.people_outline, label: 'Customer Report', route: '/dashboard/reports/customers', onTap: navigate),
                            _SubNavItem(icon: Icons.trending_up_rounded, label: 'Profit Report', route: '/dashboard/reports/profit', onTap: navigate),
                            _SubNavItem(icon: Icons.calendar_month_rounded, label: 'Monthly Report', route: '/dashboard/reports/monthly', onTap: navigate),
                            if (isWholesale)
                              _SubNavItem(icon: Icons.store_rounded, label: 'Wholesale Sales', route: '/dashboard/wholesale-sales', onTap: navigate),
                          ],
                        ),

                        const SizedBox(height: 4),
                        _SectionDivider(label: 'Finance'),

                        // ══ FINANCE ═══════════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.attach_money_rounded, label: 'Finance',
                          isExpanded: _expanded.contains('finance'),
                          onToggle: () => _toggle('finance'),
                          children: [
                            _SubNavItem(icon: Icons.account_balance_wallet_rounded, label: 'Expenses', route: '/dashboard/expenses', onTap: navigate),
                          ],
                        ),

                        const SizedBox(height: 4),
                        _SectionDivider(label: 'Procurement'),

                        // ══ PROCUREMENT ═══════════════════════════════════════
                        _ExpandableSection(
                          icon: Icons.local_shipping_rounded, label: 'Procurement',
                          isExpanded: _expanded.contains('procurement'),
                          onToggle: () => _toggle('procurement'),
                          children: [
                            _SubNavItem(icon: Icons.storefront_rounded, label: 'Suppliers', route: '/dashboard/suppliers', onTap: navigate),
                          ],
                        ),

                        // ══ ADMIN ═════════════════════════════════════════════
                        if (isAdmin) ...[
                          const SizedBox(height: 4),
                          _SectionDivider(label: 'Administration'),
                          _ExpandableSection(
                            icon: Icons.admin_panel_settings_rounded, label: 'Admin',
                            isExpanded: _expanded.contains('admin'),
                            onToggle: () => _toggle('admin'),
                            children: [
                              _SubNavItem(icon: Icons.people_alt_rounded, label: 'User Management', route: '/dashboard/users', onTap: navigate),
                              _SubNavItem(icon: Icons.notifications_rounded, label: 'Notifications', route: '/dashboard/notifications', onTap: navigate, badge: notifCount),
                              _SubNavItem(icon: Icons.settings_rounded, label: 'Settings', route: '/dashboard/settings', onTap: navigate),
                            ],
                          ),
                        ],

                      ],
                    ),
                  ),

                  // ── Footer ─────────────────────────────────────────────────
                  Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    child: _LogoutTile(onLogout: logout),
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

// ── Notification count provider ────────────────────────────────────────────────

final notificationCountProvider = FutureProvider<int>((ref) async {
  try {
    return await ref.read(posApiProvider).fetchNotificationCount();
  } catch (_) {
    return 0;
  }
});

// ── Profile Header ────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final String role;
  final String username;
  final String phoneNumber;
  final String orgName;
  const _DrawerHeader({required this.role, required this.username, required this.phoneNumber, required this.orgName});

  @override
  Widget build(BuildContext context) {
    final displayName = username.isNotEmpty ? username : phoneNumber;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayName.isNotEmpty ? displayName : 'User',
                style: TextStyle(
                    color: context.labelColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
                overflow: TextOverflow.ellipsis),
            if (username.isNotEmpty && phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(phoneNumber,
                  style: TextStyle(color: context.subLabelColor, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Active',
                  style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            if (orgName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.business_rounded, size: 11, color: EnhancedTheme.accentCyan),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(orgName,
                      style: TextStyle(color: context.subLabelColor, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Section Divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: context.hintColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

// ── Expandable Section ────────────────────────────────────────────────────────

class _ExpandableSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _ExpandableSection({
    required this.icon,
    required this.label,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(icon, color: context.labelColor.withValues(alpha: 0.75), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(label,
                    style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500))),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, color: context.hintColor, size: 20)),
              ]),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: children),
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ── Sub Nav Item ──────────────────────────────────────────────────────────────

class _SubNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final void Function(String) onTap;
  final int? badge;

  const _SubNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final active = GoRouterState.of(context).matchedLocation == route ||
        GoRouterState.of(context).matchedLocation.startsWith('$route/');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onTap(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(children: [
              Icon(icon,
                  color: active ? EnhancedTheme.primaryTeal : context.labelColor.withValues(alpha: 0.6),
                  size: 17),
              const SizedBox(width: 10),
              Expanded(child: Text(label,
                  style: TextStyle(
                      color: active ? EnhancedTheme.primaryTeal : context.labelColor.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
              if (badge != null && badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Nav Item (Top Level) ──────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final void Function(String) onTap;
  final Color? color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c      = color ?? context.labelColor;
    final active = GoRouterState.of(context).matchedLocation == route ||
        GoRouterState.of(context).matchedLocation.startsWith('$route/');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(children: [
              Icon(icon,
                  color: active ? EnhancedTheme.primaryTeal : c.withValues(alpha: 0.75),
                  size: 20),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: active ? EnhancedTheme.primaryTeal : c,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
              if (active) ...[
                const Spacer(),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: EnhancedTheme.primaryTeal,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Logout Tile ───────────────────────────────────────────────────────────────

class _LogoutTile extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutTile({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.25)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: EnhancedTheme.errorRed, size: 18),
            SizedBox(width: 10),
            Text('Sign Out',
                style: TextStyle(
                    color: EnhancedTheme.errorRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}
