import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/reports_provider.dart';
import '../providers/reports_api_client.dart';

class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  String _fmtValue(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(inventoryReportProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative orbs
        Positioned(
            top: -40,
            right: -40,
            child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        EnhancedTheme.warningAmber.withValues(alpha: 0.06)))),
        Positioned(
            bottom: 100,
            left: -60,
            child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.05)))),
        SafeArea(
            child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(AppShell.roleFallback(ref)),
                child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12))),
                    child: Icon(Icons.arrow_back_rounded,
                        color: context.labelColor, size: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Inventory Report',
                        style: GoogleFonts.outfit(
                            color: context.labelColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    Text('Stock levels & valuation',
                        style:
                            TextStyle(color: context.hintColor, fontSize: 11)),
                  ])),
              GestureDetector(
                onTap: () => ref.invalidate(inventoryReportProvider),
                child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: EnhancedTheme.accentCyan
                                .withValues(alpha: 0.25))),
                    child: const Icon(Icons.refresh_rounded,
                        color: EnhancedTheme.accentCyan, size: 18)),
              ),
            ]).animate().fadeIn(duration: 350.ms),
          ),
          const SizedBox(height: 12),

          Expanded(
              child: reportAsync.when(
            loading: () => Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const CircularProgressIndicator(
                            color: EnhancedTheme.primaryTeal, strokeWidth: 3)),
                    const SizedBox(height: 16),
                    Text('Loading inventory…',
                        style: TextStyle(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.8),
                            fontSize: 13)),
                  ]),
            ),
            error: (e, _) => Center(
                child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color:
                                EnhancedTheme.errorRed.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: EnhancedTheme.errorRed
                                    .withValues(alpha: 0.2))),
                        child: Icon(Icons.cloud_off_rounded,
                            color: context.hintColor, size: 40)),
                    const SizedBox(height: 16),
                    Text('Failed to load report',
                        style: GoogleFonts.outfit(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('$e',
                        style: TextStyle(
                            color: context.subLabelColor, fontSize: 12),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => ref.invalidate(inventoryReportProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              EnhancedTheme.primaryTeal,
                              EnhancedTheme.accentCyan
                            ]),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded,
                                  color: Colors.black, size: 16),
                              SizedBox(width: 8),
                              Text('Retry',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700)),
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

  Widget _buildBody(BuildContext context, InventoryReportData data) {
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
                    EnhancedTheme.accentCyan.withValues(alpha: 0.18),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: EnhancedTheme.accentCyan.withValues(alpha: 0.28),
                    width: 1.5),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: EnhancedTheme.accentCyan
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: EnhancedTheme.accentCyan, size: 20)),
                      const SizedBox(width: 14),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stock Valuation',
                                style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    letterSpacing: 0.4)),
                            Text(_fmtValue(data.stockValue),
                                style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800)),
                          ]),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: _kpiBadge(
                              'Total Items',
                              '${data.totalItems}',
                              Icons.inventory_2_rounded,
                              EnhancedTheme.primaryTeal)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _kpiBadge(
                              'Low Stock',
                              '${data.lowStockCount}',
                              Icons.warning_amber_rounded,
                              EnhancedTheme.warningAmber)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _kpiBadge(
                              'Healthy',
                              '${data.totalItems - data.lowStockCount}',
                              Icons.check_circle_rounded,
                              EnhancedTheme.successGreen)),
                    ]),
                  ]),
            ),
          ),
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 24),

        // ── Low stock alerts header ───────────────────────────────────────────
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded,
                  color: EnhancedTheme.warningAmber, size: 16)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Low Stock Alerts',
                  style: GoogleFonts.outfit(
                      color: context.labelColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          EnhancedTheme.warningAmber.withValues(alpha: 0.3))),
              child: Text('${data.lowStockItems.length} items',
                  style: const TextStyle(
                      color: EnhancedTheme.warningAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
        ]).animate().fadeIn(duration: 350.ms, delay: 100.ms),
        const SizedBox(height: 12),

        if (data.lowStockItems.isEmpty)
          _emptyState(Icons.check_circle_rounded,
              'All items adequately stocked', EnhancedTheme.successGreen)
        else
          ...data.lowStockItems
              .asMap()
              .entries
              .map((e) => _lowStockRow(context, e.value, e.key)),
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
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.black54, fontSize: 9),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _lowStockRow(BuildContext context, LowStockItem item, int index) {
    final pct =
        item.lowStockThreshold > 0 ? item.stock / item.lowStockThreshold : 0.0;
    final c = pct < 0.3 ? EnhancedTheme.errorRed : EnhancedTheme.warningAmber;
    final label = pct < 0.3 ? 'Critical' : 'Low';
    final labelBg = pct < 0.3
        ? EnhancedTheme.errorRed.withValues(alpha: 0.15)
        : EnhancedTheme.warningAmber.withValues(alpha: 0.15);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.withValues(alpha: 0.10), c.withValues(alpha: 0.04)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withValues(alpha: 0.25))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.warning_amber_rounded, color: c, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(c),
                          minHeight: 6)),
                  const SizedBox(height: 4),
                  Text('Threshold: ${item.lowStockThreshold} units',
                      style: TextStyle(color: context.hintColor, fontSize: 10)),
                ])),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${item.stock}',
                  style: TextStyle(
                      color: c, fontSize: 18, fontWeight: FontWeight.w800)),
              const Text('in stock',
                  style: TextStyle(color: Colors.black38, fontSize: 9)),
              const SizedBox(height: 5),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: labelBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.withValues(alpha: 0.3))),
                  child: Text(label,
                      style: TextStyle(
                          color: c, fontSize: 9, fontWeight: FontWeight.w800))),
            ]),
          ]),
        ),
      ),
    )
        .animate()
        .fadeIn(
            duration: 350.ms, delay: Duration(milliseconds: 150 + index * 40))
        .slideX(begin: 0.05, end: 0);
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
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 36)),
            const SizedBox(height: 14),
            Text(message,
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Your inventory levels look great!',
                style: const TextStyle(color: Colors.black38, fontSize: 12),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }
}
