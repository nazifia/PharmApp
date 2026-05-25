import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/shared/models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/drug_interaction_provider.dart';
import '../providers/pos_api_provider.dart';

class RetailCartScreen extends ConsumerStatefulWidget {
  const RetailCartScreen({super.key});

  @override
  ConsumerState<RetailCartScreen> createState() => _RetailCartScreenState();
}

class _RetailCartScreenState extends ConsumerState<RetailCartScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _checkout() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }
    context.push('/payment');
  }

  Future<void> _sendToCashier() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showSnackBar('Cart is empty', type: _SnackType.error);
      return;
    }

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
                  border: Border.all(color: Colors.black.withValues(alpha: 0.10), width: 1.5),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.send_rounded, color: EnhancedTheme.primaryTeal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text('Send to Cashier',
                          style: GoogleFonts.outfit(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w700)),
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
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.black38, size: 18),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
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
                            side: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
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
                          child: const Text('Send', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
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

    final items = cart.map((c) => {
      'itemId': c.item.id,
      'barcode': c.item.barcode,
      'quantity': c.quantity,
      'price': c.item.price,
      'discount': c.discount,
    }).toList();
    final customerId = ref.read(selectedCustomerProvider)?.id;
    try {
      await ref.read(posApiProvider).sendToCashier(
        items,
        customerId: customerId,
        patientName: patientName.isEmpty ? null : patientName,
      );
      if (!mounted) return;
      ref.read(cartProvider.notifier).clearCart();
      ref.read(prescriptionCartBindingsProvider.notifier).state = {};
      ref.read(selectedCustomerProvider.notifier).state = null;
      _showSnackBar('Payment request sent to cashier', type: _SnackType.success);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response == null) {
        await ref.read(offlineMutationQueueProvider.notifier).enqueue(
          'POST', '/pos/payment-requests/',
          body: {
            'items': items,
            if (customerId != null) 'customer_id': customerId,
            'payment_type': 'retail',
            if (patientName.isNotEmpty) 'patientName': patientName,
          },
          description: 'Send payment request to cashier${patientName.isNotEmpty ? ' for $patientName' : ''}',
        );
        ref.read(cartProvider.notifier).clearCart();
        ref.read(prescriptionCartBindingsProvider.notifier).state = {};
        ref.read(selectedCustomerProvider.notifier).state = null;
        _showSnackBar('Offline — request queued for sync', type: _SnackType.warning);
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar(e.response?.data?['detail']?.toString() ?? '$e', type: _SnackType.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('$e', type: _SnackType.error);
    }
  }

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

  Color _warningSeverityColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'allergy':
      case 'major':
      case 'high':
        return EnhancedTheme.errorRed;
      case 'low':
      case 'minor':
        return EnhancedTheme.infoBlue;
      default:
        return EnhancedTheme.warningAmber;
    }
  }

  void _showInteractionDialog(List<PosWarning> warnings) {
    final patientWarns = warnings.where((w) => w.source == 'Patient Profile').toList();
    final rxNormWarns  = warnings.where((w) => w.source != 'Patient Profile').toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_rounded, color: EnhancedTheme.warningAmber, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Drug Warnings',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (patientWarns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _dialogSection('Patient Profile', patientWarns),
                ],
                if (rxNormWarns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _dialogSection('Drug-Drug Interactions', rxNormWarns),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood',
                style: TextStyle(color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _dialogSection(String heading, List<PosWarning> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(heading,
            style: const TextStyle(color: Colors.black54, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
      const SizedBox(height: 8),
      ...items.asMap().entries.map((e) {
        final i = e.key;
        final w = e.value;
        final color = _warningSeverityColor(w.severity);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i > 0) const Divider(color: Colors.black12, height: 16),
          Row(children: [
            Expanded(child: Text(w.title,
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(w.severity.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ]),
          if (w.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(w.description, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ],
          if (w.source.isNotEmpty && w.source != 'Patient Profile') ...[
            const SizedBox(height: 3),
            Text('Source: ${w.source}', style: const TextStyle(color: Colors.black38, fontSize: 10)),
          ],
        ]);
      }),
    ]);
  }

  Widget _interactionBanner(AsyncValue<List<PosWarning>> warningsAsync) {
    return warningsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: EnhancedTheme.primaryTeal)),
          const SizedBox(width: 8),
          Text('Checking drug interactions…',
              style: TextStyle(color: context.subLabelColor, fontSize: 11)),
        ]),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (warnings) {
        if (warnings.isEmpty) return const SizedBox.shrink();
        final hasAllergy = warnings.any((w) => w.severity.toLowerCase() == 'allergy');
        final hasHigh    = warnings.any((w) => ['high', 'major'].contains(w.severity.toLowerCase()));
        final color      = (hasAllergy || hasHigh) ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber;
        final label      = hasAllergy
            ? '${warnings.length} allergy/interaction warning${warnings.length > 1 ? 's' : ''} — tap to review'
            : '${warnings.length} drug warning${warnings.length > 1 ? 's' : ''} detected — tap to review';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => _showInteractionDialog(warnings),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.40)),
              ),
              child: Row(children: [
                Icon(hasAllergy ? Icons.emergency_rounded : Icons.warning_rounded, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(label,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
                Icon(Icons.chevron_right_rounded, color: color, size: 16),
              ]),
            ),
          ),
        );
      },
    );
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart           = ref.watch(cartProvider);
    final cartTotal      = cart.fold(0.0, (s, c) => s + c.total);
    final cartCount      = cart.fold<int>(0, (s, c) => s + c.quantity);
    final interactionsAsync = ref.watch(combinedPosWarningsProvider);

    final filtered = _searchQuery.isEmpty
        ? cart
        : cart.where((c) => c.item.name.toLowerCase().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _buildHeader(context, cart.length, cartCount),
          if (cart.isNotEmpty) _buildSearchBar(),
          if (cart.isNotEmpty) _interactionBanner(interactionsAsync),
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
                      itemBuilder: (_, i) => _CartItemRow(
                        key: ValueKey(filtered[i].item.id),
                        item: filtered[i],
                      ).animate(delay: (i * 30).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0),
                    )),
          _buildFooter(cart, cartTotal),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, int lineCount, int unitCount) {
    return Container(
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
          Text('Cart',
              style: GoogleFonts.outfit(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w700)),
          Text('$lineCount line${lineCount != 1 ? 's' : ''} · $unitCount unit${unitCount != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ])),
        if (unitCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_rounded, color: Colors.black, size: 13),
              const SizedBox(width: 4),
              Text('$unitCount',
                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
            EnhancedTheme.accentCyan.withValues(alpha: 0.06),
          ]),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.shopping_cart_outlined, color: context.hintColor, size: 32),
      ),
      const SizedBox(height: 12),
      Text('Cart is empty', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Go back and tap an item to add it', style: TextStyle(color: context.subLabelColor, fontSize: 13)),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, size: 16, color: EnhancedTheme.primaryTeal),
        label: const Text('Back to catalogue', style: TextStyle(color: EnhancedTheme.primaryTeal)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: EnhancedTheme.primaryTeal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      ),
    ]));
  }

  Widget _buildFooter(List<CartItem> cart, double cartTotal) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${cart.length} lines · ${cart.fold<int>(0, (s, c) => s + c.quantity)} units',
                        style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    const Text('Total Amount', style: TextStyle(color: Colors.black87, fontSize: 12)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(fmtN(cartTotal),
                        style: GoogleFonts.outfit(
                            color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clearCart();
                    ref.read(prescriptionCartBindingsProvider.notifier).state = {};
                    ref.read(selectedCustomerProvider.notifier).state = null;
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
                    gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35),
                      blurRadius: 10, offset: const Offset(0, 3),
                    )],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: cart.isEmpty ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700)),
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
                label: const Text('Send to Cashier', style: TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Cart item row ──────────────────────────────────────────────────────────────

class _CartItemRow extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartItemRow({required this.item, super.key});

  @override
  ConsumerState<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends ConsumerState<_CartItemRow> {
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(
        text: widget.item.discount > 0 ? widget.item.discount.toStringAsFixed(0) : '');
  }

  @override
  void didUpdateWidget(_CartItemRow old) {
    super.didUpdateWidget(old);
    if (old.item.discount != widget.item.discount) {
      final parsed = double.tryParse(_discountCtrl.text) ?? 0;
      if (parsed != widget.item.discount) {
        _discountCtrl.text = widget.item.discount > 0
            ? widget.item.discount.toStringAsFixed(0)
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
    final c = widget.item;
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
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.item.name,
                    style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                RichText(text: TextSpan(
                  style: TextStyle(color: context.subLabelColor, fontSize: 11),
                  children: [
                    TextSpan(text: fmtN(c.item.price)),
                    const TextSpan(text: ' × '),
                    TextSpan(text: '${c.quantity}',
                        style: const TextStyle(color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' = '),
                    TextSpan(text: fmtN(c.total),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                )),
              ])),
              const SizedBox(width: 8),
              Row(children: [
                _qtyBtn(Icons.remove_rounded,
                    () => ref.read(cartProvider.notifier).updateQuantity(c.item.id, c.quantity - 1),
                    color: EnhancedTheme.errorRed),
                _QtyField(
                  quantity: c.quantity,
                  maxStock: c.item.stock,
                  onChanged: (n) => ref.read(cartProvider.notifier).updateQuantity(c.item.id, n),
                ),
                _qtyBtn(Icons.add_rounded,
                    () => ref.read(cartProvider.notifier).updateQuantity(c.item.id, c.quantity + 1),
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
                child: const Icon(Icons.discount_rounded, color: EnhancedTheme.warningAmber, size: 12),
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
                    ref.read(cartProvider.notifier).updateDiscount(c.item.id, d);
                  },
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(cartProvider.notifier).removeItem(c.item.id),
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

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {required Color color}) => GestureDetector(
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

// ── Editable quantity field ────────────────────────────────────────────────────

class _QtyField extends StatefulWidget {
  final int quantity;
  final int maxStock;
  final ValueChanged<int> onChanged;
  const _QtyField({required this.quantity, required this.maxStock, required this.onChanged});

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void didUpdateWidget(_QtyField old) {
    super.didUpdateWidget(old);
    if (old.quantity != widget.quantity) {
      final parsed = int.tryParse(_ctrl.text);
      if (parsed != widget.quantity) {
        _ctrl.text = '${widget.quantity}';
        _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
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
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w700),
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n >= 1) {
            widget.onChanged(n.clamp(1, widget.maxStock));
          }
        },
        onSubmitted: (v) {
          final n = int.tryParse(v) ?? widget.quantity;
          final clamped = n.clamp(1, widget.maxStock);
          widget.onChanged(clamped);
          _ctrl.text = '$clamped';
        },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.borderColor)),
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
        ),
      ),
    );
  }
}

enum _SnackType { success, error, warning }
