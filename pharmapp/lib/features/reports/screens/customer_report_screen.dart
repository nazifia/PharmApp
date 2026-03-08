import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';

class CustomerReportScreen extends ConsumerWidget {
  const CustomerReportScreen({super.key});

  String _fmt(double v) {
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₦${(v / 1000).toStringAsFixed(0)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(customerReportProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.iconOnBg),
                  onPressed: () => context.pop()),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Customer Report',
                    style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Customer analytics & debt tracking',
                    style: TextStyle(color: context.hintColor, fontSize: 11)),
              ])),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: context.iconOnBg.withValues(alpha: 0.7)),
                onPressed: () => ref.invalidate(customerReportProvider)),
            ]),
          ),

          Expanded(child: reportAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('$e',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(customerReportProvider),
                child: const Text('Retry',
                    style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ])),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, CustomerReportData data) {
    final metrics = [
      {'label': 'Total Customers', 'value': '${data.total}',          'color': EnhancedTheme.primaryTeal,  'icon': Icons.people_rounded},
      {'label': 'Retail',          'value': '${data.retail}',         'color': EnhancedTheme.successGreen, 'icon': Icons.storefront_rounded},
      {'label': 'Wholesale',       'value': '${data.wholesale}',      'color': EnhancedTheme.accentCyan,   'icon': Icons.store_rounded},
      {'label': 'Outstanding',     'value': _fmt(data.totalDebt),     'color': EnhancedTheme.errorRed,     'icon': Icons.money_off_rounded},
      {'label': 'Wallet Balance',  'value': _fmt(data.totalWallet),   'color': EnhancedTheme.accentPurple, 'icon': Icons.account_balance_wallet_rounded},
      {'label': 'Top Customers',   'value': '${data.topCustomers.length}','color': EnhancedTheme.accentOrange, 'icon': Icons.star_rounded},
    ];

    final debtors = data.topCustomers.where((c) => c.debt > 0).toList();
    final total   = data.total > 0 ? data.total : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Metrics grid ──────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10,
              crossAxisSpacing: 10, childAspectRatio: 1.3),
          itemCount: metrics.length,
          itemBuilder: (_, i) {
            final m     = metrics[i];
            final color = m['color'] as Color;
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.25))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(m['icon'] as IconData, color: color, size: 18),
                    const SizedBox(height: 4),
                    Text(m['value'] as String,
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(m['label'] as String,
                        style: TextStyle(
                            color: context.subLabelColor, fontSize: 9),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Segments ─────────────────────────────────────────────────────────
        Text('Customer Segments',
            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor)),
              child: Row(children: [
                Expanded(child: _segBar(context,
                    'Retail', data.retail, total, EnhancedTheme.primaryTeal)),
                const SizedBox(width: 10),
                Expanded(child: _segBar(context,
                    'Wholesale', data.wholesale, total, EnhancedTheme.accentCyan)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Top customers ─────────────────────────────────────────────────────
        Text('Top Customers by Spend',
            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (data.topCustomers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No data',
                style: TextStyle(color: context.hintColor)))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor)),
                child: Column(
                  children: data.topCustomers.asMap().entries.map((e) {
                    final isWholesale = e.value.debt > 0;
                    final accentColor = isWholesale
                        ? EnhancedTheme.accentCyan
                        : EnhancedTheme.primaryTeal;
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: accentColor.withValues(alpha: 0.15),
                            child: Text('${e.key + 1}',
                                style: TextStyle(color: accentColor,
                                    fontSize: 12, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.value.name,
                                style: TextStyle(color: context.labelColor,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${e.value.purchases} purchases',
                                style: TextStyle(
                                    color: context.hintColor,
                                    fontSize: 11)),
                          ])),
                          Text(_fmt(e.value.spent),
                              style: const TextStyle(color: EnhancedTheme.primaryTeal,
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      if (e.key < data.topCustomers.length - 1)
                        Divider(height: 1, color: context.dividerColor),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── Outstanding debts ─────────────────────────────────────────────────
        if (debtors.isNotEmpty) ...[
          Row(children: [
            const Expanded(child: Text('Outstanding Debts',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: Text(_fmt(data.totalDebt),
                  style: const TextStyle(color: EnhancedTheme.errorRed,
                      fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          ...debtors.map((c) => _debtRow(context, c)),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _segBar(BuildContext context, String label, int count, int total, Color color) {
    final pct = count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(color: context.labelColor,
                fontSize: 12, fontWeight: FontWeight.w500))),
        Text('$count (${(pct * 100).round()}%)',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          backgroundColor: context.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8),
      ),
    ]);
  }

  Widget _debtRow(BuildContext context, TopCustomer c) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2))),
        child: Row(children: [
          const Icon(Icons.money_off_rounded, color: EnhancedTheme.errorRed, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(c.name,
              style: const TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w600))),
          Text(_fmt(c.debt),
              style: const TextStyle(color: EnhancedTheme.errorRed,
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}
