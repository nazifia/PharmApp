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

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  String _period = 'Today';
  final _periods = ['Today', 'This Week', 'This Month', 'This Year'];
  DateTimeRange? _customRange;

  // -- Computed period key -----------------------------------------------------

  String get _apiPeriod {
    if (_customRange != null) {
      final from = _customRange!.start.toIso8601String().split('T').first;
      final to   = _customRange!.end.toIso8601String().split('T').first;
      return 'custom:$from:$to';
    }
    switch (_period) {
      case 'This Week':  return 'week';
      case 'This Month': return 'month';
      case 'This Year':  return 'year';
      default:           return 'today';
    }
  }

  // -- Helpers -----------------------------------------------------------------

  String _fmt(double v) {
    if (v >= 10000000) return '₦${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '₦${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}';
  }

  // -- Date range picker -------------------------------------------------------

  Future<void> _openDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: EnhancedTheme.primaryTeal,
            onPrimary: Colors.black,
            secondary: EnhancedTheme.accentCyan,
            surface: const Color(0xFF0F172A),
            onSurface: Colors.black,
            onSurfaceVariant: const Color(0xFF94A3B8),
            outline: Colors.white.withValues(alpha: 0.08),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            surfaceTintColor: Colors.transparent,
            rangePickerBackgroundColor: const Color(0xFF0F172A),
            rangePickerHeaderBackgroundColor: EnhancedTheme.primaryTeal,
            rangePickerHeaderForegroundColor: Colors.black,
            rangePickerHeaderHeadlineStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            weekdayStyle: const TextStyle(color: EnhancedTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 11),
            dayStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            dayForegroundColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.selected)) return Colors.black;
              if (s.contains(WidgetState.disabled)) return const Color(0xFF475569);
              return Colors.black;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.selected)) return EnhancedTheme.primaryTeal;
              return Colors.transparent;
            }),
            dayOverlayColor: WidgetStatePropertyAll(EnhancedTheme.primaryTeal.withValues(alpha: 0.12)),
            todayForegroundColor: const WidgetStatePropertyAll(EnhancedTheme.accentCyan),
            todayBackgroundColor: WidgetStatePropertyAll(EnhancedTheme.accentCyan.withValues(alpha: 0.12)),
            todayBorder: const BorderSide(color: EnhancedTheme.accentCyan, width: 1.5),
            rangeSelectionBackgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
            rangeSelectionOverlayColor: WidgetStatePropertyAll(EnhancedTheme.primaryTeal.withValues(alpha: 0.10)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: EnhancedTheme.primaryTeal,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
            ),
          ),
          dividerColor: Colors.white.withValues(alpha: 0.06),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _customRange = picked);
    }
  }

  // -- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(salesReportProvider(_apiPeriod));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        Positioned(top: -50, right: -50,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.07)))),
        Positioned(bottom: 80, left: -60,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.05)))),
        SafeArea(child: Column(children: [
          _header(context),
          const SizedBox(height: 8),
          _periodSelector(),
          _customRangeBanner(),
          const SizedBox(height: 4),
          Expanded(child: reportAsync.when(
            loading: () => _loadingState(),
            error: (e, _) => _errorState(e),
            data: (data) => _buildBody(context, data),
          )),
        ])),
      ]),
    );
  }

  // -- Header ------------------------------------------------------------------

  Widget _header(BuildContext context) => Padding(
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
          child: Icon(Icons.arrow_back_rounded, color: context.labelColor, size: 20)),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sales Report', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('Revenue & transaction analytics',
            style: TextStyle(color: context.hintColor, fontSize: 11)),
      ])),
      // -- Date range picker button
      GestureDetector(
        onTap: _openDatePicker,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _customRange != null
                ? EnhancedTheme.primaryTeal.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _customRange != null
                  ? EnhancedTheme.primaryTeal.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12))),
          child: Icon(Icons.date_range_rounded,
              color: _customRange != null ? EnhancedTheme.primaryTeal : context.labelColor,
              size: 18)),
      ),
      const SizedBox(width: 8),
      Builder(builder: (ctx) {
        final hasExport = ref.watch(hasFeatureProvider(SaasFeature.exportData));
        return GestureDetector(
          onTap: () {
            if (!hasExport) { ctx.go('/subscription'); return; }
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Export coming soon')));
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
    ]),
  ).animate().fadeIn(duration: 350.ms);

  // -- Period chips ------------------------------------------------------------

  Widget _periodSelector() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor)),
          child: Row(children: _periods.map((p) {
            final active = _customRange == null && p == _period;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() {
                _period = p;
                _customRange = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.9),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.8),
                  ]) : null,
                  color: active ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(p, textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active ? Colors.black : Colors.black54,
                        fontSize: 11, fontWeight: FontWeight.w700))),
            ));
          }).toList()),
        ),
      ),
    ),
  ).animate().fadeIn(duration: 350.ms, delay: 80.ms);

  // -- Custom range banner (shown when a date range is active) -----------------

  Widget _customRangeBanner() {
    if (_customRange == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: _openDatePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
              EnhancedTheme.accentCyan.withValues(alpha: 0.08),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded, color: EnhancedTheme.primaryTeal, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${_fmtDate(_customRange!.start)} � ${_fmtDate(_customRange!.end)}',
              style: const TextStyle(
                  color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w700),
            )),
            const Text('Change', style: TextStyle(color: EnhancedTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _customRange = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close_rounded, color: EnhancedTheme.primaryTeal, size: 13),
              ),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.15, end: 0);
  }

  // -- States ------------------------------------------------------------------

  Widget _loadingState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle),
          child: const CircularProgressIndicator(
            color: EnhancedTheme.primaryTeal, strokeWidth: 3)),
        const SizedBox(height: 16),
        Text('Loading report�',
            style: TextStyle(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.8), fontSize: 13)),
      ]),
    );
  }

  Widget _errorState(Object e) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2))),
          child: Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed.withValues(alpha: 0.6), size: 40)),
        const SizedBox(height: 16),
        Text('Failed to load report', style: GoogleFonts.outfit(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('$e', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => ref.invalidate(salesReportProvider(_apiPeriod)),
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
    ));
  }

  // -- Body --------------------------------------------------------------------

  Widget _buildBody(BuildContext context, SalesReportData data) {
    final grand = data.totalRevenue;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // -- KPI Hero Banner ---------------------------------------------------
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
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.22),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.trending_up_rounded, color: EnhancedTheme.primaryTeal, size: 20)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Revenue', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, letterSpacing: 0.4)),
                    Text(_fmt(grand), style: GoogleFonts.outfit(
                      color: Colors.black, fontSize: 32, fontWeight: FontWeight.w800)),
                  ]),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _kpiBadge('Transactions', '${data.totalSales}', Icons.receipt_long_rounded, EnhancedTheme.accentCyan)),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBadge('Retail', _fmt(data.totalRetail), Icons.storefront_rounded, EnhancedTheme.successGreen)),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBadge('Wholesale', _fmt(data.totalWholesale), Icons.store_rounded, EnhancedTheme.accentPurple)),
                ]),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 22),

        // -- Sales Breakdown ---------------------------------------------------
        _sectionHeader(context, 'Sales Breakdown', Icons.pie_chart_rounded, EnhancedTheme.accentCyan),
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
              child: grand <= 0
                  ? _emptyInCard('No sales data for this period')
                  : Column(children: [
                      _breakdownRow('Retail Sales', data.totalRetail, grand, EnhancedTheme.accentCyan, Icons.storefront_rounded),
                      const SizedBox(height: 16),
                      _breakdownRow('Wholesale Sales', data.totalWholesale, grand, EnhancedTheme.accentPurple, Icons.store_rounded),
                    ]),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 22),

        // -- Top Selling Items -------------------------------------------------
        _sectionHeader(context, 'Top Selling Items', Icons.emoji_events_rounded, EnhancedTheme.warningAmber),
        const SizedBox(height: 12),
        if (data.topItems.isEmpty)
          _emptyState(Icons.inventory_2_rounded, 'No items sold in this period', EnhancedTheme.primaryTeal)
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
                  children: data.topItems.asMap().entries.map((e) {
                    final rankColors = [
                      const Color(0xFFFFD700),
                      const Color(0xFFC0C0C0),
                      const Color(0xFFCD7F32),
                    ];
                    final rankColor = e.key < 3 ? rankColors[e.key] : EnhancedTheme.primaryTeal.withValues(alpha: 0.6);
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: rankColor.withValues(alpha: 0.35))),
                            child: Center(child: Text('${e.key + 1}',
                                style: TextStyle(color: rankColor, fontSize: 12, fontWeight: FontWeight.w800)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.value.name,
                                style: GoogleFonts.outfit(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EnhancedTheme.infoBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4)),
                                child: Text('${e.value.qty} units',
                                    style: const TextStyle(color: EnhancedTheme.infoBlue, fontSize: 9, fontWeight: FontWeight.w600))),
                            ]),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_fmt(e.value.revenue),
                                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.w800)),
                            if (e.key == 0)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4)),
                                child: const Text('Top seller',
                                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.w700))),
                          ]),
                        ]),
                      ),
                      if (e.key < data.topItems.length - 1)
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

  // -- Small widgets ------------------------------------------------------------

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
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _breakdownRow(String label, double value, double total, Color color, IconData icon) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: GoogleFonts.inter(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
          child: Text('${(pct * 100).round()}%',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        Text(_fmt(value),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
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

  Widget _emptyInCard(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(message,
          style: TextStyle(color: context.subLabelColor, fontSize: 13))),
    );
  }

  Widget _emptyState(IconData icon, String message, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.15))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32)),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
