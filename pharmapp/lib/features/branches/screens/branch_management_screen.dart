import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/branch.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  ConsumerState<BranchManagementScreen> createState() =>
      _BranchManagementScreenState();
}

class _BranchManagementScreenState
    extends ConsumerState<BranchManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(branchNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncBranches = ref.watch(branchNotifierProvider);
    final sub           = ref.watch(currentSubscriptionProvider);
    final limits        = sub.limits;
    final hasBranchFeature = ref.watch(hasFeatureProvider(SaasFeature.multiBranch));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) context.pop();
        else context.go(AppShell.roleFallback(ref));
      },
      child: Scaffold(
        backgroundColor: EnhancedTheme.primaryDark,
        body: Stack(
          children: [
            Container(decoration: context.bgGradient),
            SafeArea(
              child: Column(
                children: [
                  // ── AppBar ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.black, size: 20),
                          onPressed: () {
                            if (context.canPop()) context.pop();
                            else context.go(AppShell.roleFallback(ref));
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Branch Management',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (hasBranchFeature)
                          IconButton(
                            icon: const Icon(Icons.add_rounded,
                                color: EnhancedTheme.primaryTeal),
                            onPressed: () => _showBranchDialog(context),
                          ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          ref.read(branchNotifierProvider.notifier).load(),
                      color: EnhancedTheme.primaryTeal,
                      backgroundColor: EnhancedTheme.surfaceColor,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Plan limit banner ─────────────────────────────
                          _LimitBanner(sub: sub, limits: limits,
                              hasBranchFeature: hasBranchFeature),
                          const SizedBox(height: 16),

                          // ── Branch list ───────────────────────────────────
                          asyncBranches.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                    color: EnhancedTheme.primaryTeal),
                              ),
                            ),
                            error: (e, _) => _ErrorCard(
                              message: e.toString(),
                              onRetry: () => ref
                                  .read(branchNotifierProvider.notifier)
                                  .load(),
                            ),
                            data: (branches) => branches.isEmpty
                                ? _EmptyState(
                                    hasBranchFeature: hasBranchFeature,
                                    onAdd: hasBranchFeature
                                        ? () => _showBranchDialog(context)
                                        : null,
                                  )
                                : Column(
                                    children: branches
                                        .map((b) => _BranchCard(
                                              branch: b,
                                              hasBranchFeature:
                                                  hasBranchFeature,
                                              onEdit: () =>
                                                  _showBranchDialog(context,
                                                      existing: b),
                                              onSetMain: b.isMain
                                                  ? null
                                                  : () =>
                                                      _setMain(context, b),
                                              onDeactivate: b.isMain
                                                  ? null
                                                  : () => _deactivate(
                                                      context, b),
                                            ))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _showBranchDialog(BuildContext context, {Branch? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(
        existing: existing,
        onSave: (name, address, phone, email) async {
          String? err;
          if (existing != null) {
            err = await ref.read(branchNotifierProvider.notifier).update(
                  existing.id,
                  name: name,
                  address: address,
                  phone: phone,
                  email: email,
                );
          } else {
            err = await ref.read(branchNotifierProvider.notifier).create(
                  name: name,
                  address: address,
                  phone: phone,
                  email: email,
                );
          }
          if (!context.mounted) return;
          Navigator.pop(context);
          if (err != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err),
                backgroundColor: EnhancedTheme.errorRed,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _setMain(BuildContext context, Branch branch) async {
    final err =
        await ref.read(branchNotifierProvider.notifier).setMain(branch.id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err),
            backgroundColor: EnhancedTheme.errorRed),
      );
    }
  }

  Future<void> _deactivate(BuildContext context, Branch branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EnhancedTheme.surfaceColor,
        title: const Text('Deactivate Branch',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Deactivate "${branch.name}"? Its data will be preserved.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: EnhancedTheme.errorRed),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final err = await ref
        .read(branchNotifierProvider.notifier)
        .deactivate(branch.id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err),
            backgroundColor: EnhancedTheme.errorRed),
      );
    }
  }
}

// ── Plan limit banner ─────────────────────────────────────────────────────────

class _LimitBanner extends StatelessWidget {
  final Subscription sub;
  final UsageLimits  limits;
  final bool         hasBranchFeature;

  const _LimitBanner({
    required this.sub,
    required this.limits,
    required this.hasBranchFeature,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasBranchFeature) {
      return _InfoCard(
        color: EnhancedTheme.warningAmber,
        icon:  Icons.lock_rounded,
        title: 'Multi-Branch requires Professional or Enterprise',
        body:  'Upgrade your plan to register and manage multiple branches.',
      );
    }

    final maxB    = limits.maxBranches;
    final current = sub.usage.branchesCount;
    final label   = maxB == -1
        ? 'Unlimited branches'
        : '$current / $maxB branches used';

    return _InfoCard(
      color: EnhancedTheme.primaryTeal,
      icon:  Icons.account_tree_rounded,
      title: label,
      body:  maxB == -1
          ? 'Enterprise plan — add as many branches as you need.'
          : 'Professional plan — up to $maxB branches.',
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color   color;
  final IconData icon;
  final String  title;
  final String  body;

  const _InfoCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Branch card ───────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final Branch   branch;
  final bool     hasBranchFeature;
  final VoidCallback? onEdit;
  final VoidCallback? onSetMain;
  final VoidCallback? onDeactivate;

  const _BranchCard({
    required this.branch,
    required this.hasBranchFeature,
    this.onEdit,
    this.onSetMain,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final color = branch.isMain
        ? EnhancedTheme.primaryTeal
        : EnhancedTheme.infoBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: branch.isMain
                  ? color.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: branch.isMain
                    ? color.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.10),
                width: branch.isMain ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    branch.isMain
                        ? Icons.home_work_rounded
                        : Icons.store_rounded,
                    color: color, size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(branch.name,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          if (branch.isMain) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Main',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      if (branch.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(branch.address,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      if (branch.phone.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(branch.phone,
                            style: const TextStyle(
                                color: Colors.black45, fontSize: 11)),
                      ],
                    ],
                  ),
                ),

                // Menu
                if (hasBranchFeature)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.black45, size: 20),
                    color: EnhancedTheme.surfaceColor,
                    onSelected: (v) {
                      if (v == 'edit')       onEdit?.call();
                      if (v == 'main')       onSetMain?.call();
                      if (v == 'deactivate') onDeactivate?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_rounded,
                              color: Colors.white70, size: 16),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.white70)),
                        ]),
                      ),
                      if (!branch.isMain) ...[
                        const PopupMenuItem(
                          value: 'main',
                          child: Row(children: [
                            Icon(Icons.star_rounded,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text('Set as Main',
                                style: TextStyle(color: Colors.white70)),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Row(children: [
                            Icon(Icons.remove_circle_outline_rounded,
                                color: Colors.redAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Deactivate',
                                style: TextStyle(color: Colors.redAccent)),
                          ]),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         hasBranchFeature;
  final VoidCallback? onAdd;

  const _EmptyState({required this.hasBranchFeature, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              hasBranchFeature
                  ? Icons.account_tree_rounded
                  : Icons.lock_rounded,
              size: 56,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              hasBranchFeature
                  ? 'No branches yet'
                  : 'Upgrade to add branches',
              style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              hasBranchFeature
                  ? 'Tap + to register your first branch.'
                  : 'Professional and Enterprise plans support multi-branch.',
              style: const TextStyle(color: Colors.black38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (hasBranchFeature && onAdd != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Branch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String   message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: EnhancedTheme.errorRed, size: 44),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: EnhancedTheme.primaryTeal)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Branch form sheet (create / edit) ─────────────────────────────────────────

class _BranchFormSheet extends StatefulWidget {
  final Branch? existing;
  final Future<void> Function(
      String name, String address, String phone, String email) onSave;

  const _BranchFormSheet({this.existing, required this.onSave});

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  final _form    = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name    = TextEditingController(text: widget.existing?.name    ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
    _phone   = TextEditingController(text: widget.existing?.phone   ?? '');
    _email   = TextEditingController(text: widget.existing?.email   ?? '');
  }

  @override
  void dispose() {
    _name.dispose(); _address.dispose();
    _phone.dispose(); _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await widget.onSave(
      _name.text.trim(),
      _address.text.trim(),
      _phone.text.trim(),
      _email.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            decoration: BoxDecoration(
              color: EnhancedTheme.surfaceColor.withValues(alpha: 0.97),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12))),
            ),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    isEdit ? 'Edit Branch' : 'New Branch',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    controller: _name,
                    label: 'Branch Name',
                    icon:  Icons.store_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _address,
                    label: 'Address',
                    icon:  Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _phone,
                    label: 'Phone',
                    icon:  Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _email,
                    label: 'Email (optional)',
                    icon:  Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text(
                              isEdit ? 'Save Changes' : 'Create Branch',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final int                   maxLines;
  final TextInputType?        keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines    = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      maxLines:     maxLines,
      keyboardType: keyboardType,
      validator:    validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled:     true,
        fillColor:  Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal),
        ),
      ),
    );
  }
}
