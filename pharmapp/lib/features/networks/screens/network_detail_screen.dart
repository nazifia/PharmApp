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

class NetworkDetailScreen extends ConsumerWidget {
  final int networkId;
  const NetworkDetailScreen({super.key, required this.networkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkAsync = ref.watch(networkDetailProvider(networkId));
    final user = ref.watch(currentUserProvider);
    final isAdmin = Rbac.isSenior(user);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
          SafeArea(
            child: networkAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: EnhancedTheme.accentPurple,
                        backgroundColor:
                            EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading network…',
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
                        color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_off_rounded,
                          color: EnhancedTheme.errorRed, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load network',
                      style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text('$e',
                          style: TextStyle(
                              color: context.subLabelColor, fontSize: 12),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.invalidate(networkDetailProvider(networkId)),
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
              data: (network) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(networkDetailProvider(networkId)),
                color: EnhancedTheme.accentPurple,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(context, ref, network),
                    ),
                    SliverToBoxAdapter(
                      child: _buildNetworkInfo(context, network),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: _sectionHeader(
                          context,
                          'Members (${network.members.length})',
                          Icons.people_rounded,
                          EnhancedTheme.accentPurple,
                        ),
                      ),
                    ),
                    if (network.members.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: context.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      color: context.hintColor, size: 18),
                                  const SizedBox(width: 12),
                                  Text('No members yet',
                                      style: TextStyle(
                                          color: context.subLabelColor,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: _MemberCard(
                              member: network.members[i],
                              networkId: network.id,
                              isAdmin: isAdmin,
                              currentOrgId:
                                  user?.organizationId ?? 0,
                            ),
                          ).animate(delay: (i * 40).ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.15, end: 0),
                          childCount: network.members.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, PharmacyNetwork network) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  network.name,
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: network.isActive
                            ? EnhancedTheme.successGreen
                            : EnhancedTheme.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      network.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          color: context.hintColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.subLabelColor),
            onPressed: () => ref.invalidate(networkDetailProvider(networkId)),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfo(BuildContext context, PharmacyNetwork network) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                  EnhancedTheme.accentPurple.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hub_rounded,
                          color: EnhancedTheme.accentPurple, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            network.name,
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '@${network.slug}',
                            style: const TextStyle(
                                color: EnhancedTheme.accentPurple,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (network.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    network.description,
                    style: TextStyle(
                        color: context.subLabelColor, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statChip(
                      Icons.people_rounded,
                      '${network.memberCount}',
                      'Members',
                      EnhancedTheme.accentCyan,
                    ),
                    const SizedBox(width: 10),
                    _statChip(
                      Icons.calendar_today_rounded,
                      _formatDate(network.createdAt),
                      'Created',
                      EnhancedTheme.primaryTeal,
                    ),
                    if (network.myRole != null) ...[
                      const SizedBox(width: 10),
                      _statChip(
                        Icons.verified_rounded,
                        network.myRole!,
                        'Your Role',
                        EnhancedTheme.warningAmber,
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

  Widget _statChip(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.7), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  Widget _sectionHeader(
          BuildContext context, String title, IconData icon, Color color) =>
      Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
                color: context.labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
        ],
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

class _MemberCard extends ConsumerStatefulWidget {
  final NetworkMembership member;
  final int networkId;
  final bool isAdmin;
  final int currentOrgId;

  const _MemberCard({
    required this.member,
    required this.networkId,
    required this.isAdmin,
    required this.currentOrgId,
  });

  @override
  ConsumerState<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends ConsumerState<_MemberCard> {
  bool _removing = false;

  Future<void> _removeMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Member?',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove ${widget.member.organizationName} from this network?',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    final ok = await ref
        .read(networkNotifierProvider.notifier)
        .removeMember(widget.networkId, widget.member.organizationId);
    if (!mounted) return;
    setState(() => _removing = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text(
          '${widget.member.organizationName} removed',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ));
    } else {
      final err = ref.read(networkNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text(
          'Error: $err',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isOwner = m.isOwner;
    final isSelf = m.organizationId == widget.currentOrgId;
    final accentColor =
        isOwner ? EnhancedTheme.warningAmber : EnhancedTheme.accentPurple;
    final canRemove =
        widget.isAdmin && !isSelf && !isOwner && m.isActive;

    final initials = m.organizationName
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.28),
                      accentColor.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : '?',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.organizationName,
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                  color: EnhancedTheme.primaryTeal,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _chip(
                          isOwner ? 'Owner' : 'Member',
                          accentColor,
                        ),
                        const SizedBox(width: 6),
                        _chip(
                          m.status,
                          m.isActive
                              ? EnhancedTheme.successGreen
                              : EnhancedTheme.warningAmber,
                        ),
                        if (m.joinedAt != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(m.joinedAt!),
                            style: TextStyle(
                                color: context.hintColor, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 10),
                _removing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EnhancedTheme.errorRed,
                          backgroundColor:
                              EnhancedTheme.errorRed.withValues(alpha: 0.1),
                        ),
                      )
                    : GestureDetector(
                        onTap: _removeMember,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                EnhancedTheme.errorRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: EnhancedTheme.errorRed
                                    .withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.person_remove_rounded,
                              color: EnhancedTheme.errorRed, size: 16),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700),
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
