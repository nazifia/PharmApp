import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/offline/sync_service.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/features/customers/providers/customer_provider.dart';
import 'package:pharmapp/features/pos/screens/sales_history_screen.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/features/reports/providers/reports_provider.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();

  /// Returns the correct home route for the current user's role.
  static String roleFallback(WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final role = user?.role ?? '';
    if (role == 'Admin' || role == 'Manager') return '/admin-dashboard';
    if (role.contains('Wholesale') || (user?.isWholesaleOperator ?? false)) {
      return '/wholesale-dashboard';
    }
    return '/dashboard';
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

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {

  /// Periodic fallback timer — retries sync every 30 s while items are queued.
  /// Handles environments where connectivity_plus cannot detect that the
  /// *server* came back (e.g. local dev with Django stopped/restarted, or
  /// platforms where OS-level network events are unreliable such as web/Windows).
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sync on startup: runs after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
    _startRetryTimer();
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncIfNeeded();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Triggered when the app returns to the foreground from the background.
  /// Handles the case where connectivity was restored while the app was
  /// backgrounded and no stream event will fire on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncIfNeeded();
    }
  }

  /// Sync pending offline items if the device is online.
  /// [delayMs] adds a stabilisation pause so the connection is ready.
  Future<void> _syncIfNeeded({int delayMs = 0}) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (!mounted) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) return;

    // NOTE: intentionally do NOT short-circuit on empty queue here.
    // On startup, OfflineQueueNotifier._reload() is async — the queue state
    // may still be [] even though SharedPreferences has items. syncAll() reads
    // the queue at call time and fast-exits when empty (no network calls made).
    // Checking hasPending here would cause a race-condition false-negative that
    // silently skips the sync until the 30-second timer fires.

    final result = await ref.read(syncServiceProvider).syncAll();
    if (!mounted) return;

    if (result.synced > 0) {
      ref.invalidate(salesListProvider);
      ref.invalidate(offlineSalesProvider);
      ref.invalidate(salesReportProvider);
      ref.invalidate(profitReportProvider);
      ref.invalidate(inventoryReportProvider);
      ref.invalidate(customerReportProvider);
      ref.invalidate(inventoryListProvider);
      ref.invalidate(retailInventoryProvider);
      ref.invalidate(wholesaleInventoryProvider);
      ref.invalidate(customerListProvider);
    }

    if (result.authExpired) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        content: const Row(children: [
          Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Session expired — please log in again to sync offline data.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
      return;
    }

    if (result.hasWork) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        backgroundColor: (result.failed == 0
                ? EnhancedTheme.successGreen
                : EnhancedTheme.warningAmber)
            .withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Row(children: [
          Icon(
            result.failed == 0
                ? Icons.cloud_done_rounded
                : Icons.cloud_sync_rounded,
            color: Colors.black,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.failed == 0
                  ? '${result.synced} offline operation${result.synced == 1 ? '' : 's'} synced successfully'
                  : '${result.synced} synced, ${result.failed} still pending',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eagerly preload inventory, customers and payment requests so screens
    // are ready instantly when navigated to, and offline reads succeed.
    ref.watch(inventoryListProvider);
    ref.watch(retailInventoryProvider);
    ref.watch(customerListProvider);
    ref.watch(paymentRequestsPreloadProvider);

    final user         = ref.watch(currentUserProvider);
    final role         = user?.role ?? '';
    final isAdmin      = role == 'Admin' || role == 'Manager';
    final isWholesale  = role.contains('Wholesale') || (user?.isWholesaleOperator ?? false);
    final canInventory = Rbac.can(user, AppPermission.readInventory);
    final canCustomers = Rbac.can(user, AppPermission.readCustomers);
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final location     = GoRouterState.of(context).matchedLocation;
    final isOnline     = ref.watch(isOnlineProvider);
    final pendingSales = ref.watch(offlineQueueProvider);
    final pendingMuts  = ref.watch(offlineMutationQueueProvider);
    final pending      = pendingSales.length + pendingMuts.length;

    // Auto-sync on offline→online transition at runtime.
    // Startup and resume cases are handled by _syncIfNeeded() via the
    // lifecycle observer and initState post-frame callback above.
    ref.listen<bool>(isOnlineProvider, (wasOnline, nowOnline) {
      if (!nowOnline || wasOnline == true) return;
      // Wait 1.5 s for the connection to stabilise before attempting sync.
      _syncIfNeeded(delayMs: 1500);
    });

    // Trigger sync when the offline queues finish loading from SharedPreferences
    // on startup (OfflineQueueNotifier._reload() is async — it completes AFTER
    // the first frame, so the initState post-frame callback may see an empty
    // queue even though items are stored on disk). Also triggers immediately
    // when a new item is added to a non-empty queue so that momentarily-offline
    // writes are retried as soon as connectivity is back, without waiting for
    // the 30-second periodic timer.
    ref.listen<List<PendingSale>>(offlineQueueProvider, (previous, next) {
      if (next.isNotEmpty && (previous == null || next.length > previous.length)) {
        _syncIfNeeded();
      }
    });
    ref.listen<List<PendingMutation>>(offlineMutationQueueProvider, (previous, next) {
      if (next.isNotEmpty && (previous == null || next.length > previous.length)) {
        _syncIfNeeded();
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      body: Column(children: [
        if (!isOnline || pending > 0) const _OfflineBanner(),
        Expanded(child: widget.child),
      ]),
      bottomNavigationBar: _AppBottomNav(
        isDark: isDark,
        homeRoute: homeRoute,
        posRoute: posRoute,
        location: location,
        canInventory: canInventory,
        canCustomers: canCustomers,
        pendingCount: pending,
        onMoreTap: () =>
            AppShell._showMoreSheet(context, ref, isAdmin, isWholesale),
      ),
    );
  }
}

// ── Offline / Sync banner ─────────────────────────────────────────────────────

class _OfflineBanner extends ConsumerStatefulWidget {
  const _OfflineBanner();

  @override
  ConsumerState<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<_OfflineBanner> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final isOnline  = ref.watch(isOnlineProvider);
    final pendingSales  = ref.watch(offlineQueueProvider);
    final pendingMuts   = ref.watch(offlineMutationQueueProvider);
    final pending   = pendingSales.length + pendingMuts.length;

    return GestureDetector(
      onTap: isOnline ? _triggerSync : () => context.go('/dashboard/sync-queue'),
      child: Container(
        width: double.infinity,
        color: isOnline ? EnhancedTheme.primaryTeal : EnhancedTheme.warningAmber,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(
            isOnline ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
            color: Colors.black, size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            !isOnline
                ? pending > 0
                    ? 'Offline — $pending operation${pending == 1 ? '' : 's'} queued for sync'
                    : 'Offline — changes will sync when connected'
                : _syncing
                    ? 'Syncing $pending operation${pending == 1 ? '' : 's'}...'
                    : '$pending operation${pending == 1 ? '' : 's'} pending — tap to sync now',
            style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
          )),
          if (_syncing)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.black,
              ),
            )
          else if (isOnline && pending > 0) ...[
            const SizedBox(width: 6),
            const Icon(Icons.sync_rounded, color: Colors.black, size: 16),
          ]
          else if (!isOnline && pending > 0) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.black, size: 16),
          ],
        ]),
      ),
    );
  }

  Future<void> _triggerSync() async {
    if (_syncing) return;

    // Snapshot pending count BEFORE calling syncAll() — if syncAll() returns
    // no work but pendingBefore > 0, it means another sync was already running
    // (SyncService._running guard). Show a "sync in progress" message instead
    // of the misleading "Nothing to sync".
    final pendingSales = ref.read(offlineQueueProvider);
    final pendingMuts  = ref.read(offlineMutationQueueProvider);
    final pendingBefore = pendingSales.length + pendingMuts.length;

    setState(() => _syncing = true);

    final result = await ref.read(syncServiceProvider).syncAll();

    if (!mounted) return;
    setState(() => _syncing = false);

    // Invalidate all data providers so open screens reload fresh data
    if (result.synced > 0) {
      ref.invalidate(salesListProvider);
      ref.invalidate(offlineSalesProvider);
      ref.invalidate(salesReportProvider);
      ref.invalidate(profitReportProvider);
      ref.invalidate(inventoryReportProvider);
      ref.invalidate(customerReportProvider);
      ref.invalidate(inventoryListProvider);
      ref.invalidate(retailInventoryProvider);
      ref.invalidate(wholesaleInventoryProvider);
      ref.invalidate(customerListProvider);
    }

    if (result.hasWork) {
      final msg = result.failed == 0
          ? '${result.synced} offline operation${result.synced == 1 ? '' : 's'} synced successfully'
          : '${result.synced} synced, ${result.failed} still pending';
      final bgColor = result.failed == 0
          ? EnhancedTheme.successGreen
          : EnhancedTheme.warningAmber;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: bgColor.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Row(children: [
          Icon(
            result.failed == 0
                ? Icons.cloud_done_rounded
                : Icons.cloud_sync_rounded,
            color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          )),
        ]),
      ));
    } else if (!mounted) {
      return;
    } else if (pendingBefore > 0) {
      // Sync was blocked by an in-flight auto-sync — inform the user it's
      // already running rather than showing the misleading "Nothing to sync".
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.infoBlue.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: const Row(children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Sync already in progress…',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          )),
        ]),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.infoBlue.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Nothing to sync',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          )),
        ]),
      ));
    }
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _AppBottomNav extends StatelessWidget {
  final bool isDark;
  final String homeRoute;
  final String posRoute;
  final String location;
  final bool canInventory;
  final bool canCustomers;
  final int pendingCount;
  final VoidCallback onMoreTap;

  const _AppBottomNav({
    required this.isDark,
    required this.homeRoute,
    required this.posRoute,
    required this.location,
    required this.canInventory,
    required this.canCustomers,
    required this.pendingCount,
    required this.onMoreTap,
  });

  int _selectedIndex(List<_NavItem> items) {
    // Home tab matches multiple dashboard routes
    if (location == homeRoute ||
        location == '/dashboard' ||
        location == '/admin-dashboard' ||
        location == '/wholesale-dashboard') { return 0; }
    for (int i = 1; i < items.length; i++) {
      final r = items[i].route;
      if (location == r ||
          location.startsWith('$r/') ||
          (r.contains('/pos') && location.contains('/pos')) ||
          (r.contains('/inventory') && (location.contains('/inventory') || location.contains('/stock'))) ||
          (r.contains('/customer') && location.contains('/customer'))) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.home_outlined,          Icons.home_rounded,          'Home',      homeRoute),
      _NavItem(Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'POS',       posRoute),
      if (canInventory)
        const _NavItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded,   'Stock',     '/dashboard/inventory'),
      if (canCustomers)
        const _NavItem(Icons.people_outline,       Icons.people_rounded,        'Customers', '/dashboard/customers'),
    ];
    final selectedIndex = _selectedIndex(items);

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

    final user        = ref.read(currentUserProvider);
    final canReports  = Rbac.can(user, AppPermission.viewReports);
    final canExpenses = Rbac.can(user, AppPermission.manageExpenses);
    final canSuppliers = Rbac.can(user, AppPermission.manageSuppliers);
    final canPayments = Rbac.can(user, AppPermission.processPayments);
    final canTransfers = Rbac.can(user, AppPermission.manageTransfers);
    final canInventory = Rbac.can(user, AppPermission.readInventory);
    final canPOS      = Rbac.can(user, AppPermission.retailPOS);
    final pendingSales = ref.read(offlineQueueProvider);
    final pendingMuts  = ref.read(offlineMutationQueueProvider);
    final pendingTotal = pendingSales.length + pendingMuts.length;

    final tiles = [
      if (canReports)
        _MoreTile(Icons.analytics_rounded,              'Reports',     EnhancedTheme.accentPurple,  () => nav('/dashboard/reports')),
      if (canPOS || isWholesale)
        _MoreTile(Icons.receipt_long_rounded,           'Sales',       EnhancedTheme.primaryTeal,   () => nav('/dashboard/sales')),
      if (canExpenses)
        _MoreTile(Icons.account_balance_wallet_rounded, 'Expenses',    EnhancedTheme.accentOrange,  () => nav('/dashboard/expenses')),
      if (canPayments)
        _MoreTile(Icons.request_page_rounded,           'Payments',    EnhancedTheme.infoBlue,      () => nav('/dashboard/payment-requests')),
      if (canSuppliers)
        _MoreTile(Icons.storefront_rounded,             'Suppliers',   EnhancedTheme.successGreen,  () => nav('/dashboard/suppliers')),
      if (canInventory)
        _MoreTile(Icons.fact_check_rounded,             'Stock Check', EnhancedTheme.warningAmber,  () => nav('/dashboard/stock-check')),
      if (isWholesale) ...[
        _MoreTile(Icons.store_rounded,                  'WS Sales',    EnhancedTheme.accentCyan,    () => nav('/dashboard/wholesale-sales')),
        if (canTransfers)
          _MoreTile(Icons.swap_horiz_rounded,           'Transfers',   EnhancedTheme.accentPurple,  () => nav('/dashboard/transfers')),
      ],
      if (isAdmin) ...[
        _MoreTile(Icons.people_alt_rounded,             'Users',       EnhancedTheme.primaryTeal,   () => nav('/dashboard/users')),
        _MoreTile(Icons.notifications_rounded,          'Alerts',      EnhancedTheme.errorRed,      () => nav('/dashboard/notifications')),
        _MoreTile(Icons.settings_rounded,               'Settings',    isDark ? Colors.white54 : Colors.black54, () => nav('/dashboard/settings')),
      ],
      if (pendingTotal > 0)
        _MoreTile(Icons.cloud_sync_rounded,             'Sync ($pendingTotal)', EnhancedTheme.warningAmber, () => nav('/dashboard/sync-queue')),
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
