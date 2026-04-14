import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/activity_log.dart';
import '../providers/activity_log_provider.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _category = 'all';

  static const _categories = [
    ('all', 'All', Icons.list_rounded),
    ('auth', 'Auth', Icons.lock_rounded),
    ('sales', 'Sales', Icons.point_of_sale_rounded),
    ('inventory', 'Inventory', Icons.inventory_2_rounded),
    ('customers', 'Customers', Icons.people_rounded),
    ('users', 'Users', Icons.manage_accounts_rounded),
    ('settings', 'Settings', Icons.settings_rounded),
    ('reports', 'Reports', Icons.bar_chart_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(activityLogProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'auth':      return EnhancedTheme.infoBlue;
      case 'sales':     return EnhancedTheme.successGreen;
      case 'inventory': return EnhancedTheme.primaryTeal;
      case 'customers': return EnhancedTheme.accentPurple;
      case 'users':     return EnhancedTheme.warningAmber;
      case 'settings':  return EnhancedTheme.accentCyan;
      case 'reports':   return EnhancedTheme.accentOrange;
      default:          return const Color(0xFF64748B);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'auth':      return Icons.lock_rounded;
      case 'sales':     return Icons.point_of_sale_rounded;
      case 'inventory': return Icons.inventory_2_rounded;
      case 'customers': return Icons.people_rounded;
      case 'users':     return Icons.manage_accounts_rounded;
      case 'settings':  return Icons.settings_rounded;
      case 'reports':   return Icons.bar_chart_rounded;
      default:          return Icons.radio_button_unchecked_rounded;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'Admin':                 return Icons.admin_panel_settings_rounded;
      case 'Manager':               return Icons.manage_accounts_rounded;
      case 'Pharmacist':            return Icons.medical_services_rounded;
      case 'Pharm-Tech':            return Icons.science_rounded;
      case 'Cashier':               return Icons.point_of_sale_rounded;
      case 'Salesperson':           return Icons.sell_rounded;
      case 'Wholesale Manager':     return Icons.warehouse_rounded;
      case 'Wholesale Operator':    return Icons.inventory_2_rounded;
      case 'Wholesale Salesperson': return Icons.storefront_rounded;
      default:                      return Icons.person_rounded;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return DateFormat('d MMM, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityLogProvider);
    final notifier = ref.read(activityLogProvider.notifier);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),

          // Decorative circle
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            color: context.iconOnBg, size: 20),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activity Log',
                              style: GoogleFonts.outfit(
                                  color: context.labelColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          Text('User actions & audit trail',
                              style: TextStyle(
                                  color: context.hintColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Refresh button
                    GestureDetector(
                      onTap: () => notifier.fetch(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: EnhancedTheme.accentPurple, size: 20),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1),

                const SizedBox(height: 16),

                // ── Search field ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => notifier.setSearch(v),
                          style: GoogleFonts.inter(
                              color: context.labelColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by user, action, or description…',
                            hintStyle: TextStyle(
                                color: context.hintColor, fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: context.hintColor, size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded,
                                        color: context.hintColor, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      notifier.setSearch('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 50.ms, duration: 300.ms),

                const SizedBox(height: 12),

                // ── Category filter chips ────────────────────────────────────
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final (value, label, icon) = _categories[i];
                      final isActive = _category == value;
                      final color = value == 'all'
                          ? EnhancedTheme.accentPurple
                          : _categoryColor(value);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _category = value);
                          notifier.setCategory(value);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: 0.18)
                                : context.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? color.withValues(alpha: 0.5)
                                  : context.borderColor,
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(icon,
                                size: 14,
                                color: isActive ? color : context.hintColor),
                            const SizedBox(width: 6),
                            Text(label,
                                style: TextStyle(
                                    color: isActive ? color : context.hintColor,
                                    fontSize: 12,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500)),
                          ]),
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

                const SizedBox(height: 12),

                // ── Log list ─────────────────────────────────────────────────
                Expanded(
                  child: state.error != null
                      ? _ErrorView(
                          error: state.error!,
                          onRetry: () => notifier.fetch(),
                        )
                      : state.logs.isEmpty && !state.isLoading
                          ? _EmptyView(category: _category)
                          : RefreshIndicator(
                              color: EnhancedTheme.accentPurple,
                              onRefresh: () => notifier.fetch(),
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                                itemCount: state.logs.length +
                                    (state.isLoading ? 1 : 0) +
                                    (!state.isLoading && state.hasMore ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i == state.logs.length) {
                                    // Loading / load-more indicator
                                    if (state.isLoading) {
                                      return const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                              color: EnhancedTheme.accentPurple,
                                              strokeWidth: 2),
                                        ),
                                      );
                                    }
                                    return TextButton(
                                      onPressed: () => notifier.loadMore(),
                                      child: Text('Load more',
                                          style: TextStyle(
                                              color: EnhancedTheme.accentPurple)),
                                    );
                                  }
                                  return _LogTile(
                                    log: state.logs[i],
                                    categoryColor: _categoryColor(
                                        state.logs[i].category),
                                    categoryIcon: _categoryIcon(
                                        state.logs[i].category),
                                    roleIcon: _roleIcon(state.logs[i].role),
                                    relativeTime:
                                        _relativeTime(state.logs[i].timestamp),
                                    index: i,
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Log tile ──────────────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  final Color categoryColor;
  final IconData categoryIcon;
  final IconData roleIcon;
  final String relativeTime;
  final int index;

  const _LogTile({
    required this.log,
    required this.categoryColor,
    required this.categoryIcon,
    required this.roleIcon,
    required this.relativeTime,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: categoryColor.withValues(alpha: 0.25)),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(log.action,
                              style: GoogleFonts.outfit(
                                  color: context.labelColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Text(relativeTime,
                            style: TextStyle(
                                color: context.hintColor, fontSize: 11)),
                      ]),
                      if (log.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(log.description,
                            style: TextStyle(
                                color: context.subLabelColor, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        // User chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(roleIcon,
                                size: 11,
                                color: EnhancedTheme.primaryTeal),
                            const SizedBox(width: 4),
                            Text(log.username,
                                style: const TextStyle(
                                    color: EnhancedTheme.primaryTeal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        // Role chip
                        if (log.role.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(log.role,
                                style: TextStyle(
                                    color: categoryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        if (log.ipAddress != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.borderColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(log.ipAddress!,
                                style: TextStyle(
                                    color: context.hintColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: (index * 30).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.04, end: 0);
  }
}

// ── Empty view ─────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String category;
  const _EmptyView({required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                color: EnhancedTheme.accentPurple, size: 44),
          ),
          const SizedBox(height: 16),
          Text('No activity found',
              style: GoogleFonts.outfit(
                  color: context.labelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            category == 'all'
                ? 'No activity has been recorded yet.'
                : 'No "$category" events found.',
            style: TextStyle(color: context.hintColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: EnhancedTheme.errorRed, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Failed to load activity log',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    color: EnhancedTheme.errorRed, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.accentPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
