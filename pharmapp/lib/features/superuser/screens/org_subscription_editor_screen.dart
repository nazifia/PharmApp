import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/superuser/providers/superuser_provider.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';
import 'package:pharmapp/shared/models/subscription.dart';

class OrgSubscriptionEditorScreen extends ConsumerStatefulWidget {
  final int orgId;
  const OrgSubscriptionEditorScreen({super.key, required this.orgId});

  @override
  ConsumerState<OrgSubscriptionEditorScreen> createState() =>
      _OrgSubscriptionEditorScreenState();
}

class _OrgSubscriptionEditorScreenState
    extends ConsumerState<OrgSubscriptionEditorScreen> {
  // ── Draft state (edited in-UI, only saved on tap) ─────────────────────────
  late SubscriptionPlan   _plan;
  late SubscriptionStatus _status;
  late BillingCycle       _billingCycle;
  DateTime?               _trialEndsAt;
  late Set<String>        _extraFeatures;
  late Set<String>        _removedFeatures;
  // custom limits: null means "use plan default"
  late Map<String, int?>  _customLimits;

  bool _initialized = false;
  bool _saving      = false;

  final _fmt = DateFormat('MMM d, yyyy');

  void _initFromOrg(OrgSubscriptionSummary org) {
    _plan           = org.plan;
    _status         = org.status;
    _billingCycle   = org.billingCycle;
    _trialEndsAt    = org.trialEndsAt;
    _extraFeatures  = Set.from(org.extraFeatures);
    _removedFeatures = Set.from(org.removedFeatures);
    final cl = org.customLimits;
    _customLimits = {
      'max_users':                  cl?.maxUsers,
      'max_items':                  cl?.maxItems,
      'max_transactions_per_month': cl?.maxTransactionsPerMonth,
      'max_branches':               cl?.maxBranches,
    };
    _initialized = true;
  }

  // ── Feature toggle helpers ────────────────────────────────────────────────

  bool _isFeatureEnabled(String feature) {
    if (_removedFeatures.contains(feature)) return false;
    final planDefault = SaasFeature.forPlan(_plan).contains(feature);
    return planDefault || _extraFeatures.contains(feature);
  }

  bool _isFeatureInPlan(String feature) =>
      SaasFeature.forPlan(_plan).contains(feature);

  void _toggleFeature(String feature) {
    setState(() {
      if (_isFeatureEnabled(feature)) {
        // Turn off: if it's in the plan, add to removed; if only in extras, remove from extras.
        if (_isFeatureInPlan(feature)) {
          _removedFeatures.add(feature);
          _extraFeatures.remove(feature);
        } else {
          _extraFeatures.remove(feature);
        }
      } else {
        // Turn on: remove from removed set; if not in plan, add to extras.
        _removedFeatures.remove(feature);
        if (!_isFeatureInPlan(feature)) {
          _extraFeatures.add(feature);
        }
      }
    });
  }

  // ── Build payload ─────────────────────────────────────────────────────────

  Map<String, dynamic> _buildPayload() {
    final hasCustomLimits = _customLimits.values.any((v) => v != null);
    return {
      'plan':             _plan.name,
      'status':           _status.name,
      'billing_cycle':    _billingCycle.apiValue,
      'trial_ends_at':    _trialEndsAt?.toIso8601String(),
      'extra_features':   _extraFeatures.toList(),
      'removed_features': _removedFeatures.toList(),
      'custom_limits': hasCustomLimits
          ? {
              'max_users':                  _customLimits['max_users'],
              'max_items':                  _customLimits['max_items'],
              'max_transactions_per_month': _customLimits['max_transactions_per_month'],
              'max_branches':               _customLimits['max_branches'],
            }
          : null,
    };
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final error = await ref
        .read(orgEditorProvider(widget.orgId).notifier)
        .save(_buildPayload());
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription updated successfully.'),
          backgroundColor: EnhancedTheme.successGreen,
        ),
      );
    }
  }

  // ── Extend trial dialog ───────────────────────────────────────────────────

  Future<void> _showExtendTrialDialog() async {
    int days = 14;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Extend Trial',
            style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current trial ends: ${_trialEndsAt != null ? _fmt.format(_trialEndsAt!) : 'not set'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: Colors.white54),
                    onPressed: () => setS(
                        () => days = (days - 7).clamp(7, 365)),
                  ),
                  Expanded(
                    child: Text('$days days',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white54),
                    onPressed: () => setS(
                        () => days = (days + 7).clamp(7, 365)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal),
              child: const Text('Extend')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final error = await ref
        .read(orgEditorProvider(widget.orgId).notifier)
        .extendTrial(days);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $error'),
          backgroundColor: EnhancedTheme.errorRed));
    } else {
      // Sync local state to new trial date from the notifier
      final updated = ref.read(orgEditorProvider(widget.orgId)).valueOrNull;
      if (updated != null) {
        setState(() => _trialEndsAt = updated.trialEndsAt);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Trial extended.'),
          backgroundColor: EnhancedTheme.successGreen));
    }
  }

  // ── Reset dialog ──────────────────────────────────────────────────────────

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset to Plan Defaults',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will remove all feature overrides and custom limits for this organization.',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.errorRed),
              child: const Text('Reset')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final error = await ref
        .read(orgEditorProvider(widget.orgId).notifier)
        .resetToDefaults();
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $error'),
          backgroundColor: EnhancedTheme.errorRed));
    } else {
      final updated = ref.read(orgEditorProvider(widget.orgId)).valueOrNull;
      if (updated != null) setState(() => _initFromOrg(updated));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reset to plan defaults.'),
          backgroundColor: EnhancedTheme.successGreen));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(orgEditorProvider(widget.orgId));

    return orgAsync.when(
      loading: () => Scaffold(
        backgroundColor: EnhancedTheme.primaryDark,
        body: Stack(children: [
          Container(decoration: context.bgGradient),
          const Center(
              child: CircularProgressIndicator(
                  color: EnhancedTheme.primaryTeal)),
        ]),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: EnhancedTheme.primaryDark,
        body: Stack(children: [
          Container(decoration: context.bgGradient),
          Center(
              child: Text(e.toString(),
                  style:
                      const TextStyle(color: Colors.white54))),
        ]),
      ),
      data: (org) {
        if (org == null) {
          return Scaffold(
            backgroundColor: EnhancedTheme.primaryDark,
            body: Stack(children: [
              Container(decoration: context.bgGradient),
              const Center(
                  child: Text('Organization not found.',
                      style: TextStyle(color: Colors.white54))),
            ]),
          );
        }

        // Initialize draft once
        if (!_initialized) _initFromOrg(org);

        return Scaffold(
          backgroundColor: EnhancedTheme.primaryDark,
          body: Stack(
            children: [
              Container(decoration: context.bgGradient),
              SafeArea(
                child: Column(
                  children: [
                    // ── AppBar ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.black,
                                size: 20),
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/superuser'),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(org.name,
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(org.slug,
                                    style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          if (_saving)
                            const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EnhancedTheme.primaryTeal,
                              ),
                            )
                          else
                            TextButton(
                              onPressed: _save,
                              style: TextButton.styleFrom(
                                backgroundColor: EnhancedTheme.primaryTeal
                                    .withValues(alpha: 0.15),
                                foregroundColor: EnhancedTheme.primaryTeal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Save',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Plan & Status ─────────────────────────────
                          const _SectionHeader(
                              icon: Icons.workspace_premium_rounded,
                              title: 'Plan & Status'),
                          const SizedBox(height: 8),
                          _GlassCard(
                            child: Column(
                              children: [
                                _DropdownRow<SubscriptionPlan>(
                                  label:    'Plan',
                                  value:    _plan,
                                  items:    SubscriptionPlan.values,
                                  itemLabel: (p) => p.displayName,
                                  onChanged: (p) => setState(() {
                                    _plan = p!;
                                    // Recalculate extra/removed for new plan baseline
                                    final newPlanFeatures = SaasFeature.forPlan(_plan);
                                    // Keep extras that aren't now in the plan
                                    _extraFeatures.removeWhere(
                                        newPlanFeatures.contains);
                                    // Keep removed only for features still in plan
                                    _removedFeatures.removeWhere(
                                        (f) => !newPlanFeatures.contains(f));
                                  }),
                                ),
                                const Divider(color: Colors.white10, height: 1),
                                _DropdownRow<SubscriptionStatus>(
                                  label:    'Status',
                                  value:    _status,
                                  items:    SubscriptionStatus.values,
                                  itemLabel: (s) => _statusLabel(s),
                                  onChanged: (s) =>
                                      setState(() => _status = s!),
                                ),
                                const Divider(color: Colors.white10, height: 1),
                                _DropdownRow<BillingCycle>(
                                  label:    'Billing Cycle',
                                  value:    _billingCycle,
                                  items:    BillingCycle.values,
                                  itemLabel: (b) => b.displayName,
                                  onChanged: (b) =>
                                      setState(() => _billingCycle = b!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Trial ─────────────────────────────────────
                          const _SectionHeader(
                              icon: Icons.hourglass_empty_rounded,
                              title: 'Trial Period'),
                          const SizedBox(height: 8),
                          _GlassCard(
                            child: Column(
                              children: [
                                _DateRow(
                                  label: 'Trial ends at',
                                  date: _trialEndsAt,
                                  onPick: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _trialEndsAt ??
                                          DateTime.now()
                                              .add(const Duration(days: 14)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _trialEndsAt = picked);
                                    }
                                  },
                                  onClear: () =>
                                      setState(() => _trialEndsAt = null),
                                ),
                                const Divider(color: Colors.white10, height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.calendar_today_rounded,
                                          color: Colors.black38,
                                          size: 14),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text('Quick extend trial',
                                            style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 13)),
                                      ),
                                      TextButton(
                                        onPressed: _showExtendTrialDialog,
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              EnhancedTheme.accentOrange,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Extend…'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Feature Flags ─────────────────────────────
                          const _SectionHeader(
                              icon: Icons.tune_rounded,
                              title: 'Feature Overrides'),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Checkmark = enabled.  Grey = plan default.  Teal = manually added.  Red = manually removed.',
                              style: TextStyle(
                                  color: Colors.black38, fontSize: 10),
                            ),
                          ),
                          _GlassCard(
                            child: Column(
                              children: [
                                ..._allFeatureKeys.map((entry) {
                                  final key    = entry.$1;
                                  final label  = entry.$2;
                                  final enabled = _isFeatureEnabled(key);
                                  final inPlan  = _isFeatureInPlan(key);
                                  final isExtra   = _extraFeatures.contains(key);
                                  final isRemoved = _removedFeatures.contains(key);

                                  return Column(
                                    children: [
                                      InkWell(
                                        onTap: () => _toggleFeature(key),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          child: Row(
                                            children: [
                                              Icon(
                                                enabled
                                                    ? Icons.check_circle_rounded
                                                    : Icons.cancel_rounded,
                                                color: enabled
                                                    ? (isExtra
                                                        ? EnhancedTheme.primaryTeal
                                                        : EnhancedTheme.successGreen)
                                                    : EnhancedTheme.errorRed,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(label,
                                                    style: TextStyle(
                                                        color: enabled
                                                            ? Colors.black87
                                                            : Colors.black38,
                                                        fontSize: 13)),
                                              ),
                                              // Plan default / override indicator
                                              if (inPlan && !isRemoved)
                                                const _FeatureTag(
                                                    label: 'plan',
                                                    color: Colors.black26)
                                              else if (isExtra)
                                                const _FeatureTag(
                                                    label: 'added',
                                                    color: EnhancedTheme.primaryTeal)
                                              else if (isRemoved)
                                                const _FeatureTag(
                                                    label: 'removed',
                                                    color: EnhancedTheme.errorRed)
                                              else
                                                const SizedBox.shrink(),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (entry != _allFeatureKeys.last)
                                        const Divider(
                                            color: Colors.white10, height: 1),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Custom Limits ─────────────────────────────
                          const _SectionHeader(
                              icon: Icons.speed_rounded,
                              title: 'Usage Limits Override'),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Leave blank to use plan defaults.  Enter -1 for unlimited.',
                              style: TextStyle(
                                  color: Colors.black38, fontSize: 10),
                            ),
                          ),
                          _GlassCard(
                            child: Column(
                              children: [
                                _LimitRow(
                                  icon:  Icons.people_rounded,
                                  label: 'Max users',
                                  planDefault:
                                      UsageLimits.forPlan(_plan).maxUsers,
                                  value:
                                      _customLimits['max_users'],
                                  onChanged: (v) => setState(() =>
                                      _customLimits['max_users'] = v),
                                ),
                                const Divider(
                                    color: Colors.white10, height: 1),
                                _LimitRow(
                                  icon:  Icons.inventory_2_rounded,
                                  label: 'Max items',
                                  planDefault:
                                      UsageLimits.forPlan(_plan).maxItems,
                                  value:
                                      _customLimits['max_items'],
                                  onChanged: (v) => setState(
                                      () => _customLimits['max_items'] = v),
                                ),
                                const Divider(
                                    color: Colors.white10, height: 1),
                                _LimitRow(
                                  icon:  Icons.receipt_long_rounded,
                                  label: 'Max transactions/mo',
                                  planDefault: UsageLimits.forPlan(_plan)
                                      .maxTransactionsPerMonth,
                                  value: _customLimits[
                                      'max_transactions_per_month'],
                                  onChanged: (v) => setState(() =>
                                      _customLimits[
                                          'max_transactions_per_month'] = v),
                                ),
                                const Divider(
                                    color: Colors.white10, height: 1),
                                _LimitRow(
                                  icon:  Icons.store_rounded,
                                  label: 'Max branches',
                                  planDefault:
                                      UsageLimits.forPlan(_plan).maxBranches,
                                  value:
                                      _customLimits['max_branches'],
                                  onChanged: (v) => setState(() =>
                                      _customLimits['max_branches'] = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Usage Stats (read-only) ────────────────────
                          const _SectionHeader(
                              icon: Icons.bar_chart_rounded,
                              title: 'Current Usage (read-only)'),
                          const SizedBox(height: 8),
                          _GlassCard(
                            child: Column(
                              children: [
                                _InfoRow(
                                    icon: Icons.people_rounded,
                                    label: 'Active users',
                                    value: '${org.usage.usersCount}'),
                                const Divider(
                                    color: Colors.white10, height: 1),
                                _InfoRow(
                                    icon: Icons.inventory_2_rounded,
                                    label: 'Inventory items',
                                    value: '${org.usage.itemsCount}'),
                                const Divider(
                                    color: Colors.white10, height: 1),
                                _InfoRow(
                                    icon: Icons.receipt_long_rounded,
                                    label: 'Transactions this month',
                                    value:
                                        '${org.usage.transactionsThisMonth}'),
                                const Divider(
                                    color: Colors.white10, height: 1),
                                _InfoRow(
                                    icon: Icons.store_rounded,
                                    label: 'Branches',
                                    value: '${org.usage.branchesCount}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Danger zone ────────────────────────────────
                          _GlassCard(
                            child: InkWell(
                              onTap: _confirmReset,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: EnhancedTheme.errorRed
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.restore_rounded,
                                          color: EnhancedTheme.errorRed,
                                          size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Reset to Plan Defaults',
                                              style: TextStyle(
                                                  color: EnhancedTheme.errorRed,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                              'Remove all feature & limit overrides',
                                              style: TextStyle(
                                                  color: Colors.black38,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: Colors.black26, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _allFeatureKeys = [
    (SaasFeature.pos,             'Point of Sale'),
    (SaasFeature.inventory,       'Inventory Management'),
    (SaasFeature.customers,       'Customer Management'),
    (SaasFeature.userManagement,  'User Management'),
    (SaasFeature.basicReports,    'Basic Reports'),
    (SaasFeature.advancedReports, 'Advanced Reports'),
    (SaasFeature.wholesale,       'Wholesale Module'),
    (SaasFeature.exportData,      'Export Data'),
    (SaasFeature.multiBranch,     'Multi-Branch'),
    (SaasFeature.prioritySupport, 'Priority Support'),
  ];

  String _statusLabel(SubscriptionStatus s) => switch (s) {
        SubscriptionStatus.active    => 'Active',
        SubscriptionStatus.trial     => 'Trial',
        SubscriptionStatus.expiring  => 'Expiring',
        SubscriptionStatus.expired   => 'Expired',
        SubscriptionStatus.pending   => 'Pending',
        SubscriptionStatus.suspended => 'Suspended',
        SubscriptionStatus.cancelled => 'Cancelled',
      };
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: EnhancedTheme.primaryTeal, size: 15),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final String         label;
  final T              value;
  final List<T>        items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value:         value,
                isExpanded:    true,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.black38, size: 18),
                onChanged: onChanged,
                items: items
                    .map((item) => DropdownMenuItem<T>(
                          value: item,
                          child: Text(itemLabel(item)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DateRow({
    required this.label,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Text(
                date != null ? fmt.format(date!) : 'Not set — tap to pick',
                style: TextStyle(
                    color: date != null
                        ? Colors.black87
                        : Colors.black38,
                    fontSize: 13),
              ),
            ),
          ),
          if (date != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded,
                  color: Colors.black38, size: 16),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatefulWidget {
  final IconData icon;
  final String   label;
  final int      planDefault;
  final int?     value;
  final ValueChanged<int?> onChanged;

  const _LimitRow({
    required this.icon,
    required this.label,
    required this.planDefault,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_LimitRow> createState() => _LimitRowState();
}

class _LimitRowState extends State<_LimitRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(widget.icon, color: Colors.black38, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.label,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text('plan: ${widget.planDefault == -1 ? "∞" : "${widget.planDefault}"}',
              style: const TextStyle(color: Colors.black26, fontSize: 10)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
              ],
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'default',
                hintStyle: const TextStyle(color: Colors.black26, fontSize: 11),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                widget.onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final String label;
  final Color  color;
  const _FeatureTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
