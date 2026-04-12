import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
        backgroundColor: (success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.black, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(success
              ? '${_isTopUp ? "Topped up" : "Deducted"} ₦${amount.toStringAsFixed(2)}'
              : 'Operation failed — please try again', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
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
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: EnhancedTheme.warningAmber, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Reset Wallet',
              style: TextStyle(color: context.labelColor, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
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
                  backgroundColor: (success ? EnhancedTheme.warningAmber : EnhancedTheme.errorRed).withValues(alpha: 0.92),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  content: Row(children: [
                    Icon(success ? Icons.info_rounded : Icons.error_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(success ? 'Wallet reset to ₦0.00' : 'Reset failed', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                  ]),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.warningAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
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
    final activeColor  = _isTopUp ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),

        // Decorative background blobs
        Positioned(
          top: -50, right: -50,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          top: 80, left: -80,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.05),
            ),
          ),
        ),

        SafeArea(child: CustomScrollView(slivers: [

          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/customers')),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customerName,
                    style: GoogleFonts.outfit(
                        color: context.labelColor, fontSize: 19, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      color: EnhancedTheme.primaryTeal, size: 12),
                  const SizedBox(width: 4),
                  Text('Wallet Management',
                      style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ]),
              ])),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Icon(Icons.refresh_rounded, color: context.iconOnBg, size: 18),
                ),
                onPressed: () {
                  ref.invalidate(customerDetailProvider(_customerId));
                  ref.invalidate(walletTransactionsProvider(_customerId));
                }),
            ]),
          )),

          // ── Balance + Action Card ────────────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTopUp
                          ? [EnhancedTheme.successGreen.withValues(alpha: 0.18),
                             EnhancedTheme.primaryTeal.withValues(alpha: 0.10)]
                          : [EnhancedTheme.errorRed.withValues(alpha: 0.18),
                             EnhancedTheme.accentOrange.withValues(alpha: 0.10)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                  ),
                  child: Column(children: [

                    // Balance display
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded,
                            color: activeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text('Current Balance',
                          style: TextStyle(color: context.subLabelColor, fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 10),
                    customerAsync.when(
                      loading: () => SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: EnhancedTheme.successGreen,
                              backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.15),
                              strokeWidth: 3)),
                      error: (_, __) => Text('—',
                          style: GoogleFonts.outfit(
                              color: context.labelColor, fontSize: 40, fontWeight: FontWeight.w800)),
                      data: (c) {
                        final balance = c.walletBalance;
                        final isNegative = balance < 0;
                        final balColor = isNegative ? EnhancedTheme.errorRed : EnhancedTheme.successGreen;
                        return Column(children: [
                          Text(
                            '${isNegative ? '-' : ''}₦${balance.abs().toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              color: balColor,
                              fontSize: 42, fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (isNegative) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Negative Balance',
                                  style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ]);
                      },
                    ),
                    const SizedBox(height: 18),

                    // Mode toggle buttons
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: EnhancedTheme.warningAmber.withValues(alpha: 0.4))),
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
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: activeColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            amt >= 1000 ? '₦${amt ~/ 1000}k' : '₦$amt',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: activeColor, fontSize: 12, fontWeight: FontWeight.w700),
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
                        style: TextStyle(
                            color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'Enter amount…',
                          hintStyle: TextStyle(color: context.hintColor, fontWeight: FontWeight.w400),
                          filled: true,
                          fillColor: context.isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: activeColor, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixText: '₦ ',
                          prefixStyle: TextStyle(
                              color: activeColor,
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      )),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: processing ? null : _confirm,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: processing ? null : LinearGradient(
                              colors: _isTopUp
                                  ? [EnhancedTheme.successGreen, EnhancedTheme.primaryTeal]
                                  : [EnhancedTheme.errorRed, EnhancedTheme.accentOrange],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            color: processing ? context.cardColor : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: processing ? [] : [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.35),
                                blurRadius: 10, offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: processing
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text(_isTopUp ? 'Top Up' : 'Deduct',
                                  style: GoogleFonts.outfit(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0)),

          // ── Transaction History header ────────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 20, 10),
            child: Row(children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.accentCyan, size: 16),
              const SizedBox(width: 8),
              Text('Transaction History',
                  style: GoogleFonts.outfit(
                      color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              transactionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
                data: (txs) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
                  ),
                  child: Text('${txs.length} records',
                      style: const TextStyle(color: EnhancedTheme.primaryTeal,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          )),

          // ── Transactions list ────────────────────────────────────────────────
          if (transactionsAsync.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 40, height: 40,
                  child: CircularProgressIndicator(
                    color: EnhancedTheme.primaryTeal,
                    backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Loading transactions…', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ])),
            )
          else if (transactionsAsync.hasError)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 36),
                ),
                const SizedBox(height: 12),
                Text('Could not load transactions',
                    style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(walletTransactionsProvider(_customerId)),
                  child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
              ])),
            )
          else if (transactionsAsync.value!.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.02),
                      ]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: EnhancedTheme.primaryTeal, size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text('No transactions yet',
                      style: GoogleFonts.outfit(
                          color: context.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Top up or deduct from the wallet above',
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final txs = transactionsAsync.value!;
                    return _txRow(txs[i])
                        .animate(delay: (i * 30).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.1, end: 0);
                  },
                  childCount: transactionsAsync.value!.length,
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: active ? LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ) : null,
        color: active ? null : context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? Colors.transparent : context.borderColor),
        boxShadow: active ? [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ] : [],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: active ? Colors.black : context.subLabelColor, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            color: active ? Colors.black : context.labelColor,
            fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  Widget _txRow(WalletTransaction tx) {
    final isCredit = tx.isCredit;
    final color    = isCredit ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
    final icon     = isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final sign     = isCredit ? '+' : '-';

    final balanceAfter      = tx.balanceAfter;
    final balanceAfterColor = balanceAfter != null && balanceAfter < 0
        ? EnhancedTheme.errorRed
        : context.hintColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCredit
                    ? EnhancedTheme.successGreen.withValues(alpha: 0.15)
                    : context.borderColor,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx.displayType,
                    style: GoogleFonts.outfit(
                        color: context.labelColor,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (tx.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tx.note,
                      style: TextStyle(color: context.subLabelColor, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (tx.date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tx.date,
                      style: TextStyle(color: context.hintColor, fontSize: 10)),
                ],
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$sign₦${tx.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                        color: color, fontSize: 15, fontWeight: FontWeight.w800)),
                if (balanceAfter != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: balanceAfterColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Bal: ${balanceAfter < 0 ? '-' : ''}₦${balanceAfter.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                          color: balanceAfterColor, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
