import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      case 'low_stock':      return Icons.warning_amber_rounded;
      case 'out_of_stock':   return Icons.error_outline_rounded;
      case 'expiry_alert':   return Icons.timer_outlined;
      case 'payment_request': return Icons.payment_rounded;
      default:               return Icons.info_outline_rounded;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'low_stock':      return EnhancedTheme.warningAmber;
      case 'out_of_stock':   return EnhancedTheme.errorRed;
      case 'expiry_alert':   return EnhancedTheme.accentOrange;
      case 'payment_request': return EnhancedTheme.successGreen;
      default:               return EnhancedTheme.infoBlue;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _buildHeader(context),
          Expanded(child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: EnhancedTheme.primaryTeal,
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal));
                }
                if (snap.hasError) {
                  return ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(child: Column(children: [
                      Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
                      const SizedBox(height: 12),
                      Text('${snap.error}', style: TextStyle(color: context.subLabelColor), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _refresh,
                          child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
                    ])),
                  ]);
                }
                final notifications = snap.data ?? [];
                if (notifications.isEmpty) {
                  return ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(child: Column(children: [
                      Icon(Icons.notifications_none_rounded, color: context.hintColor, size: 72),
                      const SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: context.subLabelColor, fontSize: 16, fontWeight: FontWeight.w500)),
                    ])),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: notifications.length,
                  itemBuilder: (_, i) => _notificationCard(notifications[i] as Map<String, dynamic>),
                );
              },
            ),
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
      const SizedBox(width: 4),
      Text('Notifications',
          style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      if (_unreadCount > 0) Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      const Spacer(),
      IconButton(icon: Icon(Icons.refresh_rounded, color: context.subLabelColor), onPressed: _refresh),
    ]),
  );

  Widget _notificationCard(Map<String, dynamic> n) {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isRead ? context.cardColor : typeCol.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isRead ? context.borderColor : typeCol.withValues(alpha: 0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeCol.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(type), color: typeCol, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title.isNotEmpty ? title : _typeLabel(type),
                      style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600))),
                  if (!isRead) Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: typeCol),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: context.subLabelColor, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  if (priority != null) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: prioCol.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: prioCol.withValues(alpha: 0.3)),
                    ),
                    child: Text(priority[0].toUpperCase() + priority.substring(1),
                        style: TextStyle(color: prioCol, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  if (date != null) Text(_formatDate(date),
                      style: TextStyle(color: context.hintColor, fontSize: 11)),
                ]),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}
