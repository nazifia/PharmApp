import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/superuser/providers/superuser_api_client.dart';
import 'package:pharmapp/features/superuser/providers/superuser_provider.dart';
import 'package:pharmapp/shared/models/org_subscription_summary.dart';

/// Two-step confirmation for permanently deleting a tenant, shared by the
/// dashboard card and the org subscription editor.
///
/// Step 1 previews the cascade (fetched from the backend, nothing deleted).
/// Step 2 requires typing the org name. Returns true only if the org was
/// actually deleted; the org list is updated on success, so callers only need
/// to handle their own navigation.
Future<bool> confirmDeleteOrg(
  BuildContext context,
  WidgetRef ref,
  OrgSubscriptionSummary org,
) async {
  final api       = ref.read(superuserApiClientProvider);
  final messenger = ScaffoldMessenger.of(context);

  // ponytail: no spinner while the preview loads — one small GET.
  Map<String, int>? impact;
  try {
    impact = await api.getOrgDeletionImpact(org.id);
  } catch (_) {
    impact = null; // preview unavailable; the warning below still stands
  }
  if (!context.mounted) return false;

  // ── Step 1: impact preview ────────────────────────────────────────────────
  final step1 = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
          SizedBox(width: 8),
          Text('Delete Organization',
              style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permanently delete "${org.name}" and all its data?',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 12),
          if (impact != null) ...[
            const Text('This will delete:',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            ...impact.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_circle_outlined,
                          color: Color(0xFFEF4444), size: 12),
                      const SizedBox(width: 6),
                      Text('${e.value} ${e.key}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 12),
          const Text('This action cannot be undone.',
              style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Continue')),
      ],
    ),
  );
  if (step1 != true || !context.mounted) return false;

  // ── Step 2: type the org name ─────────────────────────────────────────────
  final nameCtrl = TextEditingController();
  final step2 = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirm Deletion',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                children: [
                  const TextSpan(text: 'Type '),
                  TextSpan(
                      text: org.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' to confirm:'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                hintText: org.name,
                hintStyle: const TextStyle(color: Colors.white24),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) => setS(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
              onPressed: nameCtrl.text.trim() == org.name
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Delete Forever')),
        ],
      ),
    ),
  );
  nameCtrl.dispose();
  if (step2 != true) return false;

  try {
    await api.deleteOrganization(org.id);
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: EnhancedTheme.errorRed));
    return false;
  }

  ref.read(orgListProvider.notifier).removeOrg(org.id);
  messenger.showSnackBar(SnackBar(
      content: Text('${org.name} deleted.'),
      backgroundColor: EnhancedTheme.errorRed));
  return true;
}
