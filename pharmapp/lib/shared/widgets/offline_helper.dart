import 'package:flutter/material.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

/// Show a consistent "queued for offline sync" snackbar.
void showQueuedSnackbar(BuildContext context, String description) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    content: Row(children: [
      const Icon(Icons.cloud_upload_rounded, color: Colors.black, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          '$description — queued for sync',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
    ]),
  ));
}
