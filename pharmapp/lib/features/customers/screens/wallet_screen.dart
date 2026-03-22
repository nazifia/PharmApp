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

  void _setQuickAmount(double amount) {
    _amountCtrl.text = amount.toStringAsFixed(0);
    setState(() {});
  }

  void _confirmReset(BuildContext context, WidgetRef ref, int customerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Wallet',
            style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w700)),
        content: Text('This will set the wallet balance to ₦0.00. Are you sure?',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(walletNotifierProvider(customerId).notifier).resetWallet();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Wallet reset to ₦0.00' : 'Reset failed'),
                  backgroundColor: success ? EnhancedTheme.warningAmber : EnhancedTheme.errorRed));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.warningAmber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync     = ref.watch(customerDetailProvider(_customerId));
    final transactionsAsync = ref.watch(walletTransactionsProvider(_customerId));
    final walletState       = ref.watch(walletNotifierProvider(_customerId));
    final processing        = walletState is AsyncLoading;

    final customerName = customerAsync.valueOrNull?.name ?? 'Customer';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/customers')),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customerName,
                    style: TextStyle(color: context.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
                Text('Wallet Management',
                    style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: context.iconOnBg.withValues(alpha: 0.7)),
                onPressed: () {
                  ref.invalidate(customerDetailProvider(_customerId));
                  ref.invalidate(walletTransactionsProvider(_customerId));
                }),
            ]),
          ),

          // ── Balance + Action Card ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTopUp
                          ? [EnhancedTheme.successGreen.withValues(alpha: 0.18),
                             EnhancedTheme.primaryTeal.withValues(alpha: 0.18)]
                          : [EnhancedTheme.errorRed.withValues(alpha: 0.18),
                             EnhancedTheme.accentOrange.withValues(alpha: 0.18)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (_isTopUp ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
                          .withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(children: [
                    // Balance display
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: _isTopUp ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                          size: 24),
                      const SizedBox(width: 8),
                      Text('Current Balance',
                          style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    customerAsync.when(
                      loading: () => const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: EnhancedTheme.successGreen, strokeWidth: 2)),
                      error: (_, __) => Text('—',
                          style: TextStyle(color: context.labelColor, fontSize: 38, fontWeight: FontWeight.w800)),
                      data: (c) {
                        final balance = c.walletBalance;
                        final isNegative = balance < 0;
                        return Text(
                          '${isNegative ? '-' : ''}₦${balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isNegative ? EnhancedTheme.errorRed : EnhancedTheme.successGreen,
                            fontSize: 38, fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Top-up / Deduct / Reset toggle
                    Row(children: [
                      Expanded(child: _modeBtn(
                        label: 'Top Up',
                        icon: Icons.add_circle_outline_rounded,
                        active: _isTopUp,
                        color: EnhancedTheme.successGreen,
                        onTap: () => setState(() => _isTopUp = true),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _modeBtn(
                        label: 'Deduct',
                        icon: Icons.remove_circle_outline_rounded,
                        active: !_isTopUp,
                        color: EnhancedTheme.errorRed,
                        onTap: () => setState(() => _isTopUp = false),
                      )),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _confirmReset(context, ref, _customerId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: EnhancedTheme.warningAmber.withValues(alpha: 0.35))),
                          child: const Icon(Icons.refresh_rounded,
                              color: EnhancedTheme.warningAmber, size: 20),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Quick amount buttons
                    Row(children: [500, 1000, 5000, 10000].map((amt) =>
                      Expanded(child: GestureDetector(
                        onTap: () => _setQuickAmount(amt.toDouble()),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Text(
                            amt >= 1000 ? '₦${amt ~/ 1000}k' : '₦$amt',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: context.labelColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ))
                    ).toList()),
                    const SizedBox(height: 12),

                    // Amount input + confirm
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Enter amount…',
                          hintStyle: TextStyle(color: context.hintColor),
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixText: '₦ ',
                          prefixStyle: TextStyle(
                              color: context.labelColor,
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      )),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: processing ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTopUp ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: processing
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isTopUp ? 'Top Up' : 'Deduct',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),

          // ── Transactions header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(children: [
              Icon(Icons.receipt_long_rounded, color: context.subLabelColor, size: 16),
              const SizedBox(width: 6),
              Text('Transaction History',
                  style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              transactionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
                data: (txs) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${txs.length} records',
                      style: const TextStyle(color: EnhancedTheme.primaryTeal,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),

          // ── Transactions list ────────────────────────────────────────────────
          Expanded(child: transactionsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 40),
              const SizedBox(height: 8),
              Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12),
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(walletTransactionsProvider(_customerId)),
                child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (txs) => txs.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_outlined, color: context.hintColor, size: 48),
                    const SizedBox(height: 12),
                    Text('No transactions yet',
                        style: TextStyle(color: context.subLabelColor, fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: txs.length,
                    itemBuilder: (_, i) => _txRow(txs[i])),
          )),
        ])),
      ]),
    );
  }

  Widget _modeBtn({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: active ? color : context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? color : context.borderColor),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: active ? Colors.white : context.subLabelColor, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            color: active ? Colors.white : context.labelColor,
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _txRow(WalletTransaction tx) {
    final isCredit = tx.isCredit;
    final color = isCredit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
    final icon  = isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final sign  = isCredit ? '+' : '-';

    // Balance-after colour: red when negative
    final balanceAfter     = tx.balanceAfter;
    final balanceAfterColor = balanceAfter != null && balanceAfter < 0
        ? EnhancedTheme.errorRed
        : context.hintColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.displayType,
                  style: TextStyle(color: context.labelColor,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (tx.note.isNotEmpty)
                Text(tx.note,
                    style: TextStyle(color: context.subLabelColor, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              if (tx.date.isNotEmpty)
                Text(tx.date,
                    style: TextStyle(color: context.hintColor, fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$sign₦${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(color: color,
                      fontSize: 14, fontWeight: FontWeight.w800)),
              if (balanceAfter != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Bal: ${balanceAfter < 0 ? '-' : ''}₦${balanceAfter.abs().toStringAsFixed(2)}',
                  style: TextStyle(color: balanceAfterColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
