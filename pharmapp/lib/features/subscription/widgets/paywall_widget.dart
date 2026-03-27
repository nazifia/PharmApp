import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';

/// Wraps a [child] widget and overlays a paywall if the named [feature]
/// is not available on the current subscription plan.
///
/// ```dart
/// FeatureGate(
///   feature: SaasFeature.wholesale,
///   requiredPlan: SubscriptionPlan.professional,
///   child: WholesaleDashboard(),
/// )
/// ```
class FeatureGate extends ConsumerWidget {
  final String             feature;
  final SubscriptionPlan   requiredPlan;
  final Widget             child;
  final String?            featureLabel;   // friendly name for the paywall UI

  const FeatureGate({
    super.key,
    required this.feature,
    required this.requiredPlan,
    required this.child,
    this.featureLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasFeatureProvider(feature));
    if (hasAccess) return child;

    return Stack(
      children: [
        // Blurred-out content preview
        IgnorePointer(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Opacity(opacity: 0.25, child: child),
            ),
          ),
        ),
        // Paywall overlay
        Positioned.fill(
          child: _PaywallOverlay(
            requiredPlan: requiredPlan,
            featureLabel: featureLabel ?? _labelFor(feature),
          ),
        ),
      ],
    );
  }

  static String _labelFor(String feature) => switch (feature) {
        SaasFeature.wholesale       => 'Wholesale Management',
        SaasFeature.advancedReports => 'Advanced Reports',
        SaasFeature.basicReports    => 'Reports',
        SaasFeature.userManagement  => 'User Management',
        SaasFeature.customers       => 'Customer Management',
        SaasFeature.exportData      => 'Data Export',
        SaasFeature.multiBranch     => 'Multi-Branch',
        SaasFeature.apiAccess       => 'API Access',
        _                           => feature.replaceAll('_', ' '),
      };
}

// ── Paywall overlay ──────────────────────────────────────────────────────────

class _PaywallOverlay extends StatelessWidget {
  final SubscriptionPlan requiredPlan;
  final String           featureLabel;

  const _PaywallOverlay({required this.requiredPlan, required this.featureLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          EnhancedTheme.accentPurple.withValues(alpha: 0.3),
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                        ],
                      ),
                      border: Border.all(
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: EnhancedTheme.accentPurple,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    featureLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Available on ${requiredPlan.displayName} and above',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/subscription'),
                      icon: const Icon(Icons.upgrade_rounded, size: 18),
                      label: Text('Upgrade to ${requiredPlan.displayName}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.accentPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

// ── Usage limit banner ────────────────────────────────────────────────────────

/// Shows a warning row when usage is >= 80% of the plan limit.
/// Returns [SizedBox.shrink] when there is no concern.
class UsageLimitWarning extends ConsumerWidget {
  final String limitType; // 'users' | 'items' | 'transactions'
  const UsageLimitWarning({super.key, required this.limitType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage  = ref.watch(currentUsageProvider);
    final limits = ref.watch(usageLimitsProvider);

    final int current;
    final int max;
    final String label;

    switch (limitType) {
      case 'users':
        current = usage.usersCount;
        max     = limits.maxUsers;
        label   = 'staff accounts';
      case 'items':
        current = usage.itemsCount;
        max     = limits.maxItems;
        label   = 'inventory items';
      case 'transactions':
        current = usage.transactionsThisMonth;
        max     = limits.maxTransactionsPerMonth;
        label   = 'transactions this month';
      default:
        return const SizedBox.shrink();
    }

    if (max == -1) return const SizedBox.shrink(); // unlimited

    final double pct = max > 0 ? current / max : 0;
    if (pct < 0.8)  return const SizedBox.shrink(); // no warning needed

    final bool isOver  = current >= max;
    final Color color  = isOver ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber;
    final String text  = isOver
        ? 'You have reached your limit of $max $label. Upgrade to add more.'
        : 'You are using $current/$max $label (${(pct * 100).round()}%). Upgrade soon.';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.block_rounded : Icons.warning_amber_rounded,
            color: color, size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push('/subscription'),
            child: Text(
              'Upgrade',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
