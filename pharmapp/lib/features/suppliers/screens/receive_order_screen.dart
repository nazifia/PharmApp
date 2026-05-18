import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/inventory/providers/inventory_provider.dart';
import 'package:pharmapp/shared/models/purchase_order.dart';
import '../providers/purchase_order_provider.dart';

class ReceiveOrderScreen extends ConsumerStatefulWidget {
  final int orderId;

  const ReceiveOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<ReceiveOrderScreen> createState() =>
      _ReceiveOrderScreenState();
}

class _ReceiveOrderScreenState extends ConsumerState<ReceiveOrderScreen> {
  final Map<int, TextEditingController> _qtyControllers = {};
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<PurchaseOrderItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (!_qtyControllers.containsKey(i)) {
        _qtyControllers[i] = TextEditingController(
            text: '${items[i].quantityOrdered}');
      }
    }
  }

  Future<void> _markReceived(
      BuildContext context, List<PurchaseOrderItem> items) async {
    final receivedItems = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final qty = int.tryParse(_qtyControllers[i]?.text ?? '') ?? 0;
      receivedItems.add({
        if (items[i].id != null) 'id': items[i].id,
        'item_id': items[i].itemId,
        'item_name': items[i].itemName,
        'quantity_received': qty,
        'unit_cost': items[i].unitCost,
      });
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(purchaseOrderListProvider.notifier)
          .receiveOrder(widget.orderId, receivedItems);

      ref.invalidate(inventoryListProvider);
      ref.invalidate(retailInventoryProvider);
      ref.invalidate(wholesaleInventoryProvider);
      ref.invalidate(purchaseOrderDetailProvider(widget.orderId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor:
              EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: const Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.black, size: 20),
            SizedBox(width: 10),
            Expanded(
                child: Text('Stock updated',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600))),
          ]),
        ));
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(purchaseOrderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(
          child: Column(children: [
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
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(
                              '/dashboard/purchase-orders/${widget.orderId}'),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Receive Stock',
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text('Enter quantities received',
                            style: GoogleFonts.inter(
                                color: context.subLabelColor,
                                fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: orderAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: EnhancedTheme.primaryTeal)),
                error: (e, _) => Center(
                  child: Text('$e',
                      style: GoogleFonts.inter(
                          color: context.subLabelColor,
                          fontSize: 13)),
                ),
                data: (order) {
                  _initControllers(order.items);
                  return _buildBody(context, order);
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, PurchaseOrder order) {
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.infoBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: EnhancedTheme.infoBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: EnhancedTheme.infoBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Receiving from: ${order.supplierName} · PO #${order.id}',
                        style: GoogleFonts.inter(
                            color: EnhancedTheme.infoBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Items to Receive',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...order.items.asMap().entries.map(
                  (e) => _itemReceiveCard(context, e.value, e.key),
                ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitting
                ? null
                : () => _markReceived(context, order.items),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.move_to_inbox_rounded, size: 20),
            label: Text(
                _submitting ? 'Updating…' : 'Mark as Received',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.successGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _itemReceiveCard(
      BuildContext context, PurchaseOrderItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
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
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(item.itemName,
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.accentCyan
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: EnhancedTheme.accentCyan
                              .withValues(alpha: 0.25)),
                    ),
                    child: Text('Ordered: ${item.quantityOrdered}',
                        style: GoogleFonts.inter(
                            color: EnhancedTheme.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: EnhancedTheme.warningAmber
                              .withValues(alpha: 0.25)),
                    ),
                    child: Text(
                        '₦${item.unitCost.toStringAsFixed(2)}/unit',
                        style: GoogleFonts.inter(
                            color: EnhancedTheme.warningAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ])),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _qtyControllers[index],
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                    filled: true,
                    fillColor:
                        EnhancedTheme.successGreen.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: EnhancedTheme.successGreen
                                .withValues(alpha: 0.25))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: EnhancedTheme.successGreen
                                .withValues(alpha: 0.25))),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(
                            color: EnhancedTheme.successGreen,
                            width: 1.5)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.03, end: 0);
  }
}
