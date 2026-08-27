import 'dart:convert';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/shared/models/sale.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import '../providers/pos_api_provider.dart';
import '../providers/wholesale_cart_provider.dart';
import 'receipt_screen.dart';

const _kWalkInId   = -1;
const _kWalkInName = 'Walk-in Customer';

// ─────────────────────────────────────────────────────────────────────────────

class WholesaleCartScreen extends ConsumerStatefulWidget {
  const WholesaleCartScreen({super.key});

  @override
  ConsumerState<WholesaleCartScreen> createState() => _WholesaleCartScreenState();
}

class _WholesaleCartScreenState extends ConsumerState<WholesaleCartScreen> {
  final _searchCtrl  = TextEditingController();
  String _searchQuery = '';
  bool   _isSubmitting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────

  void _showSnackBar(String msg, {required _SnackType type}) {
    final color = type == _SnackType.success
        ? EnhancedTheme.successGreen
        : type == _SnackType.error
            ? EnhancedTheme.errorRed
            : type == _SnackType.warning
                ? EnhancedTheme.warningAmber
                : EnhancedTheme.infoBlue;
    final icon = type == _SnackType.success
        ? Icons.check_circle_rounded
        : type == _SnackType.error
            ? Icons.error_rounded
            : type == _SnackType.warning
                ? Icons.cloud_off_rounded
                : Icons.info_rounded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(icon, color: Colors.black, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  // ── Checkout ───────────────────────────────────────────────────────────────

  void _showPaymentSheet() {
    final cart     = ref.read(wsCartProvider);
    final customer = ref.read(wsSelectedCustomerProvider);

    if (cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }
    if (customer == null) {
      _showSnackBar('Please select a customer or choose Walk-in', type: _SnackType.warning);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WsPaymentSheet(
        total:         cart.fold(0.0, (s, l) => s + l.total),
        walletBalance: customer.walletBalance,
        customerName:  customer.name,
        onConfirm:     (method, payments) => _processCheckout(method, payments),
      ),
    );
  }

  Future<void> _processCheckout(String method, Map<String, double> payments) async {
    setState(() => _isSubmitting = true);
    try {
      final cart     = ref.read(wsCartProvider);
      final customer = ref.read(wsSelectedCustomerProvider);
      final total    = cart.fold(0.0, (s, l) => s + l.total);

      final payload = CheckoutPayload(
        items: cart.map((l) => SaleItemPayload(
          barcode:  l.barcode,
          itemId:   l.id,
          quantity: l.qty,
          price:    l.price,
          discount: l.discount,
        )).toList(),
        payment: PaymentPayload(
          cash:         payments['cash'] ?? 0,
          pos:          payments['pos'] ?? 0,
          bankTransfer: payments['bankTransfer'] ?? 0,
          wallet:       payments['wallet'] ?? 0,
        ),
        customerId:    (customer?.id == _kWalkInId) ? null : customer?.id,
        totalAmount:   total,
        isWholesale:   true,
        paymentMethod: method,
        patientName:   customer?.name,
      );

      final result = await ref.read(checkoutProvider.notifier).processCheckout(payload);
      if (!mounted) return;

      if (result == null) {
        final err = ref.read(checkoutProvider).error;
        String msg = 'Checkout failed';
        if (err is DioException) {
          msg = err.response?.data is Map && err.response!.data['detail'] != null
              ? err.response!.data['detail'].toString()
              : 'Checkout failed (${err.response?.statusCode ?? err.message})';
        } else if (err != null) {
          msg = 'Checkout failed: $err';
        }
        _showSnackBar(msg, type: _SnackType.error);
        return;
      }

      final name         = customer?.name ?? 'Customer';
      final customerId   = customer?.id;
      final cartSnapshot = List<WsCartLine>.from(cart);

      ref.read(wsCartProvider.notifier).clearCart();
      ref.read(wsSelectedCustomerProvider.notifier).state = null;

      if (result['offline'] == true) {
        final queue   = ref.read(offlineQueueProvider);
        final queueId = queue.isNotEmpty
            ? queue.last.id
            : DateTime.now().microsecondsSinceEpoch.toString();
        final receiptData = _buildOfflineReceipt(
            cartSnapshot, name, customerId, queueId, total, method, payments);
        final activeBranch = ref.read(activeBranchProvider);
        if (activeBranch != null && activeBranch.id > 0) {
          receiptData['branchName']    = activeBranch.name;
          receiptData['branchAddress'] = activeBranch.address;
          receiptData['branchPhone']   = activeBranch.phone;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_receipt_$queueId', jsonEncode(receiptData));
        if (mounted) _showOfflineSheet(receiptData);
      } else {
        final receiptId = result['receiptId'] as String? ?? result['receipt_id'] as String? ?? '';
        final enrichedResult = Map<String, dynamic>.from(result);
        final activeBranch = ref.read(activeBranchProvider);
        if (activeBranch != null && activeBranch.id > 0) {
          enrichedResult['branchName']    = activeBranch.name;
          enrichedResult['branchAddress'] = activeBranch.address;
          enrichedResult['branchPhone']   = activeBranch.phone;
        }
        if (enrichedResult['customerName'] == null &&
            enrichedResult['customer_name'] == null &&
            enrichedResult['patientName'] == null) {
          enrichedResult['customerName'] = name;
        }
        if (mounted) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _WsSuccessSheet(
              total:         total,
              customerName:  name,
              receiptId:     receiptId,
              paymentMethod: method,
              saleData:      enrichedResult,
              onDone: () {
                Navigator.pop(context); // close success sheet
                Navigator.pop(context); // go back to POS
              },
              onViewReceipt: () {
                Navigator.pop(context);
                showReceiptSheet(context, enrichedResult);
              },
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Checkout failed: $e', type: _SnackType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Map<String, dynamic> _buildOfflineReceipt(
    List<WsCartLine> cart,
    String customerName,
    int? customerId,
    String queueId,
    double total,
    String paymentMethod,
    Map<String, double> payments,
  ) {
    final now    = DateTime.now().toIso8601String();
    final suffix = queueId.length > 6 ? queueId.substring(queueId.length - 6) : queueId;
    return {
      'id':              'offline_$queueId',
      'receiptId':       'OFFLINE-$suffix',
      'status':          'pending_sync',
      '_offlineQueueId': queueId,
      'totalAmount':     total,
      'paymentMethod':   paymentMethod,
      'paymentCash':     payments['cash'] ?? 0,
      'paymentPos':      payments['pos'] ?? 0,
      'paymentTransfer': payments['bankTransfer'] ?? 0,
      'paymentWallet':   payments['wallet'] ?? 0,
      'customerName':    customerName,
      'isWholesale':     true,
      'createdAt':       now,
      'items': cart.map((l) => {
        'name':     l.name,
        'quantity': l.qty,
        'price':    l.price,
        'discount': l.discount,
        'subtotal': l.total,
      }).toList(),
    };
  }

  void _showOfflineSheet(Map<String, dynamic> receiptData) {
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
              color: const Color(0xFF1E293B).withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2))),
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
                  style: GoogleFonts.outfit(color: Colors.black87, fontSize: 21, fontWeight: FontWeight.w800))
                  .animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              const Text(
                'No internet connection. This sale has been saved and will sync automatically when back online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 20),
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
                      style: const TextStyle(color: EnhancedTheme.warningAmber,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 24),
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
                  gradient: const LinearGradient(
                      colors: [EnhancedTheme.warningAmber, Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: EnhancedTheme.warningAmber.withValues(alpha: 0.35),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('OK, Got It',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                )),
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Send to cashier ────────────────────────────────────────────────────────

  Future<void> _sendToCashier() async {
    final cart = ref.read(wsCartProvider);
    if (cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }

    final customer   = ref.read(wsSelectedCustomerProvider);
    final patientName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1.5),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3, width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send_rounded, color: EnhancedTheme.accentCyan, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text('Send to Cashier',
                          style: GoogleFonts.outfit(color: Colors.black87,
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Patient / Customer name (optional)',
                        style: TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'e.g. John Doe',
                        hintStyle: const TextStyle(color: Colors.black38),
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            color: Colors.black38, size: 18),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: EnhancedTheme.accentCyan, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                          child: const Text('Send',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                        ),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (patientName == null || !mounted) return;

    final items = cart.map((l) => {
      'itemId':   l.id,
      'barcode':  l.barcode,
      'quantity': l.qty,
      'price':    l.price,
      'discount': l.discount,
    }).toList();
    final effectiveCustomerId =
        (customer?.id == _kWalkInId) ? null : customer?.id;

    try {
      await ref.read(posApiProvider).sendToCashier(
        items,
        customerId:  effectiveCustomerId,
        paymentType: 'wholesale',
        patientName: patientName.isEmpty ? null : patientName,
      );
      if (!mounted) return;
      ref.read(wsCartProvider.notifier).clearCart();
      ref.read(wsSelectedCustomerProvider.notifier).state = null;
      _showSnackBar('Payment request sent to cashier', type: _SnackType.success);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response == null) {
        await ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/payment-requests/',
          body: {
            'items': items,
            if (effectiveCustomerId != null) 'customer_id': effectiveCustomerId,
            'payment_type': 'wholesale',
            if (patientName.isNotEmpty) 'patientName': patientName,
          },
          description: 'Wholesale payment request${patientName.isNotEmpty ? ' for $patientName' : ''}',
        );
        ref.read(wsCartProvider.notifier).clearCart();
        ref.read(wsSelectedCustomerProvider.notifier).state = null;
        _showSnackBar('Offline — request queued for sync', type: _SnackType.warning);
        if (mounted) Navigator.pop(context);
      } else {
        final msg = e.response?.data is Map && e.response!.data['detail'] != null
            ? e.response!.data['detail'].toString()
            : 'Request failed (${e.response?.statusCode ?? e.message})';
        _showSnackBar(msg, type: _SnackType.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('$e', type: _SnackType.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cart    = ref.watch(wsCartProvider);
    final total   = cart.fold(0.0, (s, l) => s + l.total);
    final lineCount = cart.length;
    final unitCount = cart.fold(0.0, (s, l) => s + l.qty);

    final filtered = _searchQuery.isEmpty
        ? cart
        : cart.where((l) => l.name.toLowerCase().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _buildHeader(context, lineCount, unitCount),
          if (cart.isNotEmpty) _buildSearchBar(),
          Expanded(child: cart.isEmpty
              ? _emptyState()
              : filtered.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off_rounded, color: context.hintColor, size: 40),
                      const SizedBox(height: 10),
                      Text('No items match "$_searchQuery"',
                          style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => WsCartItemWidget(
                        key: ValueKey(filtered[i].id),
                        line: filtered[i],
                        onQtyChange:      (id, qty)      => ref.read(wsCartProvider.notifier).updateQty(id, qty),
                        onRemove:         (id)            => ref.read(wsCartProvider.notifier).removeItem(id),
                        onDiscountChange: (id, discount)  => ref.read(wsCartProvider.notifier).updateDiscount(id, discount),
                      ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0),
                    )),
          _buildFooter(cart, total),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, int lineCount, double unitCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            EnhancedTheme.accentCyan.withValues(alpha: 0.2),
            EnhancedTheme.accentPurple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wholesale Cart',
              style: GoogleFonts.outfit(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(
            '$lineCount line${lineCount != 1 ? 's' : ''} · ${fmtWsQty(unitCount)} unit${unitCount != 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ])),
        if (unitCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: EnhancedTheme.accentCyan.withValues(alpha: 0.4),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_rounded, color: Colors.black, size: 13),
              const SizedBox(width: 4),
              Text(fmtWsQty(unitCount),
                  style: const TextStyle(
                      color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: TextStyle(color: context.labelColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search cart items…',
          hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: context.hintColor, size: 16),
                  onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }))
              : null,
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            EnhancedTheme.accentCyan.withValues(alpha: 0.1),
            EnhancedTheme.accentPurple.withValues(alpha: 0.06),
          ]),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.shopping_cart_outlined, color: context.hintColor, size: 32),
      ),
      const SizedBox(height: 12),
      Text('Cart is empty',
          style: GoogleFonts.outfit(
              color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Go back and tap an item to add it',
          style: TextStyle(color: context.subLabelColor, fontSize: 13)),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 16, color: EnhancedTheme.accentCyan),
        label: const Text('Back to catalogue',
            style: TextStyle(color: EnhancedTheme.accentCyan)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: EnhancedTheme.accentCyan),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      ),
    ]));
  }

