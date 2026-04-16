import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/shared/models/branch.dart';

class BranchSelectionScreen extends ConsumerStatefulWidget {
  const BranchSelectionScreen({super.key});

  @override
  ConsumerState<BranchSelectionScreen> createState() =>
      _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends ConsumerState<BranchSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  bool _refreshing     = false;
  bool _autoRefreshing = false;

  // ── Light-mode palette (matches LoginScreen) ─────────────────────────────
  static const _bg1      = Color(0xFFE0F2FE);
  static const _bg2      = Color(0xFFF0FAFA);
  static const _bg3      = Color(0xFFF8FAFC);
  static const _textDark = Color(0xFF0F172A);
  static const _textSub  = Color(0xFF64748B);
  static const _textHint = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // Trigger branch list fetch + auto-check backend for assigned branch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(branchNotifierProvider.notifier).load();

      // Non-admin users with no cached branch: the session-restore background
      // refresh may not have finished yet. Auto-trigger it so the user never
      // has to manually press "Check Again" after a branch was assigned by admin.
      final user      = ref.read(currentUserProvider);
      final isAdmin   = const {'Admin', 'Manager', 'Wholesale Manager'}.contains(user?.role);
      if (user != null && !isAdmin && user.branchId == 0) {
        _triggerAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _selectBranch(Branch branch) {
    ref.read(authFlowProvider.notifier).selectBranch(branch);
    // Router re-evaluates via _GoRouterNotifier → navigates to role route.
  }

  void _skipSelection() {
    ref.read(authFlowProvider.notifier).skipBranchSelection();
    // Router redirect fires → role route.
  }

  void _logout() {
    ref.read(authServiceProvider).logout();
    context.go('/login');
  }

  /// Silently refreshes the user profile on screen mount. Shows a loading
  /// spinner instead of "No Branch Assigned" while waiting. If the backend
  /// returns a non-zero branchId the router auto-redirects; if not, the
  /// "No Branch Assigned" message is shown with the manual "Check Again" option.
  Future<void> _triggerAutoRefresh() async {
    if (!mounted) return;
    setState(() => _autoRefreshing = true);
    await ref.read(authFlowProvider.notifier).refreshProfile();
    if (mounted) setState(() => _autoRefreshing = false);
  }

  Future<void> _refreshProfile() async {
    setState(() => _refreshing = true);
    await ref.read(authFlowProvider.notifier).refreshProfile();
    if (mounted) setState(() => _refreshing = false);
    // Router auto-redirects if branchId is now set (activeBranchProvider changed).
  }

  @override
  Widget build(BuildContext context) {
    final user          = ref.watch(currentUserProvider);
    final asyncBranches = ref.watch(branchNotifierProvider);
    final orgName       = user?.organizationName.isNotEmpty == true
        ? user!.organizationName
        : 'Your Organisation';
    final isAdminRole   = const {'Admin', 'Manager', 'Wholesale Manager'}
        .contains(user?.role);

    return Scaffold(
      backgroundColor: _bg3,
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bg1, _bg2, _bg3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -90, left: -70,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // AppBar row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.logout_rounded,
                              color: _textSub, size: 20),
                          tooltip: 'Sign out',
                          onPressed: _logout,
                        ),
                        const Spacer(),
                        if (isAdminRole)
                          TextButton(
                            onPressed: _skipSelection,
                            child: const Text(
                              'All Branches',
                              style: TextStyle(
                                  color: EnhancedTheme.primaryTeal,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.store_outlined,
                            color: EnhancedTheme.primaryTeal,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          orgName,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select a branch to continue',
                          style: TextStyle(color: _textSub, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Non-admin users must have a backend-assigned branch.
                  // Show a spinner while auto-checking; show the blocking UI
                  // only after the backend confirms branchId is still 0.
                  if (!isAdminRole && (user?.branchId ?? 0) == 0)
                    Expanded(
                      child: _autoRefreshing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: EnhancedTheme.primaryTeal,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: EnhancedTheme.warningAmber.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.no_accounts_rounded,
                                        color: EnhancedTheme.warningAmber,
                                        size: 48,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No Branch Assigned',
                                      style: TextStyle(
                                        color: _textDark,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Your account has not been assigned to a branch yet. '
                                      'Please contact your administrator to get access.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _textSub, fontSize: 13, height: 1.5),
                                    ),
                                    const SizedBox(height: 28),
                                    FilledButton.icon(
                                      onPressed: _refreshing ? null : _refreshProfile,
                                      icon: _refreshing
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.refresh_rounded, size: 16),
                                      label: Text(_refreshing ? 'Checking…' : 'Check Again'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: EnhancedTheme.primaryTeal,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(Radius.circular(12)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _logout,
                                      icon: const Icon(Icons.logout_rounded, size: 16),
                                      label: const Text('Sign Out'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: EnhancedTheme.errorRed,
                                        side: const BorderSide(color: EnhancedTheme.errorRed),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(Radius.circular(12)),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                  // Branch list (admin / manager roles only, or users with an
                  // assigned branch — the latter are routed past this screen
                  // by the router so this list is effectively admin-only)
                  if (isAdminRole || (user?.branchId ?? 0) != 0)
                  Expanded(
                    child: asyncBranches.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: EnhancedTheme.primaryTeal,
                          strokeWidth: 2.5,
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined,
                                  color: _textHint, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Could not load branches',
                                style: const TextStyle(
                                    color: _textDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.toString().replaceFirst('Exception: ', ''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: _textSub, fontSize: 12),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.tonal(
                                onPressed: () => ref
                                    .read(branchNotifierProvider.notifier)
                                    .load(),
                                child: const Text('Retry'),
                              ),
                              if (isAdminRole) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _skipSelection,
                                  child: const Text(
                                    'Continue without a branch',
                                    style: TextStyle(
                                        color: EnhancedTheme.primaryTeal),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      data: (branches) {
                        final active = branches
                            .where((b) => b.isActive)
                            .toList();

                        if (active.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.store_mall_directory_outlined,
                                      color: _textHint, size: 48),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No branches found',
                                    style: TextStyle(
                                        color: _textDark,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Ask your admin to set up branches first.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: _textSub, fontSize: 12),
                                  ),
                                  const SizedBox(height: 20),
                                  if (isAdminRole)
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                          backgroundColor:
                                              EnhancedTheme.primaryTeal),
                                      onPressed: _skipSelection,
                                      child: const Text('Continue'),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: active.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _BranchCard(
                            branch: active[i],
                            onTap: () => _selectBranch(active[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Branch card ────────────────────────────────────────────────────────────────

class _BranchCard extends StatefulWidget {
  final Branch branch;
  final VoidCallback onTap;

  const _BranchCard({required this.branch, required this.onTap});

  @override
  State<_BranchCard> createState() => _BranchCardState();
}

class _BranchCardState extends State<_BranchCard> {
  bool _pressed = false;

  static const _textDark   = Color(0xFF0F172A);
  static const _textSub    = Color(0xFF64748B);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale:    _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.branch.isMain
                          ? Icons.home_work_outlined
                          : Icons.store_outlined,
                      color: EnhancedTheme.primaryTeal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.branch.name,
                                style: const TextStyle(
                                  color: _textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.branch.isMain)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EnhancedTheme.primaryTeal
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Main',
                                  style: TextStyle(
                                    color: EnhancedTheme.primaryTeal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (widget.branch.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.branch.address,
                            style: const TextStyle(
                                color: _textSub, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.branch.phone.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.branch.phone,
                            style: const TextStyle(
                                color: _textSub, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

