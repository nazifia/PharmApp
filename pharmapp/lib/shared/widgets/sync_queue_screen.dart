import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/offline/connectivity_provider.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/offline/sync_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  SYNC QUEUE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class SyncQueueScreen extends ConsumerStatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  ConsumerState<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends ConsumerState<SyncQueueScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final result = await ref.read(syncServiceProvider).syncAll();
    if (!mounted) return;
    setState(() => _syncing = false);

    final String msg;
    final Color color;
    final IconData icon;

    if (result.connectionFailed) {
      msg   = 'Cannot reach server — items remain queued';
      color = EnhancedTheme.errorRed;
      icon  = Icons.cloud_off_rounded;
    } else if (result.synced == 0 && result.failed == 0) {
      msg   = 'Nothing to sync';
      color = EnhancedTheme.successGreen;
      icon  = Icons.check_circle_rounded;
    } else if (result.failed == 0) {
      msg   = '${result.synced} operation${result.synced == 1 ? '' : 's'} synced successfully';
      color = EnhancedTheme.successGreen;
      icon  = Icons.cloud_done_rounded;
    } else {
      msg   = '${result.synced} synced, ${result.failed} still pending';
      color = EnhancedTheme.warningAmber;
      icon  = Icons.cloud_sync_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      content: Row(children: [
        Icon(icon, color: result.connectionFailed ? Colors.white : Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(
              color: result.connectionFailed ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    ));
  }

  // ── Queue control actions ──────────────────────────────────────────────────

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Clear All Pending Items',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently remove all pending operations from the sync '
          'queue. This action cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: EnhancedTheme.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Clear All',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sales = ref.read(offlineQueueProvider);
    final muts = ref.read(offlineMutationQueueProvider);
    final saleNotifier = ref.read(offlineQueueProvider.notifier);
    final mutNotifier = ref.read(offlineMutationQueueProvider.notifier);
    for (final s in sales) { await saleNotifier.remove(s.id); }
    for (final m in muts)  { await mutNotifier.remove(m.id); }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text(
          'Cleared all ${sales.length + muts.length} pending operations',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    ));
  }

  Future<void> _discardFailed() async {
    final removed = await ref.read(syncServiceProvider).discardFailed();
    if (!mounted || removed == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        const Icon(
          Icons.delete_outline_rounded,
          color: Colors.black,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          'Discarded $removed failed operation${removed == 1 ? '' : 's'}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    ));
  }

  Future<void> _removeSale(String id) async {
    await ref.read(offlineQueueProvider.notifier).remove(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: const Row(children: [
        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
        SizedBox(width: 10),
        Text(
          'Removed from queue',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ]),
    ));
  }

  Future<void> _removeMutation(String id) async {
    await ref.read(offlineMutationQueueProvider.notifier).remove(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: const Row(children: [
        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
        SizedBox(width: 10),
        Text(
          'Removed from queue',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingSales = ref.watch(offlineQueueProvider);
    final pendingMuts = ref.watch(offlineMutationQueueProvider);
    final total = pendingSales.length + pendingMuts.length;
    final failedCount =
        pendingSales.where((e) => e.attempts > 0).length +
        pendingMuts.where((e) => e.attempts > 0).length;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          // Decorative blob
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.warningAmber.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: context.labelColor,
                            size: 20,
                          ),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppShell.roleFallback(ref)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sync Queue',
                              style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              total > 0
                                  ? '$total operation${total == 1 ? '' : 's'} pending'
                                  : 'All caught up',
                              style: TextStyle(
                                color: context.subLabelColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (total > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.warningAmber.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: EnhancedTheme.warningAmber.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_upload_rounded,
                                color: EnhancedTheme.warningAmber,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$total',
                                style: const TextStyle(
                                  color: EnhancedTheme.warningAmber,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(
                  duration: 400.ms,
                ).slideY(begin: -0.1, end: 0),
                const SizedBox(height: 16),

                // ── Connectivity status + Sync button ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isOnline
                                  ? EnhancedTheme.successGreen
                                  : EnhancedTheme.warningAmber)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (isOnline
                                    ? EnhancedTheme.successGreen
                                    : EnhancedTheme.warningAmber)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isOnline
                                        ? EnhancedTheme.successGreen
                                        : EnhancedTheme.warningAmber)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isOnline
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_off_rounded,
                                color: isOnline
                                    ? EnhancedTheme.successGreen
                                    : EnhancedTheme.warningAmber,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOnline ? 'Connected' : 'Offline',
                                    style: GoogleFonts.outfit(
                                      color: isOnline
                                          ? EnhancedTheme.successGreen
                                          : EnhancedTheme.warningAmber,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    isOnline
                                        ? total > 0
                                            ? 'Tap "Sync Now" to push queued changes'
                                            : 'No pending items'
                                        : 'Reconnect to sync queued operations',
                                    style: TextStyle(
                                      color: context.subLabelColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOnline && total > 0)
                              _syncing
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: EnhancedTheme.primaryTeal,
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _syncNow,
                                      icon: const Icon(
                                        Icons.sync_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Sync Now',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            EnhancedTheme.primaryTeal,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 16),

                // ── Queue action buttons ─────────────────────────────────────
                if (total > 0) ...[
                  _actionButtonsBar(total, failedCount),
                  const SizedBox(height: 12),
                ],

                // ── Queue list ───────────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _syncNow,
                    color: EnhancedTheme.primaryTeal,
                    child: total == 0
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: _emptyState(),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            children: [
                              // Pending POS sales
                              if (pendingSales.isNotEmpty) ...[
                                _sectionHeader(
                                  'POS Sales',
                                  pendingSales.length,
                                  Icons.point_of_sale_rounded,
                                  EnhancedTheme.primaryTeal,
                                ),
                                const SizedBox(height: 8),
                                ...pendingSales.asMap().entries.map(
                                  (e) => _saleCard(e.value).animate(
                                    delay: (e.key * 50).ms,
                                  ).fadeIn(
                                    duration: 300.ms,
                                  ).slideY(begin: 0.05, end: 0),
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Pending mutations
                              if (pendingMuts.isNotEmpty) ...[
                                _sectionHeader(
                                  'Other Operations',
                                  pendingMuts.length,
                                  Icons.cloud_upload_rounded,
                                  EnhancedTheme.accentCyan,
                                ),
                                const SizedBox(height: 8),
                                ...pendingMuts.asMap().entries.map(
                                  (e) => _mutationCard(e.value).animate(
                                    delay: (e.key * 50).ms,
                                  ).fadeIn(
                                    duration: 300.ms,
                                  ).slideY(begin: 0.05, end: 0),
                                ),
                              ],
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

  // ── Queue action buttons bar ───────────────────────────────────────────────
  Widget _actionButtonsBar(int total, int failedCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded, size: 15),
              label: const Text(
                'Clear All',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.errorRed,
                side: const BorderSide(
                  color: EnhancedTheme.errorRed,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (failedCount > 0) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _discardFailed,
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: Text(
                  '$failedCount Failed',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EnhancedTheme.warningAmber,
                  side: const BorderSide(
                    color: EnhancedTheme.warningAmber,
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 150.ms);
  }

  Widget _sectionHeader(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.outfit(
            color: context.labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _saleCard(PendingSale sale) {
    final items = (sale.payload['items'] as List<dynamic>?) ?? [];
    final total = (sale.payload['totalAmount'] as num?)?.toDouble();
    final isWholesale = sale.payload['isWholesale'] as bool? ?? false;
    final method = (sale.payload['paymentMethod'] as String?) ?? '';
    final queued = _formatTime(sale.queuedAt);

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_rounded,
                    color: EnhancedTheme.primaryTeal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isWholesale ? 'Wholesale Sale' : 'Retail Sale',
                        style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${items.length} item${items.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: context.subLabelColor,
                              fontSize: 12,
                            ),
                          ),
                          if (method.isNotEmpty) ...[
                            Text(
                              ' \u00b7 ',
                              style: TextStyle(
                                color: context.hintColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              method,
                              style: TextStyle(
                                color: context.subLabelColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        queued,
                        style: TextStyle(
                          color: context.hintColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (total != null)
                      Text(
                        'N${total.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          color: EnhancedTheme.primaryTeal,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (sale.attempts > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.warningAmber.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${sale.attempts} attempt${sale.attempts == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: EnhancedTheme.warningAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key('sale_${sale.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: EnhancedTheme.errorRed,
          size: 24,
        ),
      ),
      onDismissed: (_) => _removeSale(sale.id),
      child: card,
    );
  }

  Widget _mutationCard(PendingMutation m) {
    final queued = _formatTime(m.queuedAt);
    final color = _methodColor(m.method);
    final icon = _opIcon(m.path);

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.description.isNotEmpty
                            ? m.description
                            : '${m.method} ${m.path}',
                        style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        queued,
                        style: TextStyle(
                          color: context.hintColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.method,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (m.attempts > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.warningAmber.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${m.attempts} attempt${m.attempts == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: EnhancedTheme.warningAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

    return Dismissible(
      key: Key('mut_${m.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: EnhancedTheme.errorRed,
          size: 24,
        ),
      ),
      onDismissed: (_) => _removeMutation(m.id),
      child: card,
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  EnhancedTheme.successGreen.withValues(alpha: 0.12),
                  EnhancedTheme.successGreen.withValues(alpha: 0.03),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: EnhancedTheme.successGreen,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'All synced!',
            style: GoogleFonts.outfit(
              color: context.labelColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No pending operations',
            style: TextStyle(color: context.subLabelColor, fontSize: 13),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1, 1),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
        return EnhancedTheme.successGreen;
      case 'PATCH':
      case 'PUT':
        return EnhancedTheme.infoBlue;
      case 'DELETE':
        return EnhancedTheme.errorRed;
      default:
        return EnhancedTheme.accentCyan;
    }
  }

  IconData _opIcon(String path) {
    if (path.contains('inventory')) return Icons.inventory_2_rounded;
    if (path.contains('customers')) return Icons.people_rounded;
    if (path.contains('payment')) return Icons.payment_rounded;
    if (path.contains('expense')) return Icons.account_balance_wallet_rounded;
    if (path.contains('supplier')) return Icons.storefront_rounded;
    if (path.contains('procurement')) return Icons.local_shipping_rounded;
    if (path.contains('stock-check')) return Icons.fact_check_rounded;
    if (path.contains('transfer')) return Icons.swap_horiz_rounded;
    if (path.contains('users') || path.contains('auth')) {
      return Icons.person_rounded;
    }
    if (path.contains('notification')) return Icons.notifications_rounded;
    return Icons.cloud_upload_rounded;
  }
}