  Widget _buildFooter(List<WsCartLine> cart, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(children: [
              // Total row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.accentCyan.withValues(alpha: 0.15),
                    EnhancedTheme.accentPurple.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${cart.length} lines · ${fmtWsQty(cart.fold(0.0, (s, l) => s + l.qty))} units',
                      style: TextStyle(color: context.subLabelColor, fontSize: 11),
                    ),
                    const Text('Order Total',
                        style: TextStyle(color: Colors.black87, fontSize: 12)),
                  ])),
                  Text(fmtN(total),
                      style: GoogleFonts.outfit(
                          color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(wsCartProvider.notifier).clearCart();
                    ref.read(wsSelectedCustomerProvider.notifier).state = null;
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EnhancedTheme.errorRed,
                    side: BorderSide(color: EnhancedTheme.errorRed.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: EnhancedTheme.accentCyan.withValues(alpha: 0.35),
                        blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: (cart.isEmpty || _isSubmitting) ? null : _showPaymentSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Processing…' : 'Checkout',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: cart.isEmpty ? null : _sendToCashier,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EnhancedTheme.accentOrange,
                  side: BorderSide(color: EnhancedTheme.accentOrange.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send to Cashier',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PAYMENT SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _WsPaymentSheet extends StatefulWidget {
  final double total;
  final double walletBalance;
  final String customerName;
  final void Function(String method, Map<String, double> payments) onConfirm;

  const _WsPaymentSheet({
    required this.total,
    required this.walletBalance,
    required this.customerName,
    required this.onConfirm,
  });

  @override
  State<_WsPaymentSheet> createState() => _WsPaymentSheetState();
}

class _WsPaymentSheetState extends State<_WsPaymentSheet> {
  String _method = 'bank_transfer';
  bool _isSubmitting = false;

  final _cashCtrl     = TextEditingController();
  final _posCtrl      = TextEditingController();
  final _transferCtrl = TextEditingController();
  final _walletCtrl   = TextEditingController();

  @override
  void dispose() {
    _cashCtrl.dispose();
    _posCtrl.dispose();
    _transferCtrl.dispose();
    _walletCtrl.dispose();
    super.dispose();
  }

  Map<String, double> get _payments {
    switch (_method) {
      case 'cash':          return {'cash': widget.total};
      case 'pos':           return {'pos': widget.total};
      case 'bank_transfer': return {'bankTransfer': widget.total};
      case 'wallet':        return {'wallet': widget.total};
      case 'split':
        return {
          'cash':         double.tryParse(_cashCtrl.text)     ?? 0,
          'pos':          double.tryParse(_posCtrl.text)      ?? 0,
          'bankTransfer': double.tryParse(_transferCtrl.text) ?? 0,
          'wallet':       double.tryParse(_walletCtrl.text)   ?? 0,
        };
      default: return {'bankTransfer': widget.total};
    }
  }

  bool get _splitValid {
    if (_method != 'split') return true;
    return (_payments.values.fold(0.0, (a, b) => a + b) - widget.total).abs() < 0.01;
  }

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return fmtN(v);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.borderColor),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.accentCyan.withValues(alpha: 0.2),
                      EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: EnhancedTheme.accentCyan, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Payment Method',
                      style: GoogleFonts.outfit(
                          color: context.labelColor, fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(widget.customerName,
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      EnhancedTheme.accentCyan.withValues(alpha: 0.18),
                      EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Text('Order Total',
                      style: TextStyle(color: context.subLabelColor,
                          fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('₦',
                        style: GoogleFonts.outfit(
                            color: EnhancedTheme.accentCyan, fontSize: 22,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Text(_fmtNaira(widget.total).replaceAll('₦', ''),
                        style: GoogleFonts.outfit(
                            color: Colors.black, fontSize: 38, fontWeight: FontWeight.w800,
                            letterSpacing: -1)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Text('Select Method',
                  style: GoogleFonts.outfit(
                      color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _methodCard('bank_transfer', 'Bank Transfer',
                  Icons.account_balance_rounded, EnhancedTheme.infoBlue),
              const SizedBox(height: 8),
              _methodCard('cash', 'Cash', Icons.payments_rounded, EnhancedTheme.successGreen),
              const SizedBox(height: 8),
              _methodCard('pos', 'POS / Card',
                  Icons.credit_card_rounded, EnhancedTheme.accentPurple),
              const SizedBox(height: 8),
              if (widget.customerName != _kWalkInName) ...[
                _methodCard('wallet', 'Wallet',
                    Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
                const SizedBox(height: 8),
              ],
              _methodCard('split', 'Split Payment',
                  Icons.call_split_rounded, EnhancedTheme.primaryTeal),
              if (_method == 'wallet' && widget.walletBalance < widget.total) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.warningAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: EnhancedTheme.warningAmber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Balance ${fmtN(widget.walletBalance)} — wallet will go to '
                      '${fmtN(widget.walletBalance - widget.total)} after this sale.',
                      style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 11),
                    )),
                  ]),
                ),
              ],
              if (_method == 'split') ...[
                const SizedBox(height: 20),
                Text('Split Payment',
                    style: GoogleFonts.outfit(
                        color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _splitField(_transferCtrl, 'Bank Transfer',
                    Icons.account_balance_rounded, EnhancedTheme.infoBlue),
                const SizedBox(height: 10),
                _splitField(_cashCtrl, 'Cash',
                    Icons.payments_rounded, EnhancedTheme.successGreen),
                const SizedBox(height: 10),
                _splitField(_posCtrl, 'POS / Card',
                    Icons.credit_card_rounded, EnhancedTheme.accentPurple),
                const SizedBox(height: 10),
                _splitField(_walletCtrl, 'Wallet',
                    Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber),
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  final sum  = _payments.values.fold(0.0, (a, b) => a + b);
                  final diff = sum - widget.total;
                  final ok   = diff.abs() < 0.01;
                  final label = ok ? 'Balanced ✓'
                      : diff > 0 ? 'Over by ${fmtN(diff)}' : 'Under by ${fmtN(-diff)}';
                  final color = ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: color, size: 14),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                      Text('Sum: ${fmtN(sum)}',
                          style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    ]),
                  );
                }),
              ],
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  gradient: (_isSubmitting || !_splitValid)
                      ? null
                      : const LinearGradient(
                          colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple]),
                  color: (_isSubmitting || !_splitValid)
                      ? Colors.grey.withValues(alpha: 0.3)
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (_isSubmitting || !_splitValid)
                      ? null
                      : [BoxShadow(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.4),
                          blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || !_splitValid) ? null : () {
                      setState(() => _isSubmitting = true);
                      Navigator.pop(context);
                      widget.onConfirm(_method, _payments);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text('Confirm ${_fmtNaira(widget.total)}',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _methodCard(String value, String label, IconData icon, Color color) {
    final active = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.08),
                ])
              : null,
          color: active ? null : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color : context.borderColor, width: active ? 1.5 : 1.0),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.15) : context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: active ? color.withValues(alpha: 0.3) : context.borderColor),
            ),
            child: Icon(icon,
                color: active ? color : context.subLabelColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: TextStyle(
                  color: active ? color : context.labelColor,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500))),
          if (active)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: color, size: 14),
            ),
        ]),
      ),
    );
  }

  Widget _splitField(TextEditingController ctrl, String label, IconData icon, Color color) {
    return TextField(
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
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SUCCESS SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _WsSuccessSheet extends StatelessWidget {
  final double total;
  final String customerName;
  final String receiptId;
  final String paymentMethod;
  final Map<String, dynamic> saleData;
  final VoidCallback onDone;
  final VoidCallback onViewReceipt;

  const _WsSuccessSheet({
    required this.total,
    required this.customerName,
    required this.receiptId,
    required this.paymentMethod,
    required this.saleData,
    required this.onDone,
    required this.onViewReceipt,
  });

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '₦${(v / 1000).toStringAsFixed(1)}K';
    return fmtN(v);
  }

  (IconData, Color) get _methodMeta {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':         return (Icons.payments_rounded,             EnhancedTheme.successGreen);
      case 'pos':          return (Icons.credit_card_rounded,          EnhancedTheme.accentPurple);
      case 'wallet':       return (Icons.account_balance_wallet_rounded, EnhancedTheme.warningAmber);
      case 'split':        return (Icons.call_split_rounded,           EnhancedTheme.primaryTeal);
      default:             return (Icons.account_balance_rounded,      EnhancedTheme.infoBlue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _methodMeta;
    final label = paymentMethod.replaceAll('_', ' ').toUpperCase();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: context.borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [EnhancedTheme.successGreen, EnhancedTheme.accentCyan]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [EnhancedTheme.successGreen, Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: EnhancedTheme.successGreen.withValues(alpha: 0.4),
                    blurRadius: 20, spreadRadius: 2)],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.black, size: 44),
            ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1),
                duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('Order Placed!',
                style: GoogleFonts.outfit(
                    color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w800))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text('${_fmtNaira(total)} for $customerName',
                style: TextStyle(color: context.subLabelColor, fontSize: 14),
                textAlign: TextAlign.center)
                .animate().fadeIn(delay: 300.ms),
            if (receiptId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: Text(receiptId,
                    style: TextStyle(color: context.hintColor, fontSize: 11,
                        fontFamily: 'monospace')),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 32),
            // Print receipt button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                    blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Center(child: ReceiptPrintButton(saleData: saleData)),
              ),
            ).animate().fadeIn(delay: 380.ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 10),
            // View receipt button
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: onViewReceipt,
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('View Receipt',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.accentCyan,
                side: const BorderSide(color: EnhancedTheme.accentCyan),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            )).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [EnhancedTheme.successGreen, Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: EnhancedTheme.successGreen.withValues(alpha: 0.35),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('New Order',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black)),
                ),
              ),
            ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.2, end: 0),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CART ITEM WIDGET  (public — also used in the wide-layout panel)
