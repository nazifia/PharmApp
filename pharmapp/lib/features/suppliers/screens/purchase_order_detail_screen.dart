import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/purchase_order.dart';
import '../providers/purchase_order_provider.dart';

class PurchaseOrderDetailScreen extends ConsumerWidget {
  final int orderId;

  const PurchaseOrderDetailScreen({super.key, required this.orderId});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(purchaseOrderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(
          child: orderAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(
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
              ]),
            ),
            data: (order) => _buildContent(context, ref, order),
          ),
        ),
      ]),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, PurchaseOrder order) {
    final color = _statusColor(order.status);
    final icon = _statusIcon(order.status);
    final dateStr = order.createdAt != null
        ? '${order.createdAt!.year}-${order.createdAt!.month.toString().padLeft(2, '0')}-${order.createdAt!.day.toString().padLeft(2, '0')}'
        : '';
    final deliveryStr = order.expectedDelivery != null
        ? '${order.expectedDelivery!.year}-${order.expectedDelivery!.month.toString().padLeft(2, '0')}-${order.expectedDelivery!.day.toString().padLeft(2, '0')}'
        : '';
    final canSubmit = order.status == 'draft';
    final canReceive =
        order.status == 'submitted' || order.status == 'partial';

    return Column(children: [
      ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04)),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: context.labelColor),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/dashboard/purchase-orders'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('PO #${order.id}',
                      style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  Text(order.supplierName,
                      style: GoogleFonts.inter(
                          color: context.subLabelColor, fontSize: 11)),
                ]),
              ),
              _statusChip(order.status, color),
            ]),
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
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
                        border: Border.all(
                            color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      _infoRow(context, 'Supplier', order.supplierName),
                      if (dateStr.isNotEmpty)
                        _infoRow(context, 'Created', dateStr),
                      if (deliveryStr.isNotEmpty)
                        _infoRow(context, 'Expected', deliveryStr),
                      _infoRow(context, 'Items',
                          '${order.items.length}'),
                      _infoRow(context, 'Total',
                          '₦${order.total.toStringAsFixed(2)}'),
                    ])),
                  ]),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Icon(Icons.notes_rounded,
                          color: context.hintColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(order.notes!,
                            style: GoogleFonts.inter(
                                color: context.subLabelColor,
                                fontSize: 13)),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Items (${order.items.length})',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...order.items.asMap().entries.map(
                  (e) => _itemTile(context, e.value, e.key),
                ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                      EnhancedTheme.accentCyan.withValues(alpha: 0.06),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Row(children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: EnhancedTheme.primaryTeal, size: 18),
                      const SizedBox(width: 8),
                      Text('Total Cost',
                          style: GoogleFonts.outfit(
                              color: context.labelColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]),
                    Text('₦${order.total.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                            color: EnhancedTheme.primaryTeal,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (canSubmit)
              _actionButton(
                context,
                ref,
                label: 'Submit Order',
                icon: Icons.send_rounded,
                color: EnhancedTheme.infoBlue,
                onTap: () => _submitOrder(context, ref, order.id!),
              ),
            if (canReceive)
              _actionButton(
                context,
                ref,
                label: 'Receive Stock',
                icon: Icons.move_to_inbox_rounded,
                color: EnhancedTheme.successGreen,
                onTap: () => context.push(
                    '/dashboard/purchase-orders/${order.id}/receive'),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Text('$label: ',
            style: GoogleFonts.inter(
                color: context.hintColor,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  color: context.labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _itemTile(BuildContext context, PurchaseOrderItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: GoogleFonts.outfit(
                          color: EnhancedTheme.primaryTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(item.itemName,
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Wrap(spacing: 6, children: [
                  _chip(context, 'Qty',
                      '${item.quantityOrdered}',
                      EnhancedTheme.accentCyan),
                  _chip(context, 'Received',
                      '${item.quantityReceived}',
                      EnhancedTheme.successGreen),
                  _chip(context, 'Unit Cost',
                      '₦${item.unitCost.toStringAsFixed(2)}',
                      EnhancedTheme.warningAmber),
                ]),
              ])),
              Text(
                  '₦${(item.unitCost * item.quantityOrdered).toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Text(label,
            style: GoogleFonts.inter(
                color: color.withValues(alpha: 0.7), fontSize: 9)),
        Text(value,
            style: GoogleFonts.outfit(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _statusChip(String status, Color color) {
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _actionButton(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder(
      BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(purchaseOrderListProvider.notifier).submitOrder(id);
      ref.invalidate(purchaseOrderDetailProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor:
              EnhancedTheme.infoBlue.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: const Row(children: [
            Icon(Icons.send_rounded, color: Colors.black, size: 20),
            SizedBox(width: 10),
            Expanded(
                child: Text('Order submitted',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor:
              EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Failed: $e',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }
}
