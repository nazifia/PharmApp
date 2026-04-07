import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/superuser/providers/superuser_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';

/// Superuser screen for editing the global plan → feature matrix.
///
/// Each row is a feature; each column is a plan tier.  Tap a cell to toggle.
/// Long-press a feature row to rename or delete it.
/// Use the FAB to add a brand-new feature key.
/// Changes are staged locally until the "Save" button is tapped.
class PlanFeatureEditorScreen extends ConsumerStatefulWidget {
  const PlanFeatureEditorScreen({super.key});

  @override
  ConsumerState<PlanFeatureEditorScreen> createState() =>
      _PlanFeatureEditorScreenState();
}

class _PlanFeatureEditorScreenState
    extends ConsumerState<PlanFeatureEditorScreen> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final error =
        await ref.read(planFeatureMatrixProvider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $error'),
        backgroundColor: EnhancedTheme.errorRed,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Plan features saved.'),
        backgroundColor: EnhancedTheme.successGreen,
      ));
    }
  }

  // ── Add feature dialog ─────────────────────────────────────────────────────

  Future<void> _showAddFeatureDialog() async {
    final keyCtrl   = TextEditingController();
    final labelCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Feature',
            style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: keyCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Feature key (snake_case)'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: labelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Display label'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref
          .read(planFeatureMatrixProvider.notifier)
          .addFeature(keyCtrl.text.trim(), labelCtrl.text.trim());
    }
    keyCtrl.dispose();
    labelCtrl.dispose();
  }

  // ── Rename feature dialog ──────────────────────────────────────────────────

  Future<void> _showRenameDialog(String key, String currentLabel) async {
    final ctrl = TextEditingController(text: currentLabel);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rename Feature',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Display label'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      ref
          .read(planFeatureMatrixProvider.notifier)
          .renameFeature(key, ctrl.text.trim());
    }
    ctrl.dispose();
  }

  // ── Delete feature dialog ──────────────────────────────────────────────────

  Future<void> _showDeleteDialog(String key, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Feature',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "$label" from all plans?  This cannot be undone once saved.',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(planFeatureMatrixProvider.notifier).removeFeature(key);
    }
  }

  // ── Feature row long-press menu ────────────────────────────────────────────

  void _showFeatureMenu(
      BuildContext context, String key, String label) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: EnhancedTheme.primaryTeal),
              title: const Text('Rename',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(key, label);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded,
                  color: EnhancedTheme.errorRed),
              title: const Text('Delete from all plans',
                  style: TextStyle(color: EnhancedTheme.errorRed)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(key, label);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final matrixAsync = ref.watch(planFeatureMatrixProvider);

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFeatureDialog,
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Feature',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
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
                            : context.go('/superuser'),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Plan Feature Matrix',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            Text('Tap a cell to toggle  ·  Long-press to rename/delete',
                                style: TextStyle(
                                    color: Colors.black45, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (_saving)
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: EnhancedTheme.primaryTeal),
                        )
                      else ...[
                        IconButton(
                          tooltip: 'Reload from server',
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.black54, size: 20),
                          onPressed: () => ref
                              .read(planFeatureMatrixProvider.notifier)
                              .reload(),
                        ),
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
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Matrix body ────────────────────────────────────────────
                Expanded(
                  child: matrixAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: EnhancedTheme.primaryTeal),
                    ),
                    error: (e, _) => Center(
                      child: Text(e.toString(),
                          style:
                              const TextStyle(color: Colors.white54)),
                    ),
                    data: (matrix) => _MatrixBody(
                      matrix: matrix,
                      onToggle: (planName, feature) => ref
                          .read(planFeatureMatrixProvider.notifier)
                          .toggleFeatureInPlan(planName, feature),
                      onLongPress: (key, label) =>
                          _showFeatureMenu(context, key, label),
                      onReorder: (oldIndex, newIndex) => ref
                          .read(planFeatureMatrixProvider.notifier)
                          .reorderFeatures(oldIndex, newIndex),
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

  static InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: EnhancedTheme.primaryTeal)),
      );
}

