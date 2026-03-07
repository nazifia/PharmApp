import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

enum _PayMethod { cash, card, wallet, split }

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _PayMethod _method = _PayMethod.cash;
  bool _processing = false;

  // Mock cart — in production this would come from a cart provider
  static const _lines = [
    {'name': 'Paracetamol 500mg', 'qty': 2, 'price': 75.0},
    {'name': 'Vitamin C 500mg',   'qty': 1, 'price': 450.0},
    {'name': 'ORS Sachet',        'qty': 3, 'price': 25.0},
  ];

  double get _subtotal => _lines.fold(0, (s, l) => s + (l['qty'] as int) * (l['price'] as double));
  double get _tax      => _subtotal * 0.05;
  double get _total    => _subtotal + _tax;

  void _confirm() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _processing = false);
    _showSuccessSheet();
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
    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
            colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
        SafeArea(child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Review and confirm', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ])),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Order summary ──────────────────────────────────────────────
              const Text('Order Summary', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(children: [
                      ..._lines.asMap().entries.map((e) => Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: EnhancedTheme.primaryTeal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.medication_rounded, color: EnhancedTheme.primaryTeal, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.value['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('₹${(e.value['price'] as double).toStringAsFixed(0)} × ${e.value['qty']}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                            ])),
                            Text('₹${((e.value['price'] as double) * (e.value['qty'] as int)).toStringAsFixed(0)}',
                                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        if (e.key < _lines.length - 1)
                          Divider(height: 1, color: Colors.white.withOpacity(0.07)),
                      ])),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Totals ────────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(children: [
                      _totalRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}', Colors.white54),
                      const SizedBox(height: 8),
                      _totalRow('Tax (5%)',  '₹${_tax.toStringAsFixed(2)}',     EnhancedTheme.infoBlue),
                      const SizedBox(height: 12),
                      Divider(color: Colors.white.withOpacity(0.12), height: 1),
                      const SizedBox(height: 12),
                      _totalRow('Total', '₹${_total.toStringAsFixed(2)}', EnhancedTheme.successGreen,
                          valueFontSize: 20, valueBold: true),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Payment method ────────────────────────────────────────────
              const Text('Payment Method', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                _methodChip(_PayMethod.cash,   Icons.money_rounded,              'Cash'),
                const SizedBox(width: 8),
                _methodChip(_PayMethod.card,   Icons.credit_card_rounded,        'Card'),
                const SizedBox(width: 8),
                _methodChip(_PayMethod.wallet, Icons.account_balance_wallet_rounded, 'Wallet'),
                const SizedBox(width: 8),
                _methodChip(_PayMethod.split,  Icons.call_split_rounded,         'Split'),
              ]),
              const SizedBox(height: 20),

              // ── Customer info (optional) ──────────────────────────────────
              const Text('Customer (Optional)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _glassInput('Customer name', Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _glassInput('Phone number', Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 32),
            ]),
          )),

          // ── Confirm button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: EnhancedTheme.primaryTeal.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _processing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _processing ? 'Processing…' : 'Confirm Payment  ₹${_total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _totalRow(String label, String value, Color valueColor,
      {double valueFontSize = 14, bool valueBold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
      Text(value, style: TextStyle(color: valueColor, fontSize: valueFontSize,
          fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600)),
    ]);
  }

  Widget _methodChip(_PayMethod method, IconData icon, String label) {
    final active = _method == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? EnhancedTheme.primaryTeal.withOpacity(0.2) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? EnhancedTheme.primaryTeal : Colors.white.withOpacity(0.1),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon, color: active ? EnhancedTheme.primaryTeal : Colors.white38, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              color: active ? EnhancedTheme.primaryTeal : Colors.white38,
              fontSize: 10, fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _glassInput(String hint, IconData icon, {TextInputType? type}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          keyboardType: type,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 18),
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ── Success bottom sheet ──────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final double total;
  final _PayMethod method;
  final VoidCallback onDone;

  const _SuccessSheet({required this.total, required this.method, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final methodLabels = {
      _PayMethod.cash:   'Cash',
      _PayMethod.card:   'Card',
      _PayMethod.wallet: 'Wallet',
      _PayMethod.split:  'Split',
    };

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: EnhancedTheme.successGreen.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: EnhancedTheme.successGreen.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: EnhancedTheme.successGreen, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Payment Successful!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('₹${total.toStringAsFixed(2)} via ${methodLabels[method]}',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
