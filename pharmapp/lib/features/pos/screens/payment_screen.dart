import 'dart:convert';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/sale.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/offline/offline_queue.dart';
import '../../../shared/models/cart_item.dart';
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

  Color get accentColor {
    switch (this) {
      case _PayMethod.cash:         return EnhancedTheme.successGreen;
      case _PayMethod.card:         return EnhancedTheme.accentPurple;
      case _PayMethod.bankTransfer: return EnhancedTheme.infoBlue;
      case _PayMethod.wallet:       return EnhancedTheme.warningAmber;
      case _PayMethod.split:        return EnhancedTheme.primaryTeal;
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
  final _cashCtrl      = TextEditingController();
  final _cardCtrl      = TextEditingController();
  final _bankCtrl      = TextEditingController();
  final _walletCtrl    = TextEditingController();
  final _buyerNameCtrl = TextEditingController();

  @override
  void dispose() {
    _cashCtrl.dispose();
    _cardCtrl.dispose();
    _bankCtrl.dispose();
    _walletCtrl.dispose();
    _buyerNameCtrl.dispose();
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
        _showSnackBar('Wallet payment requires a linked customer.', type: _SnackType.warning);
        return;
      }
    }

    if (_method == _PayMethod.split && _splitWallet > 0) {
      final selected = ref.read(selectedCustomerProvider);
      if (selected == null) {
        _showSnackBar('Wallet split requires a linked customer.', type: _SnackType.warning);
        return;
      }
    }

    setState(() => _processing = true);

    final cart     = ref.read(cartProvider);
    final selected = ref.read(selectedCustomerProvider);

    final buyerName = _buyerNameCtrl.text.trim();
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
      patientName:   buyerName.isEmpty ? null : buyerName,
    );

    final result = await ref.read(checkoutProvider.notifier).processCheckout(payload);

    if (!mounted) return;
    setState(() => _processing = false);

    if (result != null && result['offline'] == true) {
      // No connection — sale queued for sync.
      // Capture the queue ID of the just-enqueued sale and build a local receipt
      // so the sale is visible in history immediately (before sync).
      final queue   = ref.read(offlineQueueProvider);
      final queueId = queue.isNotEmpty ? queue.last.id : DateTime.now().microsecondsSinceEpoch.toString();
      // Pass buyerName explicitly — it was captured before the async gap above
      // so it is guaranteed to be the value the user typed, regardless of
      // any subsequent widget rebuilds or controller state changes.
      final receiptData = _buildOfflineReceipt(cart, selected, queueId, buyerName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_receipt_$queueId', jsonEncode(receiptData));

      ref.read(cartProvider.notifier).clearCart();
      ref.read(selectedCustomerProvider.notifier).state = null;
      _buyerNameCtrl.clear();
      _showOfflineQueuedSheet(receiptData);
    } else if (result != null) {
      // Merge the manually-typed buyer name into the backend response so the
      // receipt shows the correct customer name. The backend may return the
      // sale without echoing back the patientName field.
      final enrichedResult = Map<String, dynamic>.from(result);
      if (buyerName.isNotEmpty) {
        enrichedResult['customerName'] = buyerName;
      } else if (selected != null &&
          enrichedResult['customerName'] == null &&
          enrichedResult['customer_name'] == null &&
          enrichedResult['patientName'] == null &&
          enrichedResult['patient_name'] == null) {
        enrichedResult['customerName'] = selected.name;
      }
      ref.read(cartProvider.notifier).clearCart();
      ref.read(selectedCustomerProvider.notifier).state = null;
      _buyerNameCtrl.clear();
      _showSuccessSheet(enrichedResult);
    } else {
      final err = ref.read(checkoutProvider).error;
      String errMsg = 'Checkout failed';
      if (err is DioException) {
        final data = err.response?.data;
        if (data is Map && data['detail'] != null) {
          errMsg = data['detail'].toString();
        } else {
          errMsg = 'Checkout failed: ${err.response?.statusCode ?? err.message}';
        }
      } else if (err != null) {
        errMsg = 'Checkout failed: $err';
      }
      _showSnackBar(errMsg, type: _SnackType.error);
    }
  }

  Map<String, dynamic> _buildOfflineReceipt(
    List<CartItem> cart,
    SelectedCustomer? customer,
    String queueId,
    String buyerName,
  ) {
    final now     = DateTime.now().toIso8601String();
    final payment = _buildPayment;
    final suffix  = queueId.length > 6 ? queueId.substring(queueId.length - 6) : queueId;
    return {
      'id':              'offline_$queueId',
      'receiptId':       'OFFLINE-$suffix',
      'status':          'pending_sync',
      '_offlineQueueId': queueId,
      'totalAmount':     _total,
      'paymentMethod':   _method.apiKey,
      'paymentCash':     payment.cash,
      'paymentPos':      payment.pos,
      'paymentTransfer': payment.bankTransfer,
      'paymentWallet':   payment.wallet,
      'customerName':    buyerName.isNotEmpty
                             ? buyerName
                             : (customer?.name ?? 'Walk-in'),
      'isWholesale':     false,
      'createdAt':       now,
      'items': cart.map((c) => {
        'name':        c.item.name,
        'brand':       c.item.brand,
        'dosageForm':  c.item.dosageForm,
        'quantity':    c.quantity,
        'price':       c.item.price.toDouble(),
        'discount':    c.discount,
        'subtotal':    c.total,
      }).toList(),
    };
  }

  void _showSnackBar(String msg, {required _SnackType type}) {
    final color = type == _SnackType.success
        ? EnhancedTheme.successGreen
        : type == _SnackType.error
            ? EnhancedTheme.errorRed
            : EnhancedTheme.warningAmber;
    final icon = type == _SnackType.success
        ? Icons.check_circle_rounded
        : type == _SnackType.error
            ? Icons.error_rounded
            : Icons.warning_amber_rounded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 5),
      content: Row(children: [
        Icon(icon, color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  void _showSuccessSheet(Map<String, dynamic> saleData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        total:    _total,
        method:   _method,
        saleData: saleData,
        onDone: () {
          Navigator.pop(context);             // dismiss success sheet
          if (context.canPop()) {
            context.pop();                    // return to wherever POS was pushed from
          } else {
            context.go('/dashboard/pos');     // fallback: direct entry to POS
          }
        },
        onViewReceipt: () {
          Navigator.pop(context);
          showReceiptSheet(context, saleData);
        },
      ),
    );
  }

  void _showOfflineQueuedSheet(Map<String, dynamic> receiptData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.97) : Colors.white.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: context.borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.warningAmber.withValues(alpha: 0.2),
                    EnhancedTheme.warningAmber.withValues(alpha: 0.08),
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.warningAmber, size: 38),
              ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 20),
              Text('Sale Saved Offline',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 21, fontWeight: FontWeight.w800))
                  .animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'No internet connection. This sale has been saved and will sync automatically when back online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.subLabelColor, fontSize: 13, height: 1.5),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 20),
              // Receipt ID chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_rounded, color: EnhancedTheme.warningAmber, size: 14),
                  const SizedBox(width: 6),
                  Text(receiptData['receiptId'] as String? ?? 'OFFLINE',
                      style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 24),
              // View Receipt button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showReceiptSheet(context, receiptData);
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('View Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EnhancedTheme.primaryTeal,
                  side: const BorderSide(color: EnhancedTheme.primaryTeal),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15, end: 0),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [EnhancedTheme.warningAmber, Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: EnhancedTheme.warningAmber.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/dashboard/pos');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('OK, Got It', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                )),
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
            ]),
          ),
        ),
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
          // ── Gradient Header ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                  EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/dashboard/pos'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment',
                    style: GoogleFonts.outfit(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Complete the transaction',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
              ]),
            ]),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Large Amount Display (calculator style) ─────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                          EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
                    ),
                    child: Column(children: [
                      Text('Total Amount',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('₦',
                            style: GoogleFonts.outfit(color: EnhancedTheme.accentCyan, fontSize: 24, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text(total.toStringAsFixed(2),
                            style: GoogleFonts.outfit(
                                color: Colors.black, fontSize: 42, fontWeight: FontWeight.w800,
                                letterSpacing: -1.5)),
                      ]),
                      const SizedBox(height: 10),
                      // Order summary mini rows
                      if (cart.isNotEmpty)
                        ...cart.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(child: Text(c.item.name,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                                overflow: TextOverflow.ellipsis)),
                            if (c.discount > 0)
                              Text('-₦${c.discount.toStringAsFixed(0)}  ',
                                  style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 11)),
                            Text('×${c.quantity}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                            const SizedBox(width: 12),
                            Text('₦${c.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: EnhancedTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        )),
                    ]),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 50.ms),

              const SizedBox(height: 20),

              // ── Linked Customer ─────────────────────────────────────────────
              if (selected != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                          EnhancedTheme.accentPurple.withValues(alpha: 0.06),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.25))),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                          child: Text(selected.name.isNotEmpty ? selected.name[0] : '?',
                              style: GoogleFonts.outfit(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w800, fontSize: 15))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(selected.name,
                              style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                          Row(children: [
                            const Icon(Icons.account_balance_wallet_rounded, size: 11, color: EnhancedTheme.accentCyan),
                            const SizedBox(width: 4),
                            Text(
                              'Wallet: ₦${selected.walletBalance.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: selected.walletBalance < 0
                                    ? EnhancedTheme.errorRed
                                    : EnhancedTheme.accentCyan,
                                fontSize: 11, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                        ])),
                        GestureDetector(
                          onTap: () => ref.read(selectedCustomerProvider.notifier).state = null,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.close_rounded, color: EnhancedTheme.errorRed, size: 14)),
                        ),
                      ]),
                    ),
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 20),
              ],

              // ── Buyer Name ──────────────────────────────────────────────────
              Text('Buyer Name (optional)',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: TextField(
                    controller: _buyerNameCtrl,
                    style: TextStyle(color: context.labelColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. John Doe',
                      hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: context.hintColor, size: 18),
                      filled: true,
                      fillColor: context.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: EnhancedTheme.primaryTeal, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 80.ms),
              const SizedBox(height: 20),

              // ── Payment Method ───────────────────────────────────────────────
              Text('Payment Method',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              // Large method selector cards with icons and gradients
              ...List.generate(_PayMethod.values.length, (i) {
                final m = _PayMethod.values[i];
                if (m == _PayMethod.wallet && selected == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _methodCard(m),
                ).animate(delay: (100 + i * 40).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
              }),

              // ── Wallet debt warning ─────────────────────────────────────────
              if (selected != null && _method == _PayMethod.wallet && selected.walletBalance < total) ...[
                const SizedBox(height: 8),
                _warningBanner(
                  'Balance ₦${selected.walletBalance.toStringAsFixed(0)} — wallet will go to '
                  '₦${(selected.walletBalance - total).toStringAsFixed(0)} after this sale.',
                ),
              ],

              // ── Split wallet debt warning ────────────────────────────────────
              if (selected != null && _method == _PayMethod.split && _splitWallet > selected.walletBalance) ...[
                const SizedBox(height: 8),
                _warningBanner(
                  'Wallet portion ₦${_splitWallet.toStringAsFixed(0)} exceeds balance '
                  '₦${selected.walletBalance.toStringAsFixed(0)} — wallet will run negative.',
                ),
              ],

              // ── Split Payment Fields ─────────────────────────────────────────
              if (_method == _PayMethod.split) ...[
                const SizedBox(height: 20),
                Text('Split Amounts',
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Amounts must sum to ₦${total.toStringAsFixed(2)}.',
                    style: TextStyle(color: context.hintColor, fontSize: 12)),
                const SizedBox(height: 14),
                _splitField(_cashCtrl,  'Cash',          Icons.payments_rounded,                    EnhancedTheme.successGreen),
                const SizedBox(height: 10),
                _splitField(_cardCtrl,  'Card / POS',    Icons.credit_card_rounded,                 EnhancedTheme.accentPurple),
                const SizedBox(height: 10),
                _splitField(_bankCtrl,  'Bank Transfer', Icons.account_balance_rounded,             EnhancedTheme.infoBlue),
                const SizedBox(height: 10),
                if (selected != null)
                  _splitField(_walletCtrl, 'Wallet',  Icons.account_balance_wallet_rounded,         EnhancedTheme.warningAmber),
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
                  final color = ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: color, size: 16),
                        const SizedBox(width: 8),
                        Text(label, style: TextStyle(
                            color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                      Text('Sum: ₦${_splitSum.toStringAsFixed(2)}',
                          style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                    ]),
                  );
                }),
              ],

              const SizedBox(height: 28),

              // ── Gradient Confirm Button with glow shadow ─────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: (cart.isEmpty || _processing || !_splitValid)
                      ? null
                      : LinearGradient(colors: [_method.accentColor, _method.accentColor.withValues(alpha: 0.7)]),
                  color: (cart.isEmpty || _processing || !_splitValid)
                      ? context.cardColor.withValues(alpha: 0.4)
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: (cart.isEmpty || _processing || !_splitValid)
                      ? null
                      : [BoxShadow(
                          color: _method.accentColor.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        )],
                ),
                child: SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: (cart.isEmpty || _processing || !_splitValid) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _processing
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_method.icon, size: 20, color: Colors.black),
                          const SizedBox(width: 10),
                          Text('Confirm Payment  ₦${total.toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                        ]),
                )),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),
            ]),
          )),
        ])),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _methodCard(_PayMethod m) {
    final active = _method == m;
    final color = m.accentColor;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)])
              : null,
          color: active ? null : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : context.borderColor,
            width: active ? 1.5 : 1.0,
          ),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: active
                  ? LinearGradient(colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)])
                  : null,
              color: active ? null : context.cardColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: active ? color.withValues(alpha: 0.4) : context.borderColor,
              ),
            ),
            child: Icon(m.icon, color: active ? color : context.subLabelColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.label, style: TextStyle(
                color: active ? color : context.labelColor,
                fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            if (active)
              Text('Selected', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
          ])),
          if (active)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: color, size: 14),
            ),
        ]),
      ),
    );
  }

  Widget _warningBanner(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: EnhancedTheme.warningAmber.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: EnhancedTheme.warningAmber, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 12))),
    ]),
  );

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

  @override
  Widget build(BuildContext context) {
    final color = method.accentColor;
    final receiptId = saleData['receiptId'] as String? ?? '';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF1E293B).withValues(alpha: 0.97) : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Gradient handle strip
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [EnhancedTheme.successGreen, EnhancedTheme.accentCyan]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Success circle with glow
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [EnhancedTheme.successGreen, Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: EnhancedTheme.successGreen.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.black, size: 44),
            ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut),

            const SizedBox(height: 18),
            Text('Payment Successful!',
                style: GoogleFonts.outfit(color: context.labelColor, fontSize: 23, fontWeight: FontWeight.w800))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 6),

            // Amount display
            RichText(
              text: TextSpan(
                style: TextStyle(color: context.subLabelColor, fontSize: 14),
                children: [
                  const TextSpan(text: '₦'),
                  TextSpan(
                    text: total.toStringAsFixed(2),
                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const TextSpan(text: '  via'),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms),

            const SizedBox(height: 10),
            // Payment method badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(method.icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(method.label,
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ).animate().fadeIn(delay: 300.ms),

            if (receiptId.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: Text(receiptId,
                    style: TextStyle(color: context.hintColor, fontSize: 11, fontFamily: 'monospace')),
              ),
            ],

            const SizedBox(height: 28),

            // Print Receipt button — gradient (direct print, no sheet needed)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Center(child: ReceiptPrintButton(saleData: saleData)),
              ),
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.15, end: 0),

            const SizedBox(height: 10),
            // View Receipt button — outline
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: onViewReceipt,
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: Text('View Receipt',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.accentCyan,
                side: const BorderSide(color: EnhancedTheme.accentCyan),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            )).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: onDone,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.labelColor,
                side: BorderSide(color: context.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text('New Sale',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
            )).animate().fadeIn(delay: 450.ms),
          ]),
        ),
      ),
    );
  }
}

// ── Snack type helper ─────────────────────────────────────────────────────────
enum _SnackType { success, error, warning }