// ── Matrix body ────────────────────────────────────────────────────────────────

class _MatrixBody extends StatelessWidget {
  final PlanFeatureMatrix    matrix;
  final void Function(String planName, String feature) onToggle;
  final void Function(String key, String label)        onLongPress;
  final void Function(int oldIndex, int newIndex)      onReorder;

  const _MatrixBody({
    required this.matrix,
    required this.onToggle,
    required this.onLongPress,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final plans       = SubscriptionPlan.values;
    final featureKeys = matrix.featureOrder;

    return Column(
      children: [
        // ── Sticky header row (plan names) ─────────────────────────────────
        _PlanHeaderRow(plans: plans),

        // ── Reorderable feature rows ───────────────────────────────────────
        Expanded(
          child: featureKeys.isEmpty
              ? const Center(
                  child: Text('No features yet.  Tap + to add one.',
                      style: TextStyle(color: Colors.white38)))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 100),
                  itemCount: featureKeys.length,
                  onReorder: onReorder,
                  itemBuilder: (_, i) {
                    final key   = featureKeys[i];
                    final label = matrix.labelFor(key);
                    return _FeatureRow(
                      key:       ValueKey(key),
                      featureKey: key,
                      label:     label,
                      plans:     plans,
                      matrix:    matrix,
                      onToggle:  onToggle,
                      onLongPress: () => onLongPress(key, label),
                      isLast:    i == featureKeys.length - 1,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Plan header row ────────────────────────────────────────────────────────────

class _PlanHeaderRow extends StatelessWidget {
  final List<SubscriptionPlan> plans;
  const _PlanHeaderRow({required this.plans});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              // Feature label column
              const Expanded(
                child: Text('Feature',
                    style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              // Plan columns
              ...plans.map(
                (p) => SizedBox(
                  width: 66,
                  child: Column(
                    children: [
                      Icon(_planIcon(p), color: _planColor(p), size: 14),
                      const SizedBox(height: 2),
                      Text(
                        p.displayName.split(' ').first,
                        style: TextStyle(
                            color: _planColor(p),
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              // Drag handle placeholder so content aligns
              const SizedBox(width: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final String                featureKey;
  final String                label;
  final List<SubscriptionPlan> plans;
  final PlanFeatureMatrix     matrix;
  final void Function(String planName, String feature) onToggle;
  final VoidCallback          onLongPress;
  final bool                  isLast;

  const _FeatureRow({
    super.key,
    required this.featureKey,
    required this.label,
    required this.plans,
    required this.matrix,
    required this.onToggle,
    required this.onLongPress,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Feature label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 12)),
                    Text(featureKey,
                        style: const TextStyle(
                            color: Colors.black38, fontSize: 9)),
                  ],
                ),
              ),

              // Plan checkboxes
              ...plans.map((p) {
                final enabled = matrix.planHasFeature(p.name, featureKey);
                return SizedBox(
                  width: 66,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => onToggle(p.name, featureKey),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled
                              ? _planColor(p).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: enabled
                                ? _planColor(p).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.12),
                            width: enabled ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(
                          enabled
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 14,
                          color: enabled
                              ? _planColor(p)
                              : Colors.black26,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Drag handle (for reordering)
              ReorderableDragStartListener(
                index: matrix.featureOrder.indexOf(featureKey),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.drag_handle_rounded,
                      color: Colors.black26, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _planColor(SubscriptionPlan p) => switch (p) {
      SubscriptionPlan.trial        => EnhancedTheme.accentOrange,
      SubscriptionPlan.starter      => EnhancedTheme.infoBlue,
      SubscriptionPlan.professional => EnhancedTheme.accentPurple,
      SubscriptionPlan.enterprise   => EnhancedTheme.accentCyan,
    };

IconData _planIcon(SubscriptionPlan p) => switch (p) {
      SubscriptionPlan.trial        => Icons.science_rounded,
      SubscriptionPlan.starter      => Icons.rocket_launch_rounded,
      SubscriptionPlan.professional => Icons.workspace_premium_rounded,
      SubscriptionPlan.enterprise   => Icons.diamond_rounded,
    };
