import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

// ── Public helper ─────────────────────────────────────────────────────────────

/// Show the receipt as a full-screen bottom sheet.
/// [saleData] is the raw map returned by the backend checkout/sale-detail API.
void showReceiptSheet(BuildContext context, Map<String, dynamic> saleData) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReceiptSheet(saleData: saleData),
  );
}

// ── Receipt Sheet ─────────────────────────────────────────────────────────────

class ReceiptSheet extends StatelessWidget {
  final Map<String, dynamic> saleData;
  const ReceiptSheet({super.key, required this.saleData});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // ── drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 44, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // ── action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4), blurRadius: 8)],
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Receipt',
                      style: TextStyle(
                          color: context.labelColor,
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Tap print to share or print',
                      style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ]),
              ),
              _PrintButton(saleData: saleData),
              const SizedBox(width: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: context.hintColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _ReceiptCard(saleData: saleData),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Print button ──────────────────────────────────────────────────────────────

class _PrintButton extends StatefulWidget {
  final Map<String, dynamic> saleData;
  const _PrintButton({required this.saleData});

  @override
  State<_PrintButton> createState() => _PrintButtonState();
}

class _PrintButtonState extends State<_PrintButton> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        name: widget.saleData['receiptId'] as String? ?? 'Receipt',
        onLayout: (format) => _buildPdf(widget.saleData, format),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: _printing ? null : const LinearGradient(
          colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
        ),
        color: _printing ? Colors.white.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(12),
        border: _printing ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
      ),
      child: TextButton.icon(
        onPressed: _printing ? null : _print,
        icon: _printing
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: EnhancedTheme.primaryTeal))
            : const Icon(Icons.print_rounded, size: 16, color: Colors.black),
        label: Text(_printing ? 'Printing…' : 'Print',
            style: TextStyle(
                color: _printing ? EnhancedTheme.primaryTeal : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Receipt Card (on-screen) ──────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> saleData;
  const _ReceiptCard({required this.saleData});

  // ── parsed fields
  String get receiptId =>
      saleData['receiptId'] as String? ?? '#${saleData['id']}';
  String get orgName    => saleData['organizationName']    as String? ?? 'PharmApp';
  String get orgAddress => saleData['organizationAddress'] as String? ?? '';
  String get orgPhone   => saleData['organizationPhone']   as String? ?? '';
  String get customerName =>
      saleData['customerName'] as String? ?? saleData['buyerName'] as String? ?? 'Walk-in';
  String get cashierName   => saleData['cashierName']  as String? ?? '';
  String get dispenserName => saleData['dispenserName'] as String? ?? '';
  String get paymentMethod => saleData['paymentMethod'] as String? ?? 'cash';
  bool   get isWholesale   => saleData['isWholesale'] as bool? ?? false;
  String get status        => saleData['status'] as String? ?? 'completed';
  double get total         => (saleData['totalAmount'] as num?)?.toDouble() ?? 0;
  double get discountTotal => (saleData['discountTotal'] as num?)?.toDouble() ?? 0;
  List<dynamic> get items  => saleData['items'] as List<dynamic>? ?? [];

  Map<String, double> get payments {
    final result = <String, double>{};
    final list = saleData['payments'] as List<dynamic>? ?? [];
    for (final p in list) {
      final pm = p as Map<String, dynamic>;
      final method = pm['paymentMethod'] as String? ?? 'cash';
      final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
      if (amount > 0) result[method] = (result[method] ?? 0) + amount;
    }
    if (result.isEmpty) {
      final pc = (saleData['paymentCash'] as num?)?.toDouble() ?? 0;
      final pp = (saleData['paymentPos'] as num?)?.toDouble() ?? 0;
      final pt = (saleData['paymentTransfer'] as num?)?.toDouble() ?? 0;
      final pw2 = (saleData['paymentWallet'] as num?)?.toDouble() ?? 0;
      if (pc > 0) result['cash'] = pc;
      if (pp > 0) result['pos'] = pp;
      if (pt > 0) result['transfer'] = pt;
      if (pw2 > 0) result['wallet'] = pw2;
    }
    return result;
  }

  String get dateStr {
    final raw = saleData['created'] as String? ??
        saleData['createdAt'] as String? ??
        saleData['created_at'] as String? ?? '';
    return _formatDateTime(raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textDark = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMid  = isDark ? Colors.white70 : const Color(0xFF475569);
    final textHint = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final divider  = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final dash     = isDark ? Colors.white24 : const Color(0xFFCBD5E1);

    Widget row(String label, String value, {
      Color? valueColor, double fontSize = 13, bool bold = false
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: Row(children: [
            Expanded(child: Text(label,
                style: TextStyle(color: textMid, fontSize: fontSize))),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? textDark,
                    fontSize: fontSize,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );

    Widget dashedLine() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: List.generate(48, (i) => Expanded(
        child: Container(
          height: 1.5,
          color: i.isEven ? dash : Colors.transparent,
        ),
      ))),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 28, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── HEADER ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(children: [
                // Success icon with glow
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                    ),
                  ),
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.45),
                          blurRadius: 16, spreadRadius: 2),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icons/app_icon.png',
                        width: 56, height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ]).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text(orgName,
                    style: TextStyle(
                        color: textDark, fontSize: 22,
                        fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                if (orgAddress.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(orgAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMid, fontSize: 11)),
                ],
                if (orgPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(orgPhone,
                      style: TextStyle(color: textHint, fontSize: 10)),
                ],
                const SizedBox(height: 12),
                // Success chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, color: EnhancedTheme.successGreen, size: 14),
                    const SizedBox(width: 6),
                    const Text('Sale Completed', style: TextStyle(
                        color: EnhancedTheme.successGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── RECEIPT META ────────────────────────────────────────────
                dashedLine(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15)),
                  ),
                  child: Column(children: [
                    row('Receipt No.', receiptId,
                        valueColor: EnhancedTheme.primaryTeal, bold: true),
                    row('Date & Time', dateStr),
                    row('Customer', customerName),
                    if (dispenserName.isNotEmpty)
                      row('Dispenser', dispenserName),
                    if (cashierName.isNotEmpty)
                      row('Cashier', cashierName),
                    row('Type',
                        isWholesale ? 'Wholesale' : 'Retail',
                        valueColor: isWholesale
                            ? EnhancedTheme.accentPurple
                            : EnhancedTheme.primaryTeal),
                    Row(children: [
                      Expanded(
                          child: Text('Status',
                              style: TextStyle(color: textMid, fontSize: 13))),
                      _StatusBadge(status),
                    ]),
                  ]),
                ),

                // ── ITEMS ────────────────────────────────────────────────────
                dashedLine(),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: EnhancedTheme.accentCyan, size: 12),
                  ),
                  const SizedBox(width: 7),
                  Text('ITEMS',
                      style: TextStyle(
                          color: textHint, fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                ]),
                const SizedBox(height: 10),
                ...items.map((i) {
                  final item = i as Map<String, dynamic>;
                  final name = item['name'] as String? ?? '';
                  final brand = item['brand'] as String? ?? '';
                  final form  = item['dosageForm'] as String? ?? '';
                  final unit  = item['unit'] as String? ?? '';
                  final qty   = (item['quantity'] as num?)?.toInt() ?? 0;
                  final price = (item['price'] as num?)?.toDouble() ?? 0;
                  final disc  = (item['discount'] as num?)?.toDouble() ?? 0;
                  final sub   = (item['subtotal'] as num?)?.toDouble()
                      ?? (price * qty - disc);

                  final desc = [if (brand.isNotEmpty) brand,
                                if (form.isNotEmpty)  form,
                                if (unit.isNotEmpty)  unit]
                      .join(' · ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: divider),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(child: Text(name,
                            style: TextStyle(
                                color: textDark, fontSize: 13,
                                fontWeight: FontWeight.w700))),
                        Text('₦${_fmt(sub)}',
                            style: TextStyle(
                                color: textDark, fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ]),
                      if (desc.isNotEmpty)
                        Text(desc,
                            style: TextStyle(color: textHint, fontSize: 10)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('×$qty',
                              style: const TextStyle(color: EnhancedTheme.accentCyan,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text('₦${_fmt(price)} each',
                            style: TextStyle(color: textMid, fontSize: 11)),
                        if (disc > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('-₦${_fmt(disc)} off',
                                style: const TextStyle(
                                    color: EnhancedTheme.warningAmber,
                                    fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    ]),
                  );
                }),

                // ── TOTALS ───────────────────────────────────────────────────
                if (discountTotal > 0) ...[
                  row('Subtotal', '₦${_fmt(total + discountTotal)}', valueColor: textMid),
                  row('Discount', '-₦${_fmt(discountTotal)}',
                      valueColor: EnhancedTheme.warningAmber),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                        EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                        blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TOTAL AMOUNT',
                          style: TextStyle(
                              color: textHint, fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      const SizedBox(height: 2),
                      Text(isWholesale ? 'Wholesale Sale' : 'Retail Sale',
                          style: TextStyle(color: textMid, fontSize: 11)),
                    ]),
                    const Spacer(),
                    Text('₦${_fmt(total)}',
                        style: const TextStyle(
                            color: EnhancedTheme.primaryTeal,
                            fontSize: 26, fontWeight: FontWeight.w900)),
                  ]),
                ),

                // ── PAYMENT BREAKDOWN ─────────────────────────────────────────
                dashedLine(),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.payments_rounded, color: EnhancedTheme.successGreen, size: 12),
                  ),
                  const SizedBox(width: 7),
                  Text('PAYMENT',
                      style: TextStyle(
                          color: textHint, fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(children: [
                    ...payments.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: divider),
                        ),
                        child: Row(children: [
                          _PayMethodIcon(e.key),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_methodLabel(e.key),
                              style: TextStyle(color: textMid, fontSize: 13, fontWeight: FontWeight.w500))),
                          Text('₦${_fmt(e.value)}',
                              style: TextStyle(
                                  color: textDark, fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    )),
                  ]),
                ),

                // ── FOOTER ───────────────────────────────────────────────────
                dashedLine(),
                Center(
                  child: Column(children: [
                    const Icon(Icons.favorite_rounded,
                        color: EnhancedTheme.errorRed, size: 18),
                    const SizedBox(height: 8),
                    Text('Thank you for your purchase!',
                        style: TextStyle(
                            color: textDark, fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Keep this receipt for returns & reference.',
                        style: TextStyle(color: textHint, fontSize: 10)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: divider),
                      ),
                      child: Text(receiptId,
                          style: TextStyle(
                              color: textHint, fontSize: 9,
                              fontFamily: 'monospace', letterSpacing: 1)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }

  static String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':     return 'Cash';
      case 'pos':
      case 'card':     return 'Card / POS';
      case 'transfer':
      case 'bank_transfer': return 'Bank Transfer';
      case 'wallet':   return 'Wallet';
      default:         return method.toUpperCase();
    }
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'returned':
        color = EnhancedTheme.errorRed; label = 'Returned'; icon = Icons.undo_rounded; break;
      case 'partial_return':
      case 'partially_returned':
        color = EnhancedTheme.warningAmber; label = 'Partial Return'; icon = Icons.remove_circle_outline_rounded; break;
      default:
        color = EnhancedTheme.successGreen; label = 'Completed'; icon = Icons.check_circle_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Payment method icon ───────────────────────────────────────────────────────

class _PayMethodIcon extends StatelessWidget {
  final String method;
  const _PayMethodIcon(this.method);

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (method.toLowerCase()) {
      case 'pos':
      case 'card':    color = EnhancedTheme.accentPurple; icon = Icons.credit_card_rounded; break;
      case 'wallet':  color = EnhancedTheme.warningAmber; icon = Icons.account_balance_wallet_rounded; break;
      case 'transfer':
      case 'bank_transfer': color = EnhancedTheme.infoBlue; icon = Icons.account_balance_rounded; break;
      default:        color = EnhancedTheme.successGreen; icon = Icons.payments_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color, size: 15),
    );
  }
}

