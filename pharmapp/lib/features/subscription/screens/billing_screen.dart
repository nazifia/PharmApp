import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/providers/subscription_api_client.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _billingInfoProvider = FutureProvider.autoDispose<BillingInfo>((ref) async {
  return ref.watch(subscriptionApiClientProvider).getBillingInfo();
});

final _billingCycleProvider =
    StateProvider.autoDispose<BillingCycle>((ref) => BillingCycle.monthly);

// ── Screen ────────────────────────────────────────────────────────────────────

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub          = ref.watch(currentSubscriptionProvider);
    final billingAsync = ref.watch(_billingInfoProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppShell.roleFallback(ref));
        }
      },
      child: Scaffold(
        backgroundColor: EnhancedTheme.primaryDark,
        body: Stack(
          children: [
            Container(decoration: context.bgGradient),
            SafeArea(
              child: Column(
                children: [
                  // ── AppBar ─────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.black, size: 20),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppShell.roleFallback(ref));
                            }
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Billing & Invoices',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        billingAsync.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: EnhancedTheme.primaryTeal),
                              )
                            : IconButton(
                                icon: const Icon(Icons.refresh_rounded,
                                    color: Colors.black54, size: 20),
                                onPressed: () =>
                                    ref.invalidate(_billingInfoProvider),
                              ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: billingAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: EnhancedTheme.primaryTeal),
                      ),
                      error: (e, _) => _ErrorRetry(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(_billingInfoProvider)),
                      data: (billing) => _BillingContent(
                          sub: sub, billing: billing, ref: ref),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────

class _BillingContent extends StatelessWidget {
  final Subscription sub;
  final BillingInfo  billing;
  final WidgetRef    ref;

  const _BillingContent(
      {required this.sub, required this.billing, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BillingSummaryCard(sub: sub, billing: billing),
        const SizedBox(height: 12),

        _PaymentMethodCard(billing: billing, ref: ref),
        const SizedBox(height: 12),

        // ── Plans section ──────────────────────────────────────────────────
        _PlansSection(currentSub: sub, ref: ref),
        const SizedBox(height: 12),

        _InvoiceHistoryCard(billing: billing),
        const SizedBox(height: 20),

        if (sub.plan != SubscriptionPlan.trial &&
            sub.status == SubscriptionStatus.active)
          _CancelSection(ref: ref),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Billing Summary Card ──────────────────────────────────────────────────────

class _BillingSummaryCard extends StatelessWidget {
  final Subscription sub;
  final BillingInfo  billing;

  const _BillingSummaryCard({required this.sub, required this.billing});

  @override
  Widget build(BuildContext context) {
    final planColor = _planColor(sub.plan);
    final nextDate  = billing.nextPaymentDate;
    final nextAmt   = billing.nextPaymentAmount;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_rounded, color: planColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Billing Summary',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(sub.plan.displayName,
                        style: TextStyle(color: planColor, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          if (nextDate != null || nextAmt != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
          ],

          if (nextAmt != null)
            _InfoRow(
              icon: Icons.attach_money_rounded,
              label: 'Next payment',
              value: '\$${nextAmt.toStringAsFixed(2)}',
              valueColor: planColor,
            ),

          if (nextDate != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Due date',
              value: DateFormat('MMMM d, yyyy').format(nextDate),
            ),
          ],

          const SizedBox(height: 4),
          _InfoRow(
            icon: Icons.refresh_rounded,
            label: 'Billing cycle',
            value: sub.billingCycle.displayName,
          ),
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: 'Status',
            value: _statusLabel(sub.status),
            valueColor: _statusColor(sub.status),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(SubscriptionStatus s) => switch (s) {
        SubscriptionStatus.active    => 'Active',
        SubscriptionStatus.trial     => 'Free Trial',
        SubscriptionStatus.expiring  => 'Trial Expiring',
        SubscriptionStatus.expired   => 'Expired',
        SubscriptionStatus.suspended => 'Suspended',
        SubscriptionStatus.cancelled => 'Cancelled',
      };

  static Color _statusColor(SubscriptionStatus s) => switch (s) {
        SubscriptionStatus.active    => EnhancedTheme.successGreen,
        SubscriptionStatus.trial     => EnhancedTheme.accentOrange,
        SubscriptionStatus.expiring  => EnhancedTheme.warningAmber,
        SubscriptionStatus.expired   => EnhancedTheme.errorRed,
        SubscriptionStatus.suspended => EnhancedTheme.errorRed,
        SubscriptionStatus.cancelled => Colors.black38,
      };
}

// ── Payment Method Card ───────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final BillingInfo billing;
  final WidgetRef   ref;

  const _PaymentMethodCard({required this.billing, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pm = billing.paymentMethod;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.infoBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: EnhancedTheme.infoBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Payment Method',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => _showCardForm(context, ref, pm),
                style: TextButton.styleFrom(
                  backgroundColor: EnhancedTheme.infoBlue.withValues(alpha: 0.10),
                  foregroundColor: EnhancedTheme.infoBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  pm != null ? 'Update' : 'Add Card',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (pm != null)
            _CardVisual(pm: pm)
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showCardForm(context, ref, null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.infoBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: EnhancedTheme.infoBlue.withValues(alpha: 0.25),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_card_rounded,
                              color: EnhancedTheme.infoBlue, size: 18),
                          const SizedBox(width: 8),
                          const Text('Add a payment card',
                              style: TextStyle(
                                  color: EnhancedTheme.infoBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your card details are stored securely',
                      style: TextStyle(color: Colors.black38, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showCardForm(BuildContext context, WidgetRef ref, PaymentMethod? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardFormSheet(existing: existing, ref: ref),
    );
  }
}

class _CardVisual extends StatelessWidget {
  final PaymentMethod pm;
  const _CardVisual({required this.pm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1F3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EnhancedTheme.infoBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BrandLogo(brand: pm.brand),
              const Spacer(),
              Text(pm.brand.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '**** **** **** ${pm.last4}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                letterSpacing: 3,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EXPIRES',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(pm.expiry,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('CVV',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          letterSpacing: 1)),
                  SizedBox(height: 2),
                  Text('•••',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card Form Sheet ───────────────────────────────────────────────────────────

class _CardFormSheet extends StatefulWidget {
  final PaymentMethod? existing;
  final WidgetRef      ref;

  const _CardFormSheet({required this.existing, required this.ref});

  @override
  State<_CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends State<_CardFormSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl    = TextEditingController();

  bool _saving  = false;
  bool _cvvFocus = false;

  String get _brand {
    final digits = _numberCtrl.text.replaceAll(' ', '');
    if (digits.startsWith('4'))                        return 'Visa';
    if (digits.startsWith('5') || digits.startsWith('2')) return 'Mastercard';
    if (digits.startsWith('3'))                        return 'Amex';
    if (digits.startsWith('6'))                        return 'Discover';
    return 'Card';
  }

  String get _last4 {
    final digits = _numberCtrl.text.replaceAll(' ', '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : '****';
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2744),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.infoBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.credit_card_rounded,
                        color: EnhancedTheme.infoBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.existing != null
                        ? 'Update Payment Card'
                        : 'Add Payment Card',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Live card preview ─────────────────────────────────────────
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_numberCtrl, _nameCtrl, _expiryCtrl]),
                builder: (_, __) => _LiveCardPreview(
                  brand:   _brand,
                  number:  _numberCtrl.text.isEmpty
                      ? '**** **** **** ****'
                      : _numberCtrl.text.padRight(19, '*').substring(0, 19),
                  name:    _nameCtrl.text.isEmpty
                      ? 'CARDHOLDER NAME'
                      : _nameCtrl.text.toUpperCase(),
                  expiry:  _expiryCtrl.text.isEmpty ? 'MM/YY' : _expiryCtrl.text,
                  showCvv: _cvvFocus,
                ),
              ),

              const SizedBox(height: 20),

              // ── Card number ───────────────────────────────────────────────
              _CardField(
                label:    'Card Number',
                hint:     '1234 5678 9012 3456',
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 19,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(' ', '');
                  if (digits.length < 13) return 'Enter a valid card number';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ── Cardholder name ───────────────────────────────────────────
              _CardField(
                label:      'Cardholder Name',
                hint:       'As it appears on card',
                controller: _nameCtrl,
                keyboardType: TextInputType.name,
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                validator: (v) =>
                    (v == null || v.trim().length < 2)
                        ? 'Enter the cardholder name'
                        : null,
              ),

              const SizedBox(height: 14),

              // ── Expiry + CVV ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CardField(
                      label:    'Expiry',
                      hint:     'MM/YY',
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpiryFormatter(),
                      ],
                      validator: (v) {
                        if (v == null || !RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) {
                          return 'MM/YY';
                        }
                        final parts = v.split('/');
                        final month = int.tryParse(parts[0]) ?? 0;
                        if (month < 1 || month > 12) return 'Invalid month';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Focus(
                      onFocusChange: (f) => setState(() => _cvvFocus = f),
                      child: _CardField(
                        label:    'CVV',
                        hint:     '•••',
                        controller: _cvvCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        obscure: true,
                        validator: (v) =>
                            ((v ?? '').length < 3) ? 'Invalid CVV' : null,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Security note
              Row(
                children: const [
                  Icon(Icons.lock_rounded, color: Colors.white38, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Your card details are encrypted and stored securely.',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Save button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        EnhancedTheme.primaryTeal.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.existing != null
                              ? 'Update Card'
                              : 'Save Card',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    // Simulate network call; in prod send tokenised card to backend.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.existing != null
              ? 'Payment card updated successfully.'
              : 'Card ending in $_last4 added successfully.',
        ),
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Live Card Preview ─────────────────────────────────────────────────────────

class _LiveCardPreview extends StatelessWidget {
  final String brand;
  final String number;
  final String name;
  final String expiry;
  final bool   showCvv;

  const _LiveCardPreview({
    required this.brand,
    required this.number,
    required this.name,
    required this.expiry,
    required this.showCvv,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 170,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: showCvv
              ? [const Color(0xFF2D1B69), const Color(0xFF11093C)]
              : [const Color(0xFF1E3A5F), const Color(0xFF0D1F3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (showCvv
              ? EnhancedTheme.accentPurple
              : EnhancedTheme.infoBlue).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: (showCvv
                ? EnhancedTheme.accentPurple
                : EnhancedTheme.infoBlue).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: showCvv
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security_rounded,
                        color: Colors.white38, size: 28),
                    const SizedBox(height: 8),
                    const Text('CVV',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            letterSpacing: 2)),
                    const SizedBox(height: 4),
                    const Text('•••',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BrandLogo(brand: brand),
                      const Spacer(),
                      Text(
                        brand.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CARDHOLDER',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 8,
                                    letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('EXPIRES',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 8,
                                  letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text(expiry,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Card form field ───────────────────────────────────────────────────────────

class _CardField extends StatelessWidget {
  final String                       label;
  final String                       hint;
  final TextEditingController        controller;
  final TextInputType                keyboardType;
  final int?                         maxLength;
  final List<TextInputFormatter>     formatters;
  final bool                         obscure;
  final String? Function(String?)?   validator;
  final ValueChanged<String>?        onChanged;

  const _CardField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    this.maxLength,
    this.formatters = const [],
    this.obscure = false,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:        controller,
          keyboardType:      keyboardType,
          obscureText:       obscure,
          maxLength:         maxLength,
          inputFormatters:   formatters,
          validator:         validator,
          onChanged:         onChanged,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText:        hint,
            hintStyle:       const TextStyle(color: Colors.white24, fontSize: 13),
            counterText:     '',
            filled:          true,
            fillColor:       Colors.white.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: EnhancedTheme.errorRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: EnhancedTheme.errorRed, width: 1.5),
            ),
            errorStyle: const TextStyle(
                color: EnhancedTheme.errorRed, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

// ── Text Formatters ───────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue _, TextEditingValue newVal) {
    final digits = newVal.text.replaceAll(' ', '');
    final buf    = StringBuffer();
    for (var i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return newVal.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) {
    final digits = newVal.text.replaceAll('/', '');
    if (digits.isEmpty) {
      return newVal.copyWith(text: '');
    }
    if (digits.length <= 2) {
      return newVal.copyWith(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length));
    }
    final clamped = digits.substring(0, digits.length.clamp(0, 4));
    final text    = '${clamped.substring(0, 2)}/${clamped.substring(2)}';
    return newVal.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length));
  }
}

// ── Brand Logo ────────────────────────────────────────────────────────────────

class _BrandLogo extends StatelessWidget {
  final String brand;
  const _BrandLogo({required this.brand});

  @override
  Widget build(BuildContext context) {
    final color = switch (brand.toLowerCase()) {
      'visa'       => const Color(0xFF1A73E8),
      'mastercard' => const Color(0xFFEB5E28),
      'amex'       => const Color(0xFF007BC1),
      'discover'   => const Color(0xFFF76F20),
      _            => Colors.white54,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        brand == 'Card' ? 'CARD' : brand.toUpperCase(),
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1),
      ),
    );
  }
}

// ── Plans Section ─────────────────────────────────────────────────────────────

class _PlansSection extends ConsumerWidget {
  final Subscription currentSub;
  final WidgetRef    ref;

  const _PlansSection({required this.currentSub, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycle = ref.watch(_billingCycleProvider);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: EnhancedTheme.accentPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Available Plans',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              _CycleToggle(cycle: cycle, ref: ref),
            ],
          ),

          const SizedBox(height: 14),

          // Plan rows
          ...SubscriptionPlan.values.map(
            (plan) => _PlanRow(
              plan:      plan,
              cycle:     cycle,
              isCurrent: currentSub.plan == plan,
              ref:       ref,
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleToggle extends StatelessWidget {
  final BillingCycle cycle;
  final WidgetRef    ref;
  const _CycleToggle({required this.cycle, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CycleChip(
            label:      'Monthly',
            isSelected: cycle == BillingCycle.monthly,
            onTap:      () => ref.read(_billingCycleProvider.notifier).state =
                BillingCycle.monthly,
          ),
          _CycleChip(
            label:      'Annual',
            isSelected: cycle == BillingCycle.annual,
            onTap:      () => ref.read(_billingCycleProvider.notifier).state =
                BillingCycle.annual,
            badge:      'Save 20%',
          ),
        ],
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  final String       label;
  final bool         isSelected;
  final VoidCallback onTap;
  final String?      badge;
  const _CycleChip(
      {required this.label,
      required this.isSelected,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? EnhancedTheme.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500)),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : EnhancedTheme.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : EnhancedTheme.successGreen,
                        fontSize: 8,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;
  final BillingCycle     cycle;
  final bool             isCurrent;
  final WidgetRef        ref;

  const _PlanRow({
    required this.plan,
    required this.cycle,
    required this.isCurrent,
    required this.ref,
  });

  @override
  ConsumerState<_PlanRow> createState() => _PlanRowState();
}

class _PlanRowState extends ConsumerState<_PlanRow> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final planColor = _planColor(widget.plan);
    final isAnnual  = widget.cycle == BillingCycle.annual;
    final savings   = widget.plan.annualSavings;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isCurrent
              ? planColor.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isCurrent
                ? planColor.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.08),
            width: widget.isCurrent ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Plan icon
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: planColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_planIcon(widget.plan),
                  color: planColor, size: 16),
            ),
            const SizedBox(width: 10),

            // Plan name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.plan.displayName,
                          style: TextStyle(
                              color: planColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      if (widget.isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: planColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Current',
                              style: TextStyle(
                                  color: planColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.plan.priceLabel(widget.cycle),
                        style: TextStyle(
                            color: planColor.withValues(alpha: 0.75),
                            fontSize: 11),
                      ),
                      if (isAnnual && savings > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.successGreen
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Save \$${savings.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: EnhancedTheme.successGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action button
            if (!widget.isCurrent)
              _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EnhancedTheme.primaryTeal))
                  : GestureDetector(
                      onTap: () => _upgrade(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: planColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: planColor.withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          widget.plan.rank >
                                  ref.read(currentPlanProvider).rank
                              ? 'Upgrade'
                              : 'Downgrade',
                          style: TextStyle(
                              color: planColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Future<void> _upgrade(BuildContext context) async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);

    await widget.ref
        .read(subscriptionNotifierProvider.notifier)
        .upgradePlan(widget.plan.name,
            billingCycle: widget.cycle.apiValue);

    if (!mounted) return;
    setState(() => _loading = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Switched to ${widget.plan.displayName} '
          '(${widget.cycle.displayName}). Update your payment method below.',
        ),
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Invoice History ───────────────────────────────────────────────────────────

class _InvoiceHistoryCard extends StatelessWidget {
  final BillingInfo billing;
  const _InvoiceHistoryCard({required this.billing});

  @override
  Widget build(BuildContext context) {
    final invoices = billing.invoices;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded,
                    color: EnhancedTheme.accentPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Invoice History',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),

          if (invoices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Colors.black26, size: 32),
                  const SizedBox(height: 8),
                  const Text('No invoices yet',
                      style: TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
            )
          else
            ...invoices.map((inv) => _InvoiceRow(invoice: inv)),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.status) {
      InvoiceStatus.paid    => EnhancedTheme.successGreen,
      InvoiceStatus.pending => EnhancedTheme.warningAmber,
      InvoiceStatus.failed  => EnhancedTheme.errorRed,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              invoice.status == InvoiceStatus.paid
                  ? Icons.check_circle_rounded
                  : invoice.status == InvoiceStatus.pending
                      ? Icons.schedule_rounded
                      : Icons.cancel_rounded,
              color: statusColor, size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.description ??
                      DateFormat('MMMM yyyy').format(invoice.date),
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(invoice.date),
                  style: const TextStyle(color: Colors.black38, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${invoice.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(invoice.status.displayName,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (invoice.downloadUrl != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Download: ${invoice.downloadUrl}'),
                    backgroundColor: EnhancedTheme.primaryTeal,
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded,
                  color: Colors.black38, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Cancel Section ────────────────────────────────────────────────────────────

class _CancelSection extends StatelessWidget {
  final WidgetRef ref;
  const _CancelSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      borderColor: EnhancedTheme.errorRed.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danger Zone',
              style: TextStyle(
                  color: EnhancedTheme.errorRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Cancelling will downgrade your account to the free tier at '
            'the end of the current billing period.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmCancel(context),
              icon: const Icon(Icons.cancel_outlined,
                  size: 16, color: EnhancedTheme.errorRed),
              label: const Text('Cancel Subscription',
                  style: TextStyle(
                      color: EnhancedTheme.errorRed,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: EnhancedTheme.errorRed, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EnhancedTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Subscription?',
            style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        content: const Text(
          'Your plan will revert to the Free Trial at the end of the '
          'current billing period. You will not be charged again.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Plan',
                style: TextStyle(color: EnhancedTheme.primaryTeal)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: EnhancedTheme.errorRed)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref
            .read(subscriptionNotifierProvider.notifier)
            .cancelSubscription()
            .then((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Subscription cancelled. Access retained until end of billing period.'),
                backgroundColor: EnhancedTheme.warningAmber,
              ),
            );
          }
        });
      }
    });
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _GlassCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 14),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.black26, size: 48),
            const SizedBox(height: 12),
            const Text('Could not load billing info',
                style: TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: EnhancedTheme.primaryTeal)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color / icon helpers ──────────────────────────────────────────────────────

Color _planColor(SubscriptionPlan plan) => switch (plan) {
      SubscriptionPlan.trial        => EnhancedTheme.accentOrange,
      SubscriptionPlan.starter      => EnhancedTheme.infoBlue,
      SubscriptionPlan.professional => EnhancedTheme.accentPurple,
      SubscriptionPlan.enterprise   => EnhancedTheme.accentCyan,
    };

IconData _planIcon(SubscriptionPlan plan) => switch (plan) {
      SubscriptionPlan.trial        => Icons.science_rounded,
      SubscriptionPlan.starter      => Icons.rocket_launch_rounded,
      SubscriptionPlan.professional => Icons.workspace_premium_rounded,
      SubscriptionPlan.enterprise   => Icons.diamond_rounded,
    };
