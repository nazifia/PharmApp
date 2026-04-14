import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/subscription/providers/subscription_provider.dart';
import 'package:pharmapp/shared/models/subscription.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';
import '../shared/report_exporter.dart';

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
        // Decorative orbs
        Positioned(top: -50, right: -40,
          child: Container(width: 170, height: 170,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.07)))),
        Positioned(bottom: 80, left: -50,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.05)))),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                  child: Icon(Icons.arrow_back_rounded, color: context.iconOnBg, size: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Customer Report',
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Customer analytics & debt tracking',
                    style: TextStyle(color: context.hintColor, fontSize: 11)),
              ])),
              GestureDetector(
                onTap: () => ref.invalidate(customerReportProvider),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EnhancedTheme.accentPurple.withValues(alpha: 0.25))),
                  child: Icon(Icons.refresh_rounded, color: context.iconOnBg.withValues(alpha: 0.8), size: 18)),
              ),
              const SizedBox(width: 8),
              Builder(builder: (ctx) {
                final hasExport = ref.watch(hasFeatureProvider(SaasFeature.exportData));
                final data = reportAsync.valueOrNull;
                return GestureDetector(
                  onTap: () async {
                    if (!hasExport) { ctx.go('/subscription'); return; }
                    if (data == null) return;
                    await ReportExporter.exportCustomerReport(data);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: hasExport
                          ? EnhancedTheme.primaryTeal.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasExport
                            ? EnhancedTheme.primaryTeal.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.12))),
                    child: Icon(
                      hasExport ? Icons.download_rounded : Icons.lock_rounded,
                      color: hasExport ? EnhancedTheme.primaryTeal : Colors.white38,
                      size: 18)),
                );
              }),
            ]).animate().fadeIn(duration: 350.ms),
          ),
          const SizedBox(height: 12),

          Expanded(child: reportAsync.when(
            loading: () => Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 3)),
                const SizedBox(height: 16),
                Text('Loading customers…', style: TextStyle(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.8), fontSize: 13)),
              ]),
            ),
            error: (e, _) => Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2))),
                  child: Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 40)),
                const SizedBox(height: 16),
                Text('Failed to load report',
                    style: GoogleFonts.outfit(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => ref.invalidate(customerReportProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded, color: Colors.black, size: 16),
                      SizedBox(width: 8),
                      Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            )),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, CustomerReportData data) {
    final total = data.total > 0 ? data.total : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── KPI Hero Banner ───────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    EnhancedTheme.accentPurple.withValues(alpha: 0.20),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: EnhancedTheme.accentPurple.withValues(alpha: 0.28), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.accentPurple.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.people_rounded, color: EnhancedTheme.accentPurple, size: 22)),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Customers', style: TextStyle(color: Colors.black54, fontSize: 12, letterSpacing: 0.4)),
                    Text('${data.total}', style: GoogleFonts.outfit(
                      color: Colors.black, fontSize: 36, fontWeight: FontWeight.w800)),
                  ]),
                  const Spacer(),
                  // Debt badge
                  if (data.totalDebt > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.3))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        const Icon(Icons.money_off_rounded, color: EnhancedTheme.errorRed, size: 16),
                        const SizedBox(height: 2),
                        Text(_fmt(data.totalDebt),
                            style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 12, fontWeight: FontWeight.w800)),
                        const Text('Outstanding', style: TextStyle(color: Colors.black38, fontSize: 9)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _kpiBadge('Retail', '${data.retail}', Icons.storefront_rounded, EnhancedTheme.successGreen)),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBadge('Wholesale', '${data.wholesale}', Icons.store_rounded, EnhancedTheme.accentCyan)),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBadge('Debt', _fmt(data.totalDebt), Icons.money_off_rounded, EnhancedTheme.errorRed)),
                ]),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 24),

        // ── Customer Segments ─────────────────────────────────────────────────
        _sectionHeader(context, 'Customer Segments', Icons.donut_large_rounded, EnhancedTheme.accentPurple),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor)),
              child: Column(children: [
                _segBar(context, 'Retail Customers', data.retail, total, EnhancedTheme.primaryTeal, Icons.storefront_rounded),
                const SizedBox(height: 16),
                _segBar(context, 'Wholesale Customers', data.wholesale, total, EnhancedTheme.accentCyan, Icons.store_rounded),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 24),

        // ── Top Customers ─────────────────────────────────────────────────────
        _sectionHeader(context, 'Top Customers by Spend', Icons.emoji_events_rounded, EnhancedTheme.warningAmber),
        const SizedBox(height: 12),
        if (data.topCustomers.isEmpty)
          _emptyState(Icons.people_rounded, 'No customer data available', EnhancedTheme.accentPurple)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor)),
                child: Column(
                  children: data.topCustomers.asMap().entries.map((e) {
                    final rankColors = [
                      const Color(0xFFFFD700),
                      const Color(0xFFC0C0C0),
                      const Color(0xFFCD7F32),
                    ];
                    final rankColor = e.key < 3 ? rankColors[e.key] : EnhancedTheme.primaryTeal.withValues(alpha: 0.6);
                    final avatarLetter = e.value.name.isNotEmpty ? e.value.name[0].toUpperCase() : '?';

                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          // Rank + Avatar
                          Stack(clipBehavior: Clip.none, children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                              child: Text(avatarLetter,
                                  style: GoogleFonts.outfit(color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w700))),
                            Positioned(
                              bottom: -2, right: -4,
                              child: Container(
                                width: 18, height: 18,
                                decoration: BoxDecoration(
                                  color: rankColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: rankColor.withValues(alpha: 0.5), width: 1)),
                                child: Center(child: Text('${e.key + 1}',
                                    style: TextStyle(color: rankColor, fontSize: 8, fontWeight: FontWeight.w900))),
                              ),
                            ),
                          ]),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.value.name,
                                style: GoogleFonts.outfit(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
                            if (e.key == 0)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4)),
                                child: const Text('Top spender',
                                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.w700))),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_fmt(e.value.spent),
                                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w800)),
                            Text('total spend',
                                style: TextStyle(color: context.hintColor, fontSize: 9)),
                          ]),
                        ]),
                      ),
                      if (e.key < data.topCustomers.length - 1)
                        Divider(height: 1, color: context.dividerColor),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _kpiBadge(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.black45, fontSize: 9),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _segBar(BuildContext context, String label, int count, int total, Color color, IconData icon) {
    final pct = count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 13)),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: GoogleFonts.inter(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
          child: Text('$count (${(pct * 100).round()}%)',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          backgroundColor: context.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 10)),
    ]);
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _emptyState(IconData icon, String message, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.15))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 36)),
            const SizedBox(height: 14),
            Text(message, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }
}
