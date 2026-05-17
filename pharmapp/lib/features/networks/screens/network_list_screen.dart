import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/networks/providers/network_provider.dart';
import 'package:pharmapp/shared/widgets/app_drawer.dart';

class NetworkListScreen extends ConsumerWidget {
  const NetworkListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = Rbac.isSenior(user);
    final myNetworksAsync = ref.watch(myNetworksProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/dashboard/network/create'),
              backgroundColor: EnhancedTheme.primaryTeal,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: Text(
                'Create Network',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700, color: Colors.black),
              ),
            )
          : null,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, ref),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myNetworksProvider),
                    color: EnhancedTheme.primaryTeal,
                    child: myNetworksAsync.when(
                      loading: () => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: EnhancedTheme.primaryTeal,
                                backgroundColor: EnhancedTheme.primaryTeal
                                    .withValues(alpha: 0.15),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading networks…',
                              style: TextStyle(
                                  color: context.subLabelColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.errorRed
                                    .withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_off_rounded,
                                  color: EnhancedTheme.errorRed, size: 40),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Connection Error',
                              style: GoogleFonts.outfit(
                                  color: context.labelColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                '$e',
                                style: TextStyle(
                                    color: context.subLabelColor, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => ref.invalidate(myNetworksProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EnhancedTheme.primaryTeal,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      data: (memberships) {
                        if (memberships.isEmpty) {
                          return _buildEmptyState(context);
                        }
                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 110),
                          itemCount: memberships.length,
                          itemBuilder: (_, i) => _NetworkCard(
                            membership: memberships[i],
                            isAdmin: isAdmin,
                          )
                              .animate(delay: (i * 50).ms)
                              .fadeIn(duration: 350.ms)
                              .slideY(begin: 0.2, end: 0),
                        );
                      },
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

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(
                ctx.canPop()
                    ? Icons.arrow_back_rounded
                    : Icons.menu_rounded,
                color: context.labelColor,
              ),
              onPressed: () =>
                  ctx.canPop() ? ctx.pop() : Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pharmacy Networks',
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  'Collaborate with partner pharmacies',
                  style:
                      TextStyle(color: context.subLabelColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.subLabelColor),
            onPressed: () => ref.invalidate(myNetworksProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                  EnhancedTheme.accentPurple.withValues(alpha: 0.03),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: EnhancedTheme.accentPurple,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No networks yet',
            style: GoogleFonts.outfit(
                color: context.labelColor,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Create or join a pharmacy network\nto collaborate with partners',
            style: TextStyle(color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9)),
    );
  }
}

class _NetworkCard extends ConsumerStatefulWidget {
  final NetworkMembership membership;
  final bool isAdmin;

  const _NetworkCard({required this.membership, required this.isAdmin});

  @override
  ConsumerState<_NetworkCard> createState() => _NetworkCardState();
}

class _NetworkCardState extends ConsumerState<_NetworkCard> {
  bool _loading = false;

  Future<void> _handleLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Leave Network?',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You will lose access to ${widget.membership.networkName}.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    final ok = await ref
        .read(networkNotifierProvider.notifier)
        .leaveNetwork(widget.membership.networkId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
          'Left ${widget.membership.networkName}', EnhancedTheme.successGreen));
    } else {
      final err = ref.read(networkNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
          _snack('Error: $err', EnhancedTheme.errorRed));
    }
  }

  Future<void> _handleAccept() async {
    setState(() => _loading = true);
    final ok = await ref
        .read(networkNotifierProvider.notifier)
        .acceptInvitation(widget.membership.networkId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          _snack('Joined ${widget.membership.networkName}',
              EnhancedTheme.successGreen));
    } else {
      final err = ref.read(networkNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
          _snack('Error: $err', EnhancedTheme.errorRed));
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _loading = true);
    final ok = await ref
        .read(networkNotifierProvider.notifier)
        .declineInvitation(widget.membership.networkId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          _snack('Invitation declined', EnhancedTheme.warningAmber));
    } else {
      final err = ref.read(networkNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
          _snack('Error: $err', EnhancedTheme.errorRed));
    }
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
        backgroundColor: color.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final m = widget.membership;
    final isPending = m.isPending;
    final isOwner = m.isOwner;
    final accentColor = isOwner
        ? EnhancedTheme.warningAmber
        : isPending
            ? EnhancedTheme.accentCyan
            : EnhancedTheme.accentPurple;

    return GestureDetector(
      onTap: () => context.push('/dashboard/network/${m.networkId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPending
                      ? EnhancedTheme.accentCyan.withValues(alpha: 0.4)
                      : context.borderColor,
                  width: isPending ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.25),
                              accentColor.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.4),
                              width: 1.5),
                        ),
                        child: Icon(Icons.hub_rounded,
                            color: accentColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.networkName,
                              style: GoogleFonts.outfit(
                                  color: context.labelColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _statusChip(
                                  isPending
                                      ? 'Pending'
                                      : isOwner
                                          ? 'Owner'
                                          : 'Member',
                                  accentColor,
                                ),
                                const SizedBox(width: 8),
                                _statusChip(m.status.toUpperCase(),
                                    m.isActive
                                        ? EnhancedTheme.successGreen
                                        : EnhancedTheme.warningAmber),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.hintColor, size: 20),
                    ],
                  ),
                  if (m.joinedAt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: context.hintColor, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'Joined ${_formatDate(m.joinedAt!)}',
                          style: TextStyle(
                              color: context.subLabelColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_loading)
                    Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accentColor,
                          backgroundColor:
                              accentColor.withValues(alpha: 0.1),
                        ),
                      ),
                    )
                  else if (isPending)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _handleDecline,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.errorRed
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: EnhancedTheme.errorRed
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close_rounded,
                                      color: EnhancedTheme.errorRed,
                                      size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Decline',
                                    style: TextStyle(
                                        color: EnhancedTheme.errorRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _handleAccept,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    EnhancedTheme.primaryTeal,
                                    EnhancedTheme.accentCyan,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      color: Colors.black, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Accept',
                                    style: GoogleFonts.outfit(
                                        color: Colors.black,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context
                                .push('/dashboard/network/${m.networkId}'),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        accentColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.visibility_rounded,
                                      color: accentColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'View Details',
                                    style: TextStyle(
                                        color: accentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _handleLeave,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.errorRed
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: EnhancedTheme.errorRed
                                      .withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: EnhancedTheme.errorRed,
                                    size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Leave',
                                  style: TextStyle(
                                      color: EnhancedTheme.errorRed,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
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
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
