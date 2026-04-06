import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

// ── Local billing-cycle state ──────────────────────────────────────────────────
final _billingCycleProvider =
    StateProvider<BillingCycle>((ref) => BillingCycle.monthly);

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub        = ref.watch(currentSubscriptionProvider);
    final asyncState = ref.watch(subscriptionNotifierProvider);
    final isLoading  = asyncState is AsyncLoading;
    final cycle      = ref.watch(_billingCycleProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppShell.roleFallback(ref));
        }
      },
      child: Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          // ── Background gradient ─────────────────────────────────────────────
          Container(decoration: context.bgGradient),

          SafeArea(
            child: Column(
              children: [
                // ── AppBar ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.black, size: 20),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppShell.roleFallback(ref));
                          }
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Subscription & Plans',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EnhancedTheme.primaryTeal,
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Current plan card ─────────────────────────────────
                      _CurrentPlanCard(sub: sub),
                      const SizedBox(height: 8),

                      // ── Billing shortcut ──────────────────────────────────
                      _BillingShortcut(),
                      const SizedBox(height: 8),

                      // ── Usage stats ───────────────────────────────────────
                      _UsageCard(sub: sub),
                      const SizedBox(height: 20),

                      // ── Section header + billing toggle ───────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Text(
                              'Available Plans',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          _BillingToggle(cycle: cycle, ref: ref),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Plan cards ────────────────────────────────────────
                      ...SubscriptionPlan.values.map(
                        (plan) => _PlanCard(
                          plan:      plan,
                          isCurrent: sub.plan == plan &&
                              sub.billingCycle == cycle,
                          cycle:     cycle,
                          ref:       ref,
                          sub:       sub,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Feature matrix ────────────────────────────────────
                      _FeatureMatrix(sub: sub),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

// ── Billing Toggle ────────────────────────────────────────────────────────────

class _BillingToggle extends StatelessWidget {
  final BillingCycle cycle;
  final WidgetRef    ref;
  const _BillingToggle({required this.cycle, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: 'Monthly',
            isSelected: cycle == BillingCycle.monthly,
            onTap: () => ref
                .read(_billingCycleProvider.notifier)
                .state = BillingCycle.monthly,
          ),
          _ToggleSegment(
            label: 'Annual',
            isSelected: cycle == BillingCycle.annual,
            onTap: () => ref
                .read(_billingCycleProvider.notifier)
                .state = BillingCycle.annual,
            badge: 'Save 20%',
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final String  label;
  final bool    isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _ToggleSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? EnhancedTheme.primaryTeal
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : EnhancedTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : EnhancedTheme.successGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Current Plan Card ─────────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  final Subscription sub;
  const _CurrentPlanCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final Color planColor = _planColor(sub.plan);
    final days            = sub.trialDaysRemaining;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                planColor.withValues(alpha: 0.20),
                planColor.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: planColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: planColor.withValues(alpha: 0.15),
                  border: Border.all(color: planColor.withValues(alpha: 0.5)),
                ),
                child: Icon(Icons.workspace_premium_rounded,
                    color: planColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.plan.displayName,
                      style: TextStyle(
                          color: planColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel(sub),
                      style: TextStyle(
                          color: planColor.withValues(alpha: 0.75),
                          fontSize: 12),
                    ),
                    if (days != null && days >= 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (14 - days) / 14,
                          backgroundColor: planColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(planColor),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$days day${days == 1 ? '' : 's'} remaining',
                        style: TextStyle(
                            color: planColor.withValues(alpha: 0.65),
                            fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(Subscription sub) => switch (sub.status) {
        SubscriptionStatus.active    => 'Active subscription',
        SubscriptionStatus.trial     => 'Free trial',
        SubscriptionStatus.expiring  => 'Trial expiring soon',
        SubscriptionStatus.expired   => 'Trial expired — upgrade to continue',
        SubscriptionStatus.suspended => 'Suspended — contact support',
        SubscriptionStatus.cancelled => 'Cancelled',
      };
}

// ── Usage Card ────────────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final Subscription sub;
  const _UsageCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final limits = sub.limits;
    final usage  = sub.usage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Usage This Month',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _UsageRow(
                icon:    Icons.people_rounded,
                label:   'Staff accounts',
                current: usage.usersCount,
                max:     limits.maxUsers,
              ),
              const SizedBox(height: 8),
              _UsageRow(
                icon:    Icons.inventory_2_rounded,
                label:   'Inventory items',
                current: usage.itemsCount,
                max:     limits.maxItems,
              ),
              const SizedBox(height: 8),
              _UsageRow(
                icon:    Icons.receipt_long_rounded,
                label:   'Transactions',
                current: usage.transactionsThisMonth,
                max:     limits.maxTransactionsPerMonth,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      current;
  final int      max;

  const _UsageRow({
    required this.icon,
    required this.label,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final bool unlimited = max == -1;
    final double pct     = unlimited ? 0 : (max > 0 ? (current / max).clamp(0.0, 1.0) : 0);
    final Color bar      = pct >= 1
        ? EnhancedTheme.errorRed
        : pct >= 0.8
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.primaryTeal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.black54, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ),
            Text(
              unlimited ? '$current / ∞' : '$current / $max',
              style: TextStyle(
                  color: bar,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (!unlimited) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(bar),
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;
  final bool             isCurrent;
  final BillingCycle     cycle;
  final WidgetRef        ref;
  final Subscription     sub;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.cycle,
    required this.ref,
    required this.sub,
  });

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final planColor = _planColor(widget.plan);
    final limits    = UsageLimits.forPlan(widget.plan);
    // Use backend-driven features if available, else fall back to hardcoded
    final features  = widget.sub.featuresForPlan(widget.plan);
    final isAnnual  = widget.cycle == BillingCycle.annual;
    final savings   = widget.plan.annualSavings;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isCurrent
                  ? planColor.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isCurrent
                    ? planColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.10),
                width: widget.isCurrent ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: planColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_planIcon(widget.plan),
                          color: planColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(widget.plan.displayName,
                                  style: TextStyle(
                                      color: planColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              if (widget.isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: planColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('Current',
                                      style: TextStyle(
                                          color: planColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                              // Annual savings badge
                              if (isAnnual && savings > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: EnhancedTheme.successGreen
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Save \$${savings.toStringAsFixed(0)}/yr',
                                    style: const TextStyle(
                                        color: EnhancedTheme.successGreen,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.plan.priceLabel(widget.cycle),
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12),
                          ),
                          if (isAnnual &&
                              widget.plan.monthlyAmount > 0) ...[
                            const SizedBox(height: 1),
                            Text(
                              '\$${widget.plan.monthlyAmount.toStringAsFixed(2)}/mo billed monthly',
                              style: const TextStyle(
                                color: Colors.black38,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.black26,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!widget.isCurrent)
                      _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EnhancedTheme.primaryTeal,
                              ),
                            )
                          : TextButton(
                              onPressed: () => _upgrade(context),
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    planColor.withValues(alpha: 0.15),
                                foregroundColor: planColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                widget.plan.rank >
                                        (widget.ref
                                            .read(currentPlanProvider)
                                            .rank)
                                    ? 'Upgrade'
                                    : 'Downgrade',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),

                // Limits summary
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _LimitChip(
                      icon: Icons.people_rounded,
                      label: limits.unlimitedUsers
                          ? 'Unlimited users'
                          : '${limits.maxUsers} users',
                      color: planColor,
                    ),
                    _LimitChip(
                      icon: Icons.inventory_2_rounded,
                      label: limits.unlimitedItems
                          ? 'Unlimited items'
                          : '${limits.maxItems} items',
                      color: planColor,
                    ),
                    _LimitChip(
                      icon: Icons.receipt_long_rounded,
                      label: limits.unlimitedTransactions
                          ? 'Unlimited transactions'
                          : '${limits.maxTransactionsPerMonth}/mo',
                      color: planColor,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Feature tags (labels from backend if available)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: features
                      .map((f) => _FeatureChip(
                            feature: f,
                            label:   widget.sub.featureLabel(f),
                            color:   planColor,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _upgrade(BuildContext context) async {
    if (_loading) return;
    setState(() => _loading = true);

    final url = await widget.ref
        .read(subscriptionNotifierProvider.notifier)
        .upgradePlan(
          widget.plan.name,
          billingCycle: widget.cycle.apiValue,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (url != null && url.isNotEmpty) {
      // Backend returned a payment gateway URL — open it.
      // In prod: await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      context.push('/billing');
    } else {
      // No external URL — go to billing page to complete payment setup.
      context.push('/billing');
    }
  }
}

class _LimitChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _LimitChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String feature;
  final String label;
  final Color  color;
  const _FeatureChip({required this.feature, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Feature matrix table ─────────────────────────────────────────────────────

class _FeatureMatrix extends StatelessWidget {
  final Subscription sub;
  const _FeatureMatrix({required this.sub});

  @override
  Widget build(BuildContext context) {
    final featureKeys = sub.comparisonFeatureOrder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  'Feature Comparison',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),

              // Header row
              Container(
                color: Colors.white.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    ...SubscriptionPlan.values.map(
                      (p) => SizedBox(
                        width: 60,
                        child: Center(
                          child: Text(
                            p.displayName.split(' ').first,
                            style: TextStyle(
                              color: p == sub.plan
                                  ? _planColor(p)
                                  : Colors.black45,
                              fontSize: 10,
                              fontWeight: p == sub.plan
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Feature rows — driven by backend data
              ...List.generate(featureKeys.length, (i) {
                final key   = featureKeys[i];
                final label = sub.featureLabel(key);
                return Container(
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.02),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                      ),
                      ...SubscriptionPlan.values.map(
                        (p) => SizedBox(
                          width: 60,
                          child: Center(
                            child: sub.featuresForPlan(p).contains(key)
                                ? Icon(Icons.check_circle_rounded,
                                    color: _planColor(p), size: 16)
                                : const Icon(Icons.remove_rounded,
                                    color: Colors.black26,
                                    size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Billing Shortcut ──────────────────────────────────────────────────────────

class _BillingShortcut extends StatelessWidget {
  const _BillingShortcut();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: InkWell(
          onTap: () => context.push('/billing'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: EnhancedTheme.accentPurple, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billing & Invoices',
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text('Payment method, invoice history & more',
                          style:
                              TextStyle(color: Colors.black45, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.black38, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _planColor(SubscriptionPlan plan) => switch (plan) {
      SubscriptionPlan.trial        => EnhancedTheme.accentOrange,
      SubscriptionPlan.starter      => EnhancedTheme.infoBlue,
      SubscriptionPlan.professional => EnhancedTheme.accentPurple,
      SubscriptionPlan.enterprise   => EnhancedTheme.accentCyan,
    };

IconData _planIcon(SubscriptionPlan plan) => switch (plan) {
      SubscriptionPlan.trial        => Icons.science_rounded,
      SubscriptionPlan.starter      => Icons.rocket_launch_rounded,
      SubscriptionPlan.professional => Icons.workspace_premium_rounded,
      SubscriptionPlan.enterprise   => Icons.diamond_rounded,
    };
