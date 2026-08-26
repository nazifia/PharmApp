import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';

/// Confirms a write-off, then zeroes the stock of the expired items.
///
/// [itemIds] null = every expired item in the organisation; otherwise only
/// those items. Returns true when stock was actually written off.
Future<bool> confirmWriteOffExpired(
  BuildContext context,
  WidgetRef ref, {
  List<int>? itemIds,
  required int count,
  required double costValue,
}) async {
  if (count == 0) return false;
  final messenger = ScaffoldMessenger.of(context);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        const Icon(Icons.delete_forever_rounded,
            color: EnhancedTheme.errorRed, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Write off expired stock',
                style: TextStyle(
                    color: ctx.labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700))),
      ]),
      content: Text(
        'This sets the stock of $count expired item(s) to zero and marks them '
        'inactive. ${fmtN(costValue)} at cost will be recorded as a loss.\n\n'
        'The items are kept for audit but can no longer be sold. '
        'This cannot be undone.',
        style: TextStyle(color: ctx.subLabelColor, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.subLabelColor))),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.errorRed,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Write off'),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    final result = await ref
        .read(inventoryNotifierProvider.notifier)
        .writeOffExpired(itemIds: itemIds);
    messenger.showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Text(
          'Wrote off ${result.count} item(s) — ${fmtN(result.costValue)} at cost',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    ));
    return result.count > 0;
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Text('$e'.replaceFirst('Exception: ', ''),
          style: const TextStyle(color: Colors.white)),
    ));
    return false;
  }
}
