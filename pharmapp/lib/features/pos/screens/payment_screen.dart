import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/sale.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_api_provider.dart';
import 'receipt_screen.dart';

enum _PayMethod { cash, card, bankTransfer, wallet, split }

extension _PayMethodLabel on _PayMethod {
  String get label {
    switch (this) {
      case _PayMethod.cash:         return 'Cash';
      case _PayMethod.card:         return 'Card / POS';
      case _PayMethod.bankTransfer: return 'Bank Transfer';
      case _PayMethod.wallet:       return 'Wallet';
      case _PayMethod.split:        return 'Split';
    }
  }

  IconData get icon {
    switch (this) {
      case _PayMethod.cash:         return Icons.payments_rounded;
      case _PayMethod.card:         return Icons.credit_card_rounded;
      case _PayMethod.bankTransfer: return Icons.account_balance_rounded;
      case _PayMethod.wallet:       return Icons.account_balance_wallet_rounded;
      case _PayMethod.split:        return Icons.call_split_rounded;
    }
  }

  String get apiKey {
    switch (this) {
      case _PayMethod.cash:         return 'cash';
      case _PayMethod.card:         return 'card';
      case _PayMethod.bankTransfer: return 'bank_transfer';
      case _PayMethod.wallet:       return 'wallet';
      case _PayMethod.split:        return 'split';
    }
  }
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _PayMethod _method     = _PayMethod.cash;
  bool       _processing = false;

  // Split payment controllers
  final _cashCtrl     = TextEditingController();
  final _cardCtrl     = TextEditingController();
  final _bankCtrl     = TextEditingController();
  final _walletCtrl   = TextEditingController();

  @override
  void dispose() {
    _cashCtrl.dispose();
    _cardCtrl.dispose();
    _bankCtrl.dispose();
    _walletCtrl.dispose();
    super.dispose();
  }

  double get _subtotal {
    final cart = ref.read(cartProvider);
    return cart.fold(0.0, (s, c) => s + c.total);
  }

  double get _total => _subtotal;

  // Split amounts from controllers
  double get _splitCash   => double.tryParse(_cashCtrl.text)   ?? 0;
  double get _splitCard   => double.tryParse(_cardCtrl.text)   ?? 0;
  double get _splitBank   => double.tryParse(_bankCtrl.text)   ?? 0;
  double get _splitWallet => double.tryParse(_walletCtrl.text) ?? 0;
  double get _splitSum    => _splitCash + _splitCard + _splitBank + _splitWallet;

  bool get _splitValid => _method != _PayMethod.split || (_splitSum - _total).abs() < 0.01;

  PaymentPayload get _buildPayment {
    switch (_method) {
      case _PayMethod.cash:
        return PaymentPayload(cash: _total, pos: 0, bankTransfer: 0, wallet: 0);
      case _PayMethod.card:
        return PaymentPayload(cash: 0, pos: _total, bankTransfer: 0, wallet: 0);
      case _PayMethod.bankTransfer:
        return PaymentPayload(cash: 0, pos: 0, bankTransfer: _total, wallet: 0);
      case _PayMethod.wallet:
        return PaymentPayload(cash: 0, pos: 0, bankTransfer: 0, wallet: _total);
      case _PayMethod.split:
        return PaymentPayload(
          cash: _splitCash, pos: _splitCard, bankTransfer: _splitBank, wallet: _splitWallet);
    }
  }

