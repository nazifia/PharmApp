import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/purchase_order.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/purchase_order_provider.dart';

class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState
    extends ConsumerState<PurchaseOrderListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;


  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'submitted':
        return EnhancedTheme.infoBlue;
      case 'partial':
        return EnhancedTheme.warningAmber;
      case 'received':
        return EnhancedTheme.successGreen;
      case 'cancelled':
        return EnhancedTheme.errorRed;
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'submitted':
        return Icons.send_rounded;
      case 'partial':
        return Icons.incomplete_circle_rounded;
      case 'received':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(purchaseOrderListProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/purchase-orders/new'),
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text('New PO',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  decoration:
                      BoxDecoration(color: Colors.white.withValues(alpha: 0.04)),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: context.labelColor),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AppShell.roleFallback(ref)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Purchase Orders',
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text('Create and manage supplier POs',
                            style: GoogleFonts.inter(
                                color: context.subLabelColor, fontSize: 11)),
                      ]),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          color: context.subLabelColor),
                      onPressed: () =>
                          ref.read(purchaseOrderListProvider.notifier).fetch(),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          EnhancedTheme.primaryTeal,
                          EnhancedTheme.accentCyan,
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: EnhancedTheme.primaryTeal
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.black,
                      unselectedLabelColor: context.subLabelColor,
                      labelStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 12),
                      unselectedLabelStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w500, fontSize: 12),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Active'),
                        Tab(text: 'Received'),
                        Tab(text: 'Cancelled'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ordersAsync.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: List.generate(
                      4,
                      (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: EnhancedTheme.loadingShimmer(
                                height: 96, radius: 16),
                          )),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.error_outline_rounded,
                          color: EnhancedTheme.errorRed.withValues(alpha: 0.7),
                          size: 48),
                      const SizedBox(height: 12),
                      Text('$e',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: context.subLabelColor, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(purchaseOrderListProvider.notifier)
                            .fetch(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: EnhancedTheme.primaryTeal,
                            foregroundColor: Colors.black),
                        child: const Text('Retry'),
                      ),
                    ]),
                  ),
                ),
                data: (orders) {
                  final active = orders
                      .where((o) =>
                          o.status == 'draft' ||
                          o.status == 'submitted' ||
                          o.status == 'partial')
                      .toList();
                  final received =
                      orders.where((o) => o.status == 'received').toList();
                  final cancelled =
                      orders.where((o) => o.status == 'cancelled').toList();

                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _buildList(active),
                      _buildList(received),
                      _buildList(cancelled),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildList(List<PurchaseOrder> orders) {
    if (orders.isEmpty) {
      return _emptyState();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(purchaseOrderListProvider.notifier).fetch(),
      color: EnhancedTheme.primaryTeal,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: orders.length,
        itemBuilder: (_, i) => _orderTile(orders[i], i),
      ),
    );
  }

  Widget _orderTile(PurchaseOrder order, int index) {
    final color = _statusColor(order.status);
    final icon = _statusIcon(order.status);
    final dateStr = order.createdAt != null
        ? '${order.createdAt!.year}-${order.createdAt!.month.toString().padLeft(2, '0')}-${order.createdAt!.day.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () =>
            context.push('/dashboard/purchase-orders/${order.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.3)]),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.25),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(order.supplierName,
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.inventory_2_outlined,
                              color: context.hintColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                              '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                  color: context.subLabelColor, fontSize: 11)),
                          if (dateStr.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today_rounded,
                                color: context.hintColor, size: 12),
                            const SizedBox(width: 4),
                            Text(dateStr,
                                style: GoogleFonts.inter(
                                    color: context.subLabelColor,
                                    fontSize: 11)),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Text('₦${order.total.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      _statusChip(order.status),
                      const SizedBox(height: 8),
                      Icon(Icons.chevron_right_rounded,
                          color: context.hintColor, size: 18),
                    ]),
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
        .slideY(begin: 0.04, end: 0);
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
            ),
            child: Icon(Icons.receipt_long_outlined,
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.7),
                size: 40),
          ),
          const SizedBox(height: 14),
          Text('No purchase orders',
              style: GoogleFonts.outfit(
                  color: context.subLabelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap + to create a new PO',
              style: GoogleFonts.inter(
                  color: context.hintColor, fontSize: 12)),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
        begin: const Offset(0.95, 0.95));
  }
}
