import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/customer_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _amountCtrl = TextEditingController();
  bool _isTopUp = true;

  late final int _customerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final idStr = GoRouterState.of(context).pathParameters['id'] ?? '0';
    _customerId = int.tryParse(idStr) ?? 0;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return;

    final notifier = ref.read(walletNotifierProvider(_customerId).notifier);
    final success = _isTopUp
        ? await notifier.topUp(amount)
        : await notifier.deduct(amount);

    _amountCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '${_isTopUp ? "Topped up" : "Deducted"} ₦${amount.toStringAsFixed(2)}'
            : 'Operation failed — please try again'),
        backgroundColor:
            success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync    = ref.watch(customerDetailProvider(_customerId));
    final transactionsAsync = ref.watch(walletTransactionsProvider(_customerId));
    final walletState      = ref.watch(walletNotifierProvider(_customerId));
    final processing       = walletState is AsyncLoading;

    final balance = customerAsync.value?.walletBalance ?? 0.0;

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
                  onPressed: () => context.pop()),
              const Expanded(child: Text('Wallet',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: () {
                  ref.invalidate(customerDetailProvider(_customerId));
                  ref.invalidate(walletTransactionsProvider(_customerId));
                }),
            ]),
          ),

          // ── Balance card ─────────────────────────────────────────────────────
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
                      colors: [
                        EnhancedTheme.successGreen.withValues(alpha: 0.2),
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3))),
                  child: Column(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: EnhancedTheme.successGreen, size: 36),
                    const SizedBox(height: 12),
                    customerAsync.when(
                      loading: () => const CircularProgressIndicator(
                          color: EnhancedTheme.successGreen, strokeWidth: 2),
                      error: (_, __) => const Text('—',
                          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                      data: (c) => Text('₦${c.walletBalance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 4),
                    Text('Customer #$_customerId Balance',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
                    const SizedBox(height: 20),

                    // Top-up / Deduct toggle
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _isTopUp = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isTopUp
                                ? EnhancedTheme.successGreen
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12)),
                          child: Text('Top Up', textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _isTopUp ? Colors.white : Colors.white54,
                                  fontSize: 13, fontWeight: FontWeight.w600))),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _isTopUp = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isTopUp
                                ? EnhancedTheme.errorRed
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12)),
                          child: Text('Deduct', textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: !_isTopUp ? Colors.white : Colors.white54,
                                  fontSize: 13, fontWeight: FontWeight.w600))),
                      )),
                    ]),
                    const SizedBox(height: 12),

                    // Amount input + confirm
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter amount…',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          prefixText: '₦ ',
                          prefixStyle: const TextStyle(color: Colors.white70)),
                      )),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: processing ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTopUp
                              ? EnhancedTheme.successGreen
                              : EnhancedTheme.errorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                        child: processing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Confirm'),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),

          // ── Transactions header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              const Text('Transactions',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              transactionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
                data: (txs) => Text('${txs.length} records',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ),
            ]),
          ),

          // ── Transactions list ────────────────────────────────────────────────
          Expanded(child: transactionsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 40),
              const SizedBox(height: 8),
              Text('$e',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(walletTransactionsProvider(_customerId)),
                child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (txs) => txs.isEmpty
                ? Center(child: Text('No transactions yet',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: txs.length,
                    itemBuilder: (_, i) => _txRow(txs[i])),
          )),
        ])),
      ]),
    );
  }

  Widget _txRow(WalletTransaction tx) {
    final isCredit = tx.amount > 0;
    final isRefund = tx.type.toLowerCase().contains('refund');
    final color = isRefund
        ? EnhancedTheme.accentCyan
        : isCredit
            ? EnhancedTheme.successGreen
            : EnhancedTheme.errorRed;
    final icon = isRefund
        ? Icons.undo_rounded
        : isCredit
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.displayType,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(tx.note,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${isCredit ? "+" : ""}₦${tx.amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(tx.date,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }
}
