import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';

/// Displays a dismissible warning banner when any subscription (trial or paid)
/// is expiring within 7 days or has already expired.
class TrialBanner extends ConsumerStatefulWidget {
  const TrialBanner({super.key});

  @override
  ConsumerState<TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends ConsumerState<TrialBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final sub = ref.watch(currentSubscriptionProvider);

    final bool isExpired = sub.status == SubscriptionStatus.expired;
    final bool isTrial   = sub.plan == SubscriptionPlan.trial;

    // Show when expired or within 7-day expiry window for any plan.
    if (!isExpired && !sub.isSubscriptionExpiring) {
      return const SizedBox.shrink();
    }

    final days = sub.subscriptionDaysRemaining;

    final Color    bannerColor;
    final String   message;
    final IconData icon;

    if (isExpired) {
      bannerColor = EnhancedTheme.errorRed;
      icon        = Icons.lock_outline_rounded;
      message     = isTrial
          ? 'Your free trial has expired. Upgrade to continue.'
          : 'Your subscription has expired. Renew to restore access.';
    } else if (days != null && days <= 3) {
      bannerColor = EnhancedTheme.errorRed;
      icon        = Icons.timer_rounded;
      if (days == 0) {
        message = isTrial
            ? 'Trial expires today! Upgrade now to keep access.'
            : 'Subscription expires today! Renew now.';
      } else {
        final label = isTrial ? 'trial' : 'subscription';
        message = 'Only $days day${days == 1 ? '' : 's'} left on your $label. Act now.';
      }
    } else {
      // 4–7 days
      bannerColor = EnhancedTheme.warningAmber;
      icon        = Icons.hourglass_bottom_rounded;
      final label = isTrial ? 'free trial' : 'subscription';
      message     = '$days days left on your $label.';
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: bannerColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: bannerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/subscription'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTrial ? 'Upgrade' : 'Renew',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(Icons.close_rounded, color: bannerColor, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact badge showing current plan name — use in headers/drawers.
class PlanBadge extends ConsumerWidget {
  const PlanBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(currentPlanProvider);
    final sub  = ref.watch(currentSubscriptionProvider);

    final Color badgeColor = switch (plan) {
      SubscriptionPlan.trial        => EnhancedTheme.accentOrange,
      SubscriptionPlan.starter      => EnhancedTheme.infoBlue,
      SubscriptionPlan.professional => EnhancedTheme.accentPurple,
      SubscriptionPlan.enterprise   => EnhancedTheme.accentCyan,
    };

    return GestureDetector(
      onTap: () => context.push('/subscription'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sub.status == SubscriptionStatus.expired
                  ? Icons.lock_rounded
                  : Icons.workspace_premium_rounded,
              color: badgeColor,
              size: 11,
            ),
            const SizedBox(width: 4),
            Text(
              plan.displayName,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