  Future<void> _confirm() async {
    if (!_splitValid) return;

    if (_method == _PayMethod.wallet) {
      final selected = ref.read(selectedCustomerProvider);
      if (selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Wallet payment requires a linked customer.'),
          backgroundColor: EnhancedTheme.warningAmber));
        return;
      }
      if (selected.walletBalance < _total) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Insufficient wallet balance: ₦${selected.walletBalance.toStringAsFixed(0)} available'),
          backgroundColor: EnhancedTheme.errorRed));
        return;
      }
    }

    if (_method == _PayMethod.split && _splitWallet > 0) {
      final selected = ref.read(selectedCustomerProvider);
      if (selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Wallet split requires a linked customer.'),
          backgroundColor: EnhancedTheme.warningAmber));
        return;
      }
      if (selected.walletBalance < _splitWallet) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Insufficient wallet balance for split: ₦${selected.walletBalance.toStringAsFixed(0)} available'),
          backgroundColor: EnhancedTheme.errorRed));
        return;
      }
    }

    setState(() => _processing = true);

    final cart     = ref.read(cartProvider);
    final selected = ref.read(selectedCustomerProvider);

    final payload = CheckoutPayload(
      items: cart.map((c) => SaleItemPayload(
        barcode:  c.item.barcode,
        itemId:   c.item.id,
        quantity: c.quantity,
        price:    c.item.price,
        discount: c.discount,
      )).toList(),
      payment:       _buildPayment,
      totalAmount:   _total,
      customerId:    selected?.id,
      isWholesale:   false,
      paymentMethod: _method.apiKey,
    );

    final result = await ref.read(checkoutProvider.notifier).processCheckout(payload);

    if (!mounted) return;
    setState(() => _processing = false);

    if (result != null) {
      ref.read(cartProvider.notifier).clearCart();
      ref.read(selectedCustomerProvider.notifier).state = null;
      _showSuccessSheet(result);
    } else {
      final err = ref.read(checkoutProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Checkout failed: $err'),
        backgroundColor: EnhancedTheme.errorRed,
      ));
    }
  }

  void _showSuccessSheet(Map<String, dynamic> saleData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        total:    _total,
        method:   _method,
        saleData: saleData,
        onDone: () {
          Navigator.pop(context);
          context.go('/dashboard/pos');
        },
        onViewReceipt: () {
          Navigator.pop(context);
          showReceiptSheet(context, saleData);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart     = ref.watch(cartProvider);
    final selected = ref.watch(selectedCustomerProvider);
    final total = cart.fold(0.0, (s, c) => s + c.total);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/pos')),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment',
                    style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Complete the transaction',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Order Summary ───────────────────────────────────────────────
              Text('Order Summary',
                  style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _glassCard(child: Column(children: [
                if (cart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Cart is empty', style: TextStyle(color: context.hintColor)),
                  )
                else
                  ...cart.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.item.name,
                            style: TextStyle(color: context.labelColor, fontSize: 13)),
                        if (c.discount > 0)
                          Text('-₦${c.discount.toStringAsFixed(0)} disc',
                              style: TextStyle(color: EnhancedTheme.warningAmber, fontSize: 11)),
                      ])),
                      Text('×${c.quantity}',
                          style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                      const SizedBox(width: 12),
                      Text('₦${c.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                Divider(color: context.dividerColor, height: 20),
                _totalsRow('Total', '₦${total.toStringAsFixed(2)}', large: true),
              ])),
              const SizedBox(height: 20),

              // ── Linked Customer ─────────────────────────────────────────────
              if (selected != null) ...[
                Text('Customer',
                    style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.25))),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                          child: Text(selected.name.isNotEmpty ? selected.name[0] : '?',
                              style: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(selected.name,
                              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Wallet: ₦${selected.walletBalance.toStringAsFixed(0)}',
                              style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                        ])),
                        GestureDetector(
                          onTap: () => ref.read(selectedCustomerProvider.notifier).state = null,
                          child: Icon(Icons.close_rounded, color: context.hintColor, size: 18)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Payment Method ───────────────────────────────────────────────
              Text('Payment Method',
                  style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final m in _PayMethod.values)
                  if (m != _PayMethod.wallet || selected != null)
                    _methodChip(m),
              ]),

              // ── Split Payment Fields ─────────────────────────────────────────
              if (_method == _PayMethod.split) ...[
                const SizedBox(height: 20),
                Text('Split Amounts',
                    style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Enter the amount for each payment channel. Total must equal ₦${total.toStringAsFixed(2)}.',
                    style: TextStyle(color: context.hintColor, fontSize: 12)),
                const SizedBox(height: 12),
                _splitField(_cashCtrl,  'Cash',          Icons.payments_rounded,              EnhancedTheme.successGreen),
                const SizedBox(height: 10),
                _splitField(_cardCtrl,  'Card / POS',    Icons.credit_card_rounded,           EnhancedTheme.accentPurple),
                const SizedBox(height: 10),
                _splitField(_bankCtrl,  'Bank Transfer', Icons.account_balance_rounded,        EnhancedTheme.infoBlue),
                const SizedBox(height: 10),
                if (selected != null)
                  _splitField(_walletCtrl, 'Wallet',  Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
                if (selected != null) const SizedBox(height: 10),
                // Balance indicator
                Builder(builder: (_) {
                  final diff  = _splitSum - total;
                  final ok    = diff.abs() < 0.01;
                  final label = ok
                      ? 'Balanced ✓'
                      : diff > 0
                          ? 'Over by ₦${diff.toStringAsFixed(2)}'
                          : 'Remaining: ₦${(-diff).toStringAsFixed(2)}';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                            .withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(label,
                          style: TextStyle(
                            color: ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Sum: ₦${_splitSum.toStringAsFixed(2)}',
                          style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                    ]),
                  );
                }),
              ],

              const SizedBox(height: 28),

              // ── Confirm Button ───────────────────────────────────────────────
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: (cart.isEmpty || _processing || !_splitValid) ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _processing
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm Payment  ₦${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )),
            ]),
          )),
        ])),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor)),
        child: child,
      ),
    ),
  );

  Widget _totalsRow(String label, String value, {bool dimmed = false, bool large = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
            color: dimmed ? context.hintColor : context.subLabelColor,
            fontSize: large ? 16 : 13,
            fontWeight: large ? FontWeight.w700 : FontWeight.normal)),
        Text(value, style: TextStyle(
            color: large ? EnhancedTheme.primaryTeal : context.labelColor,
            fontSize: large ? 18 : 13, fontWeight: FontWeight.w700)),
      ]);

  Widget _methodChip(_PayMethod m) {
    final active = _method == m;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? EnhancedTheme.primaryTeal.withValues(alpha: 0.2) : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? EnhancedTheme.primaryTeal : context.borderColor,
            width: active ? 1.5 : 1.0),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(m.icon,
              color: active ? EnhancedTheme.primaryTeal : context.subLabelColor, size: 16),
          const SizedBox(width: 8),
          Text(m.label, style: TextStyle(
              color: active ? EnhancedTheme.primaryTeal : context.subLabelColor,
              fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _splitField(TextEditingController ctrl, String label, IconData icon, Color color) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: context.labelColor, fontSize: 14),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.hintColor, fontSize: 13),
          prefixIcon: Icon(icon, color: color, size: 18),
          prefixText: '₦',
          prefixStyle: TextStyle(color: context.hintColor),
          filled: true, fillColor: context.cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SUCCESS SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _SuccessSheet extends StatelessWidget {
  final double total;
  final _PayMethod method;
  final Map<String, dynamic> saleData;
  final VoidCallback onDone;
  final VoidCallback onViewReceipt;

  const _SuccessSheet({
    required this.total,
    required this.method,
    required this.saleData,
    required this.onDone,
    required this.onViewReceipt,
  });

  Color get _color {
    switch (method) {
      case _PayMethod.cash:         return EnhancedTheme.successGreen;
      case _PayMethod.card:         return EnhancedTheme.accentPurple;
      case _PayMethod.bankTransfer: return EnhancedTheme.infoBlue;
      case _PayMethod.wallet:       return EnhancedTheme.warningAmber;
      case _PayMethod.split:        return EnhancedTheme.primaryTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receiptId = saleData['receiptId'] as String? ?? '';
    return Container(
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // success circle
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(color: EnhancedTheme.successGreen, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 16),
        Text('Payment Successful!',
            style: TextStyle(color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('₦${total.toStringAsFixed(2)} via',
            style: TextStyle(color: context.subLabelColor, fontSize: 14)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _color.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(method.icon, color: _color, size: 14),
            const SizedBox(width: 8),
            Text(method.label,
                style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (receiptId.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(receiptId,
              style: TextStyle(color: context.hintColor, fontSize: 11,
                  fontFamily: 'monospace')),
        ],
        const SizedBox(height: 24),
        // ── Buttons
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onViewReceipt,
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('View & Print Receipt',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: onDone,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.labelColor,
            side: BorderSide(color: context.borderColor),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('New Sale',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        )),
      ]),
    );
  }
}
