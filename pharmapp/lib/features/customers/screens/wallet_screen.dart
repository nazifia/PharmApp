import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _amountCtrl = TextEditingController();
  bool _isTopUp = true;

  final _transactions = [
    {'date': 'Mar 4, 2026',  'type': 'Top-up',   'amount': 500.0,   'note': 'Cash deposit'},
    {'date': 'Mar 4, 2026',  'type': 'Payment',  'amount': -250.0,  'note': 'Invoice #1042'},
    {'date': 'Feb 28, 2026', 'type': 'Payment',  'amount': -450.0,  'note': 'Invoice #1036'},
    {'date': 'Feb 25, 2026', 'type': 'Top-up',   'amount': 2000.0,  'note': 'Transfer'},
    {'date': 'Feb 20, 2026', 'type': 'Payment',  'amount': -3200.0, 'note': 'Invoice #1028'},
    {'date': 'Feb 15, 2026', 'type': 'Refund',   'amount': 900.0,   'note': 'Returned items'},
    {'date': 'Feb 10, 2026', 'type': 'Payment',  'amount': -750.0,  'note': 'Invoice #1019'},
  ];

  double get _balance => _transactions.fold(0, (s, t) => s + (t['amount'] as double));

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final customerId = GoRouterState.of(context).pathParameters['id'] ?? '1';

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight))),
          SafeArea(child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
                const Expanded(child: Text('Wallet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
              ]),
            ),

            // Balance card
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [EnhancedTheme.successGreen.withOpacity(0.2), EnhancedTheme.primaryTeal.withOpacity(0.2)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: EnhancedTheme.successGreen.withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: EnhancedTheme.successGreen, size: 36),
                      const SizedBox(height: 12),
                      Text('₹${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Customer #$customerId Balance',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                      const SizedBox(height: 20),

                      // Top-up / Deduct toggle
                      Row(children: [
                        Expanded(child: GestureDetector(
                          onTap: () => setState(() => _isTopUp = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isTopUp ? EnhancedTheme.successGreen : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Top Up', textAlign: TextAlign.center,
                                style: TextStyle(color: _isTopUp ? Colors.white : Colors.white54,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: GestureDetector(
                          onTap: () => setState(() => _isTopUp = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isTopUp ? EnhancedTheme.errorRed : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Deduct', textAlign: TextAlign.center,
                                style: TextStyle(color: !_isTopUp ? Colors.white : Colors.white54,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        )),
                      ]),
                      const SizedBox(height: 12),

                      // Amount input + confirm
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter amount…',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              prefixText: '₹ ',
                              prefixStyle: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_amountCtrl.text.isEmpty) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${_isTopUp ? "Topped up" : "Deducted"} ₹${_amountCtrl.text}')));
                            _amountCtrl.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTopUp ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Confirm'),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),

            // Transactions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                const Text('Transactions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_transactions.length} records', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ]),
            ),

            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _transactions.length,
              itemBuilder: (_, i) => _txRow(_transactions[i]),
            )),
          ])),
        ],
      ),
    );
  }

  Widget _txRow(Map<String, dynamic> tx) {
    final amount = tx['amount'] as double;
    final isCredit = amount > 0;
    final color = tx['type'] == 'Refund' ? EnhancedTheme.accentCyan
        : isCredit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
    final icon = tx['type'] == 'Refund' ? Icons.undo_rounded
        : isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx['type'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(tx['note'] as String, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${isCredit ? "+" : ""}₹${amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(tx['date'] as String, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}