// ═══════════════════════════════════════════════════════════════════════════════

class WsCartItemWidget extends StatefulWidget {
  final WsCartLine line;
  final void Function(int id, double qty)      onQtyChange;
  final void Function(int id)                  onRemove;
  final void Function(int id, double discount) onDiscountChange;

  const WsCartItemWidget({
    required this.line,
    required this.onQtyChange,
    required this.onRemove,
    required this.onDiscountChange,
    super.key,
  });

  @override
  State<WsCartItemWidget> createState() => _WsCartItemWidgetState();
}

class _WsCartItemWidgetState extends State<WsCartItemWidget> {
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(
        text: widget.line.discount > 0 ? widget.line.discount.toStringAsFixed(0) : '');
  }

  @override
  void didUpdateWidget(WsCartItemWidget old) {
    super.didUpdateWidget(old);
    if (old.line.discount != widget.line.discount) {
      final parsed = double.tryParse(_discountCtrl.text) ?? 0;
      if (parsed != widget.line.discount) {
        _discountCtrl.text = widget.line.discount > 0
            ? widget.line.discount.toStringAsFixed(0)
            : '';
      }
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [EnhancedTheme.accentCyan, EnhancedTheme.accentPurple],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(line.name,
                    style: TextStyle(color: context.labelColor,
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                RichText(text: TextSpan(
                  style: TextStyle(color: context.subLabelColor, fontSize: 11),
                  children: [
                    TextSpan(text: fmtN(line.price)),
                    const TextSpan(text: ' × '),
                    TextSpan(text: fmtWsQty(line.qty),
                        style: const TextStyle(
                            color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700)),
                    if (line.unitOfDispensing.isNotEmpty)
                      TextSpan(text: ' ${line.unitOfDispensing}'),
                    const TextSpan(text: ' = '),
                    TextSpan(text: fmtN(line.total),
                        style: const TextStyle(
                            color: Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                )),
              ])),
              const SizedBox(width: 8),
              Row(children: [
                _qtyBtn(Icons.remove_rounded,
                    () => widget.onQtyChange(line.id, line.qty - 0.5),
                    color: EnhancedTheme.errorRed),
                WsQtyField(
                  quantity: line.qty,
                  maxStock: line.stock,
                  onChanged: (n) => widget.onQtyChange(line.id, n),
                ),
                _qtyBtn(Icons.add_rounded,
                    () => widget.onQtyChange(line.id, line.qty + 0.5),
                    color: EnhancedTheme.successGreen),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.discount_rounded,
                    color: EnhancedTheme.warningAmber, size: 12),
              ),
              const SizedBox(width: 6),
              Text('Discount:', style: TextStyle(color: context.hintColor, fontSize: 11)),
              const SizedBox(width: 6),
              SizedBox(
                width: 76, height: 28,
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.labelColor, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    hintText: '0',
                    hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
                    prefixText: '₦',
                    prefixStyle: TextStyle(color: context.hintColor, fontSize: 11),
                    filled: true, fillColor: context.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(7)),
                        borderSide: BorderSide(color: EnhancedTheme.warningAmber, width: 1.5)),
                  ),
                  onChanged: (v) {
                    final d = double.tryParse(v) ?? 0;
                    widget.onDiscountChange(line.id, d);
                  },
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => widget.onRemove(line.id),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.close_rounded, color: EnhancedTheme.errorRed, size: 14),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {required Color color}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EDITABLE QTY FIELD  (public)
// ─────────────────────────────────────────────────────────────────────────────

class WsQtyField extends StatefulWidget {
  final double quantity;
  final int maxStock;
  final ValueChanged<double> onChanged;
  const WsQtyField({
      required this.quantity, required this.maxStock, required this.onChanged, super.key});

  @override
  State<WsQtyField> createState() => _WsQtyFieldState();
}

class _WsQtyFieldState extends State<WsQtyField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: fmtWsQty(widget.quantity));
  }

  @override
  void didUpdateWidget(WsQtyField old) {
    super.didUpdateWidget(old);
    if (old.quantity != widget.quantity) {
      final parsed = double.tryParse(_ctrl.text);
      if (parsed != widget.quantity) {
        _ctrl.text = fmtWsQty(widget.quantity);
        _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _ctrl.text.length));
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52, height: 30,
      child: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
            color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700),
        onChanged: (v) {
          final n = double.tryParse(v);
          if (n != null && n >= 0.5) {
            widget.onChanged(n.clamp(0.5, widget.maxStock.toDouble()));
          }
        },
        onSubmitted: (v) {
          final n = double.tryParse(v) ?? widget.quantity;
          final clamped = n.clamp(0.5, widget.maxStock.toDouble());
          widget.onChanged(clamped);
          _ctrl.text = fmtWsQty(clamped);
        },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          filled: true, fillColor: context.cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor)),
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: EnhancedTheme.accentCyan, width: 1.5)),
        ),
      ),
    );
  }
}

enum _SnackType { success, error, warning }
