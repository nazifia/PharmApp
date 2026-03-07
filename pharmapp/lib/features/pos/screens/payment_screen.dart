import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/sale.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_api_provider.dart';

enum _PayMethod { cash, card, wallet, split }

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _PayMethod _method     = _PayMethod.cash;
  bool       _processing = false;

  double get _subtotal {
    final cart = ref.read(cartProvider);
    return cart.fold(0.0, (s, c) => s + c.subtotal);
  }

  double get _tax   => _subtotal * 0.05;
  double get _total => _subtotal + _tax;

  Future<void> _confirm() async {
    setState(() => _processing = true);

    final cart = ref.read(cartProvider);

    // Build checkout payload
    final payload = CheckoutPayload(
      items: cart.map((c) => SaleItemPayload(
        barcode:   c.item.barcode,
        quantity:  c.quantity,
        unitPrice: c.item.price,
      )).toList(),
      payments: PaymentPayload(
        cash:         _method == _PayMethod.cash   ? _total : 0,
        bankTransfer: _method == _PayMethod.card   ? _total : 0,
        wallet:       _method == _PayMethod.wallet ? _total : 0,
      ),
      totalAmount: _total,
    );

    final success = await ref.read(checkoutProvider.notifier).processCheckout(payload);

    if (!mounted) return;
    setState(() => _processing = false);

    if (success) {
      ref.read(cartProvider.notifier).clearCart();
      _showSuccessSheet();
    } else {
      final err = ref.read(checkoutProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Checkout failed: $err'),
        backgroundColor: EnhancedTheme.errorRed,
      ));
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        total: _total,
        method: _method,
        onDone: () {
          Navigator.pop(context);
          context.go('/dashboard/pos');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Complete the transaction', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Cart items
              Text('Order Summary', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: context.cardColor, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor)),
                    child: Column(children: [
                      if (cart.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('Cart is empty', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                        )
                      else
                        ...cart.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(child: Text(c.item.name, style: TextStyle(color: context.labelColor, fontSize: 13))),
                            Text('×${c.quantity}', style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                            const SizedBox(width: 12),
                            Text('₹${c.subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                        )),
                      Divider(color: context.dividerColor, height: 20),
                      _totalsRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      _totalsRow('Tax (5%)', '₹${_tax.toStringAsFixed(2)}', dimmed: true),
                      const SizedBox(height: 10),
                      _totalsRow('Total', '₹${_total.toStringAsFixed(2)}', large: true),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payment method
              Text('Payment Method', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _methodChip(_PayMethod.cash,   Icons.payments_rounded,    'Cash'),
                _methodChip(_PayMethod.card,   Icons.credit_card_rounded, 'Card'),
                _methodChip(_PayMethod.wallet, Icons.account_balance_wallet_rounded, 'Wallet'),
                _methodChip(_PayMethod.split,  Icons.call_split_rounded,  'Split'),
              ]),
              const SizedBox(height: 32),

              // Confirm button
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: cart.isEmpty || _processing ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _processing
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm Payment  ₹${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _totalsRow(String label, String value, {bool dimmed = false, bool large = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(
          color: dimmed ? context.hintColor : context.subLabelColor,
          fontSize: large ? 16 : 13, fontWeight: large ? FontWeight.w700 : FontWeight.normal)),
      Text(value, style: TextStyle(
          color: large ? EnhancedTheme.primaryTeal : context.labelColor,
          fontSize: large ? 18 : 13, fontWeight: FontWeight.w700)),
    ]);

  Widget _methodChip(_PayMethod m, IconData icon, String label) {
    final active = _method == m;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? EnhancedTheme.primaryTeal.withValues(alpha: 0.2) : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? EnhancedTheme.primaryTeal : context.borderColor, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? EnhancedTheme.primaryTeal : context.subLabelColor, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
              color: active ? EnhancedTheme.primaryTeal : context.subLabelColor,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  final double total;
  final _PayMethod method;
  final VoidCallback onDone;
  const _SuccessSheet({required this.total, required this.method, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 20),
        const Text('Payment Successful!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('₹${total.toStringAsFixed(2)} received via ${method.name.toUpperCase()}',
            style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        )),
      ]),
    );
  }
}