// ── PDF builder ───────────────────────────────────────────────────────────────

Future<Uint8List> _buildPdf(
    Map<String, dynamic> data, PdfPageFormat format) async {
  final doc = pw.Document();
  final font = await PdfGoogleFonts.nunitoRegular();
  final fontBold = await PdfGoogleFonts.nunitoBold();
  final fontMono = await PdfGoogleFonts.sourceCodeProRegular();

  final receiptId = data['receiptId'] as String? ?? '#${data['id']}';
  final orgName    = data['organizationName']    as String? ?? 'PharmApp';
  final orgAddress = data['organizationAddress'] as String? ?? '';
  final orgPhone   = data['organizationPhone']   as String? ?? '';
  final customerName = data['customerName'] as String? ??
      data['buyerName'] as String? ?? 'Walk-in';
  final cashierName    = data['cashierName']  as String? ?? '';
  final dispenserName  = data['dispenserName'] as String? ?? '';
  final isWholesale   = data['isWholesale'] as bool? ?? false;
  final status        = data['status'] as String? ?? 'completed';
  final total         = (data['totalAmount'] as num?)?.toDouble() ?? 0;
  final discountTotal = (data['discountTotal'] as num?)?.toDouble() ?? 0;
  final items         = data['items'] as List<dynamic>? ?? [];

  final raw = data['created'] as String? ??
      data['createdAt'] as String? ??
      data['created_at'] as String? ?? '';
  String dateStr = raw;
  try {
    final dt = DateTime.parse(raw).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    dateStr = '${months[dt.month-1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  } catch (_) {}

  // Build payments map
  final payments = <String, double>{};
  final list = data['payments'] as List<dynamic>? ?? [];
  for (final p in list) {
    final pm = p as Map<String, dynamic>;
    final method = pm['paymentMethod'] as String? ?? 'cash';
    final amount = (pm['amount'] as num?)?.toDouble() ?? 0;
    if (amount > 0) payments[method] = (payments[method] ?? 0) + amount;
  }
  if (payments.isEmpty) {
    final pc  = (data['paymentCash']     as num?)?.toDouble() ?? 0;
    final pp  = (data['paymentPos']      as num?)?.toDouble() ?? 0;
    final pt  = (data['paymentTransfer'] as num?)?.toDouble() ?? 0;
    final pw2 = (data['paymentWallet']   as num?)?.toDouble() ?? 0;
    if (pc  > 0) payments['cash']     = pc;
    if (pp  > 0) payments['pos']      = pp;
    if (pt  > 0) payments['transfer'] = pt;
    if (pw2 > 0) payments['wallet']   = pw2;
  }

  String fmt(double v) =>
      v == v.truncateToDouble() ? '₦${v.toStringAsFixed(0)}' : '₦${v.toStringAsFixed(2)}';

  String methodLabel(String m) {
    switch (m.toLowerCase()) {
      case 'pos':
      case 'card': return 'Card / POS';
      case 'transfer':
      case 'bank_transfer': return 'Bank Transfer';
      case 'wallet': return 'Wallet';
      default: return 'Cash';
    }
  }

  const teal  = PdfColor(0.051, 0.580, 0.533);
  const grey  = PdfColor(0.28, 0.35, 0.44);
  const light = PdfColor(0.88, 0.92, 0.96);
  const black = PdfColor(0.06, 0.09, 0.16);

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    margin: const pw.EdgeInsets.all(12),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [

        // ── Header
        pw.Center(child: pw.Column(children: [
          pw.Text(orgName,
              style: pw.TextStyle(font: fontBold, fontSize: 18, color: teal)),
          if (orgAddress.isNotEmpty)
            pw.Text(orgAddress,
                style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          if (orgPhone.isNotEmpty)
            pw.Text(orgPhone,
                style: pw.TextStyle(font: font, fontSize: 7, color: grey)),
          pw.SizedBox(height: 8),
          pw.Divider(color: light),
        ])),

        // ── Meta
        pw.SizedBox(height: 6),
        pw.Row(children: [
          pw.Text('Receipt No:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          pw.Spacer(),
          pw.Text(receiptId,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: teal)),
        ]),
        pw.Row(children: [
          pw.Text('Date:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          pw.Spacer(),
          pw.Text(dateStr, style: pw.TextStyle(font: fontMono, fontSize: 7, color: black)),
        ]),
        pw.Row(children: [
          pw.Text('Customer:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          pw.Spacer(),
          pw.Text(customerName, style: pw.TextStyle(font: fontBold, fontSize: 8, color: black)),
        ]),
        if (dispenserName.isNotEmpty)
          pw.Row(children: [
            pw.Text('Dispenser:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
            pw.Spacer(),
            pw.Text(dispenserName, style: pw.TextStyle(font: font, fontSize: 8, color: black)),
          ]),
        if (cashierName.isNotEmpty)
          pw.Row(children: [
            pw.Text('Cashier:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
            pw.Spacer(),
            pw.Text(cashierName, style: pw.TextStyle(font: font, fontSize: 8, color: black)),
          ]),
        pw.Row(children: [
          pw.Text('Type:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          pw.Spacer(),
          pw.Text(isWholesale ? 'Wholesale' : 'Retail',
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: teal)),
        ]),
        pw.Row(children: [
          pw.Text('Status:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          pw.Spacer(),
          pw.Text(status.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: black)),
        ]),

        // ── Items
        pw.SizedBox(height: 8),
        pw.Divider(color: light),
        pw.Text('ITEMS',
            style: pw.TextStyle(font: fontBold, fontSize: 8,
                color: grey, letterSpacing: 1.5)),
        pw.SizedBox(height: 4),
        ...items.map((i) {
          final item  = i as Map<String, dynamic>;
          final name  = item['name']  as String? ?? '';
          final brand = item['brand'] as String? ?? '';
          final qty   = (item['quantity'] as num?)?.toInt() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final disc  = (item['discount'] as num?)?.toDouble() ?? 0;
          final sub   = (item['subtotal'] as num?)?.toDouble()
              ?? (price * qty - disc);
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Expanded(
                  child: pw.Text(name,
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: black))),
                pw.Text(fmt(sub),
                    style: pw.TextStyle(font: fontBold, fontSize: 9, color: black)),
              ]),
              pw.Row(children: [
                if (brand.isNotEmpty)
                  pw.Text('$brand  ',
                      style: pw.TextStyle(font: font, fontSize: 7, color: grey)),
                pw.Text('$qty × ${fmt(price)}',
                    style: pw.TextStyle(font: font, fontSize: 7, color: grey)),
                if (disc > 0)
                  pw.Text('  -${fmt(disc)} disc',
                      style: pw.TextStyle(font: font, fontSize: 7, color: grey)),
              ]),
              pw.SizedBox(height: 4),
            ],
          );
        }),

        // ── Totals
        pw.Divider(color: light),
        if (discountTotal > 0) ...[
          pw.Row(children: [
            pw.Text('Subtotal:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
            pw.Spacer(),
            pw.Text(fmt(total + discountTotal),
                style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          ]),
          pw.Row(children: [
            pw.Text('Discount:', style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
            pw.Spacer(),
            pw.Text('-${fmt(discountTotal)}',
                style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          ]),
          pw.SizedBox(height: 2),
        ],
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColor(0.051, 0.580, 0.533, 0.1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(children: [
            pw.Text('TOTAL',
                style: pw.TextStyle(font: fontBold, fontSize: 12, color: teal)),
            pw.Spacer(),
            pw.Text(fmt(total),
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: teal)),
          ]),
        ),

        // ── Payment
        pw.SizedBox(height: 6),
        pw.Divider(color: light),
        pw.Text('PAYMENT',
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: grey, letterSpacing: 1.5)),
        pw.SizedBox(height: 4),
        ...payments.entries.map((e) => pw.Row(children: [
          pw.Text(methodLabel(e.key),
              style: pw.TextStyle(font: font, fontSize: 8, color: grey)),
          pw.Spacer(),
          pw.Text(fmt(e.value),
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: black)),
        ])),

        // ── Footer
        pw.SizedBox(height: 10),
        pw.Divider(color: light),
        pw.Center(
          child: pw.Column(children: [
            pw.Text('Thank you for your purchase!',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: black)),
            pw.Text('Keep this receipt for returns & reference.',
                style: pw.TextStyle(font: font, fontSize: 7, color: grey)),
            pw.SizedBox(height: 4),
            pw.Text(receiptId,
                style: pw.TextStyle(font: fontMono, fontSize: 7, color: light)),
          ]),
        ),
      ],
    ),
  ));

  return doc.save();
}
