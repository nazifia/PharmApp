import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<dynamic>> _future;
  int _unreadCount = 0;
  List<dynamic>? _notifications;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final api = ref.read(posApiProvider);
    _future = api.fetchNotifications();
    api.fetchNotificationCount().then((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  void _refresh() {
    setState(_loadData);
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'low_stock':       return Icons.inventory_2_rounded;
      case 'out_of_stock':    return Icons.remove_shopping_cart_rounded;
      case 'expiry_alert':    return Icons.hourglass_bottom_rounded;
      case 'payment_request': return Icons.payments_rounded;
      default:                return Icons.campaign_rounded;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'low_stock':       return EnhancedTheme.warningAmber;
      case 'out_of_stock':    return EnhancedTheme.errorRed;
      case 'expiry_alert':    return EnhancedTheme.accentOrange;
      case 'payment_request': return EnhancedTheme.successGreen;
      default:                return EnhancedTheme.infoBlue;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'low_stock':       return 'Low Stock';
      case 'out_of_stock':    return 'Out of Stock';
      case 'expiry_alert':    return 'Expiry Alert';
      case 'payment_request': return 'Payment';
      default:                return 'System';
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'low':      return Colors.grey;
      case 'medium':   return EnhancedTheme.infoBlue;
      case 'high':     return EnhancedTheme.warningAmber;
      case 'critical': return EnhancedTheme.errorRed;
      default:         return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    final id = n['id'];
    if (id == null) return;
    final isRead = n['isRead'] == true;
    if (isRead) return;
    try {
      await ref.read(posApiProvider).markNotificationRead(id as int);
      if (!mounted) return;
      setState(() {
        n['isRead'] = true;
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (_) {}
  }

  Future<void> _dismiss(Map<String, dynamic> n, List<dynamic> notifications) async {
    final id = n['id'];
    if (id == null) return;
    try {
      await ref.read(posApiProvider).deleteNotification(id as int);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      notifications.remove(n);
      if (n['isRead'] != true && _unreadCount > 0) _unreadCount--;
    });
  }

  Future<void> _markAllRead(List<dynamic> notifications) async {
    try {
      await ref.read(posApiProvider).markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in notifications) {
          (n as Map<String, dynamic>)['isRead'] = true;
        }
        _unreadCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: EnhancedTheme.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative top gradient blob
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.infoBlue.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(child: Column(children: [
          _buildHeader(context),
          Expanded(child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: EnhancedTheme.primaryTeal,
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildSkeletonList();
                }
                if (snap.hasError) {
                  return ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                    _buildErrorState(snap.error),
                  ]);
                }
                final notifications = snap.data ?? [];
                // Cache for header actions
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _notifications != notifications) {
                    setState(() => _notifications = notifications);
                  }
                });
                if (notifications.isEmpty) {
                  return ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                    _buildEmptyState(),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: notifications.length,
                  itemBuilder: (_, i) {
                    final n = notifications[i] as Map<String, dynamic>;
                    return Dismissible(
                      key: ValueKey(n['id'] ?? i),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: EnhancedTheme.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: EnhancedTheme.errorRed, size: 24),
                      ),
                      confirmDismiss: (_) async => true,
                      onDismissed: (_) => _dismiss(n, notifications),
                      child: _notificationCard(n, i),
                    );
                  },
                );
              },
            ),
          )),
        ])),
      ]),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: EnhancedTheme.loadingShimmer(height: 100, radius: 16),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.cloud_off_rounded,
              color: EnhancedTheme.errorRed, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Connection Error',
            style: GoogleFonts.outfit(color: context.labelColor,
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('$error',
            style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded,
              color: EnhancedTheme.primaryTeal, size: 18),
          label: Text('Retry',
              style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              EnhancedTheme.infoBlue.withValues(alpha: 0.15),
              EnhancedTheme.infoBlue.withValues(alpha: 0.04),
            ]),
          ),
          child: Icon(Icons.notifications_none_rounded,
              color: EnhancedTheme.infoBlue.withValues(alpha: 0.7), size: 52),
        ),
        const SizedBox(height: 20),
        Text('All Caught Up!',
            style: GoogleFonts.outfit(color: context.labelColor,
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('No notifications right now.\nCheck back later.',
            style: GoogleFonts.inter(color: context.subLabelColor, fontSize: 14),
            textAlign: TextAlign.center),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppShell.roleFallback(ref)),
            ),
            const SizedBox(width: 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notifications',
                  style: GoogleFonts.outfit(color: context.labelColor,
                      fontSize: 20, fontWeight: FontWeight.w700)),
              if (_unreadCount > 0)
                Text('$_unreadCount unread',
                    style: GoogleFonts.inter(color: EnhancedTheme.infoBlue,
                        fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.errorRed,
                    EnhancedTheme.errorRed.withValues(alpha: 0.8),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: EnhancedTheme.errorRed.withValues(alpha: 0.4),
                        blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text('$_unreadCount',
                    style: GoogleFonts.outfit(color: Colors.black,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ).animate().scale(duration: 300.ms),
            const SizedBox(width: 8),
            if (_unreadCount > 0 && _notifications != null)
              GestureDetector(
                onTap: () => _markAllRead(_notifications!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.infoBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: EnhancedTheme.infoBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.done_all_rounded,
                        color: EnhancedTheme.infoBlue, size: 14),
                    const SizedBox(width: 4),
                    Text('Read all',
                        style: GoogleFonts.inter(
                            color: EnhancedTheme.infoBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            const SizedBox(width: 8),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.refresh_rounded, color: context.subLabelColor, size: 18),
                onPressed: _refresh,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> n, int index) {
    final type     = n['type'] as String?;
    final priority = n['priority'] as String?;
    final title    = n['title'] as String? ?? '';
    final message  = n['message'] as String? ?? '';
    final isRead   = n['isRead'] == true;
    final date     = n['createdAt'] as String?;
    final typeCol  = _typeColor(type);
    final prioCol  = _priorityColor(priority);

    return GestureDetector(
      onTap: () => _markRead(n),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isRead
                    ? Colors.white.withValues(alpha: 0.05)
                    : typeCol.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isRead
                      ? Colors.white.withValues(alpha: 0.1)
                      : typeCol.withValues(alpha: 0.3),
                  width: isRead ? 1 : 1.5,
                ),
                boxShadow: isRead
                    ? []
                    : [
                        BoxShadow(
                            color: typeCol.withValues(alpha: 0.08),
                            blurRadius: 12, offset: const Offset(0, 4)),
                      ],
              ),
              child: Stack(children: [
                // Left accent bar
                if (!isRead)
                  Positioned(
                    left: 0, top: 10, bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: typeCol,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(!isRead ? 18 : 14, 14, 14, 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Icon badge
                    Stack(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              typeCol.withValues(alpha: 0.25),
                              typeCol.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: typeCol.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Icon(_typeIcon(type), color: typeCol, size: 22),
                      ),
                      if (!isRead)
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: typeCol,
                              border: Border.all(color: context.scaffoldBg, width: 1.5),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        // Type chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeCol.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_typeLabel(type),
                              style: GoogleFonts.outfit(color: typeCol,
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        if (date != null)
                          Text(_formatDate(date),
                              style: GoogleFonts.inter(color: context.hintColor,
                                  fontSize: 10)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        title.isNotEmpty ? title : _typeLabel(type),
                        style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(message,
                          style: GoogleFonts.inter(
                              color: context.subLabelColor, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (priority != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prioCol.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: prioCol.withValues(alpha: 0.3)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 5, height: 5,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle, color: prioCol),
                              ),
                              Text(
                                priority[0].toUpperCase() + priority.substring(1),
                                style: GoogleFonts.outfit(color: prioCol,
                                    fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ),
                        ]),
                      ],
                    ])),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.04, end: 0);
  }
}
