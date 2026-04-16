import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/superuser/providers/superuser_provider.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';
import 'package:pharmapp/shared/models/subscription.dart';

class SuperuserDashboardScreen extends ConsumerStatefulWidget {
  const SuperuserDashboardScreen({super.key});

  @override
  ConsumerState<SuperuserDashboardScreen> createState() =>
      _SuperuserDashboardScreenState();
}

class _SuperuserDashboardScreenState
    extends ConsumerState<SuperuserDashboardScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync   = ref.watch(orgListProvider);
    final filtered    = ref.watch(filteredOrgListProvider);
    final stats       = ref.watch(orgStatsProvider);
    final planFilter  = ref.watch(orgPlanFilterProvider);
    final statusFilter = ref.watch(orgStatusFilterProvider);

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                // ── AppBar ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.black, size: 20),
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/admin-dashboard'),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Platform Admin',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            Text('Subscription Management',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Plan Feature Matrix',
                        icon: const Icon(Icons.tune_rounded,
                            color: Colors.black54),
                        onPressed: () => context.push('/superuser/plans'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.black54),
                        onPressed: () =>
                            ref.read(orgListProvider.notifier).load(),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: listAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: EnhancedTheme.primaryTeal),
                    ),
                    error: (e, _) => _ErrorView(
                      message: e.toString(),
                      onRetry: () =>
                          ref.read(orgListProvider.notifier).load(),
                    ),
                    data: (_) => ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── Stats row ───────────────────────────────────────
                        _StatsRow(stats: stats),
                        const SizedBox(height: 16),

                        // ── Search ──────────────────────────────────────────
                        _SearchBar(
                          controller: _searchCtrl,
                          onChanged: (q) => ref
                              .read(orgSearchQueryProvider.notifier)
                              .state = q,
                        ),
                        const SizedBox(height: 10),

                        // ── Plan filter chips ───────────────────────────────
                        _FilterRow(
                          planFilter:    planFilter,
                          statusFilter:  statusFilter,
                          onPlanFilter:  (p) => ref
                              .read(orgPlanFilterProvider.notifier)
                              .state = p,
                          onStatusFilter: (s) => ref
                              .read(orgStatusFilterProvider.notifier)
                              .state = s,
                        ),
                        const SizedBox(height: 12),

                        // ── Org list ────────────────────────────────────────
                        if (filtered.isEmpty)
                          _EmptyState(hasFilters: planFilter != null ||
                              statusFilter != null ||
                              _searchCtrl.text.isNotEmpty)
                        else
                          ...filtered.map((org) => _OrgCard(org: org)),

                        const SizedBox(height: 24),
                      ],
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

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final OrgStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(label: 'Total',     value: stats.total,     color: Colors.white70),
        const SizedBox(width: 8),
        _StatChip(label: 'Active',    value: stats.active,    color: EnhancedTheme.successGreen),
        const SizedBox(width: 8),
        _StatChip(label: 'Trial',     value: stats.trial,     color: EnhancedTheme.accentOrange),
        const SizedBox(width: 8),
        _StatChip(label: 'Expired',   value: stats.expired,   color: EnhancedTheme.errorRed),
        const SizedBox(width: 8),
        _StatChip(label: 'Suspended', value: stats.suspended, color: Colors.white38),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.black45, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Search organizations…',
              hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Colors.black38, size: 18),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter Row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final SubscriptionPlan?   planFilter;
  final SubscriptionStatus? statusFilter;
  final ValueChanged<SubscriptionPlan?>   onPlanFilter;
  final ValueChanged<SubscriptionStatus?> onStatusFilter;

  const _FilterRow({
    required this.planFilter,
    required this.statusFilter,
    required this.onPlanFilter,
    required this.onStatusFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Status filters
          _FilterChip(
            label: 'Active',
            isSelected: statusFilter == SubscriptionStatus.active,
            color: EnhancedTheme.successGreen,
            onTap: () => onStatusFilter(
              statusFilter == SubscriptionStatus.active ? null : SubscriptionStatus.active,
            ),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Trial',
            isSelected: statusFilter == SubscriptionStatus.trial,
            color: EnhancedTheme.accentOrange,
            onTap: () => onStatusFilter(
              statusFilter == SubscriptionStatus.trial ? null : SubscriptionStatus.trial,
            ),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Expired',
            isSelected: statusFilter == SubscriptionStatus.expired,
            color: EnhancedTheme.errorRed,
            onTap: () => onStatusFilter(
              statusFilter == SubscriptionStatus.expired ? null : SubscriptionStatus.expired,
            ),
          ),
          const SizedBox(width: 12),
          // Plan filters
          ...SubscriptionPlan.values.map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterChip(
                  label: p.displayName,
                  isSelected: planFilter == p,
                  color: _planColor(p),
                  onTap: () =>
                      onPlanFilter(planFilter == p ? null : p),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   isSelected;
  final Color  color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isSelected ? color : Colors.black54,
              fontSize: 11,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}

// ── Org Card ──────────────────────────────────────────────────────────────────

class _OrgCard extends StatelessWidget {
  final OrgSubscriptionSummary org;
  const _OrgCard({required this.org});

  @override
  Widget build(BuildContext context) {
    final planColor  = _planColor(org.plan);
    final statusColor = _statusColor(org.status);
    final days        = org.trialDaysRemaining;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: InkWell(
            onTap: () => context.push('/superuser/org/${org.id}'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Plan icon bubble
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: planColor.withValues(alpha: 0.15),
                          border: Border.all(
                              color: planColor.withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.business_rounded,
                            color: planColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(org.name,
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(org.slug,
                                style: const TextStyle(
                                    color: Colors.black38, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Plan badge
                      _Badge(label: org.plan.displayName, color: planColor),
                      const SizedBox(width: 6),
                      // Status badge
                      _Badge(label: _statusLabel(org.status), color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          color: Colors.black38, size: 13),
                      const SizedBox(width: 4),
                      Text('${org.userCount} users',
                          style: const TextStyle(
                              color: Colors.black38, fontSize: 11)),
                      const SizedBox(width: 12),
                      const Icon(Icons.receipt_long_rounded,
                          color: Colors.black38, size: 13),
                      const SizedBox(width: 4),
                      Text(
                          '${org.usage.transactionsThisMonth} tx this month',
                          style: const TextStyle(
                              color: Colors.black38, fontSize: 11)),
                      if (org.hasFeatureOverrides) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.tune_rounded,
                            color: EnhancedTheme.accentPurple
                                .withValues(alpha: 0.8),
                            size: 13),
                        const SizedBox(width: 3),
                        Text('overrides',
                            style: TextStyle(
                                color: EnhancedTheme.accentPurple
                                    .withValues(alpha: 0.8),
                                fontSize: 11)),
                      ],
                    ],
                  ),
                  // Trial progress bar
                  if (days != null && days >= 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: days / 14,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(statusColor),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$days d left',
                            style: TextStyle(
                                color: statusColor, fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Empty / Error views ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.domain_disabled_rounded,
                color: Colors.black26, size: 48),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'No organizations match the current filters.'
                  : 'No organizations found.',
              style:
                  const TextStyle(color: Colors.black38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String    message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: EnhancedTheme.errorRed, size: 48),
            const SizedBox(height: 12),
            Text(message,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: EnhancedTheme.primaryTeal),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color helpers ─────────────────────────────────────────────────────────────

Color _planColor(SubscriptionPlan plan) => switch (plan) {
      SubscriptionPlan.trial        => EnhancedTheme.accentOrange,
      SubscriptionPlan.starter      => EnhancedTheme.infoBlue,
      SubscriptionPlan.professional => EnhancedTheme.accentPurple,
      SubscriptionPlan.enterprise   => EnhancedTheme.accentCyan,
    };

Color _statusColor(SubscriptionStatus s) => switch (s) {
      SubscriptionStatus.active    => EnhancedTheme.successGreen,
      SubscriptionStatus.trial     => EnhancedTheme.accentOrange,
      SubscriptionStatus.expiring  => EnhancedTheme.warningAmber,
      SubscriptionStatus.expired   => EnhancedTheme.errorRed,
      SubscriptionStatus.pending   => EnhancedTheme.accentPurple,
      SubscriptionStatus.suspended => Colors.white38,
      SubscriptionStatus.cancelled => Colors.white24,
    };

String _statusLabel(SubscriptionStatus s) => switch (s) {
      SubscriptionStatus.active    => 'Active',
      SubscriptionStatus.trial     => 'Trial',
      SubscriptionStatus.expiring  => 'Expiring',
      SubscriptionStatus.expired   => 'Expired',
      SubscriptionStatus.pending   => 'Pending',
      SubscriptionStatus.suspended => 'Suspended',
      SubscriptionStatus.cancelled => 'Cancelled',
    };
