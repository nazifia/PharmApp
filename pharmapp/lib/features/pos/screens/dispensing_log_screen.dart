import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/pos_api_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final dispensingStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchDispensingStats();
});

final dispensingLogProvider = FutureProvider.autoDispose.family<List<dynamic>, DispensingLogParams>((ref, params) {
  return ref.watch(posApiProvider).fetchDispensingLog(
    search: params.search,
    from: params.from,
    to: params.to,
  );
});

class DispensingLogParams {
  final String? search;
  final String? from;
  final String? to;
  const DispensingLogParams({this.search, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is DispensingLogParams &&
      other.search == search && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(search, from, to);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class DispensingLogScreen extends ConsumerStatefulWidget {
  const DispensingLogScreen({super.key});

  @override
  ConsumerState<DispensingLogScreen> createState() => _DispensingLogScreenState();
}

class _DispensingLogScreenState extends ConsumerState<DispensingLogScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _dateFilter = 0; // 0=Today, 1=Week, 2=Month, 3=All
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          // ── Base colour roles ──────────────────────────────────────────────
          colorScheme: ColorScheme.dark(
            primary:           EnhancedTheme.primaryTeal,   // selected-date circles
            onPrimary: Colors.black,
            secondary:         EnhancedTheme.accentCyan,    // accent
            onSecondary: Colors.black,
            surface:           const Color(0xFF0F172A),     // dialog bg
            onSurface: Colors.black,
            onSurfaceVariant:  const Color(0xFF94A3B8),     // dim text
            outline:           Colors.white.withValues(alpha: 0.08),
          ),
          // ── Fine-grained picker styling ───────────────────────────────────
          datePickerTheme: DatePickerThemeData(
            // Dialog / sheet
            backgroundColor:          const Color(0xFF0F172A),
            elevation:                0,
            shape:                    RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24)),
            surfaceTintColor:         Colors.transparent,
            // Full-screen range picker
            rangePickerBackgroundColor:          const Color(0xFF0F172A),
            rangePickerElevation:                0,
            rangePickerSurfaceTintColor:         Colors.transparent,
            rangePickerHeaderBackgroundColor:    EnhancedTheme.primaryTeal,
            rangePickerHeaderForegroundColor: Colors.black,
            rangePickerHeaderHeadlineStyle: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black),
            rangePickerHeaderHelpStyle: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7)),
            // Weekday row  (Mon Tue Wed …)
            weekdayStyle: const TextStyle(
              color: EnhancedTheme.accentCyan,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            // Day cells
            dayStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            dayForegroundColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.selected))  return Colors.black;
              if (s.contains(WidgetState.disabled))  return const Color(0xFF475569);
              return Colors.black;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((s) {
              if (s.contains(WidgetState.selected))  return EnhancedTheme.primaryTeal;
              return Colors.transparent;
            }),
            dayOverlayColor: WidgetStatePropertyAll(
              EnhancedTheme.primaryTeal.withValues(alpha: 0.12)),
            // Today's date — cyan so it's instantly obvious
            todayForegroundColor: const WidgetStatePropertyAll(EnhancedTheme.accentCyan),
            todayBackgroundColor: WidgetStatePropertyAll(
              EnhancedTheme.accentCyan.withValues(alpha: 0.12)),
            todayBorder: const BorderSide(color: EnhancedTheme.accentCyan, width: 1.5),
            // Range strip between the two selected endpoints
            rangeSelectionBackgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
            rangeSelectionOverlayColor:    WidgetStatePropertyAll(
              EnhancedTheme.primaryTeal.withValues(alpha: 0.10)),
          ),
          // ── OK / Cancel buttons ───────────────────────────────────────────
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: EnhancedTheme.primaryTeal,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
            ),
          ),
          dividerColor: Colors.white.withValues(alpha: 0.06),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _dateFilter = 4; // activate "Custom" chip
      });
    }
  }

  DispensingLogParams get _params {
    final now = DateTime.now();
    String? from;
    String? to;
    switch (_dateFilter) {
      case 0: // Today
        from = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
        to   = now.toIso8601String().split('T').first;
        break;
      case 1: // This Week
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String().split('T').first;
        to   = now.toIso8601String().split('T').first;
        break;
      case 2: // This Month
        from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
        to   = now.toIso8601String().split('T').first;
        break;
      case 3: // All — no date filter
        break;
      case 4: // Custom date range
        if (_customRange != null) {
          from = _customRange!.start.toIso8601String().split('T').first;
          to   = _customRange!.end.toIso8601String().split('T').first;
        }
        break;
    }
    return DispensingLogParams(search: _searchQuery.isEmpty ? null : _searchQuery, from: from, to: to);
  }

  Future<void> _refresh() async {
    ref.invalidate(dispensingStatsProvider);
    ref.invalidate(dispensingLogProvider(_params));
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dispensingStatsProvider);
    final logAsync = ref.watch(dispensingLogProvider(_params));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blobs
        Positioned(top: -50, left: -50,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(bottom: 80, right: -40,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                EnhancedTheme.successGreen.withValues(alpha: 0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        SafeArea(child: Column(children: [
          _header(context),
          _statsRow(statsAsync),
          _searchBar(context),
          _dateFilterChips(),
          _customRangeBanner(),
          Expanded(child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: _logList(logAsync),
          )),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
            onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dispensing Log',
            style: TextStyle(color: context.labelColor, fontSize: 22,
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        Text('Track all dispensed medications',
            style: TextStyle(color: context.subLabelColor, fontSize: 12)),
      ])),
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
                  : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(Icons.date_range_rounded,
              color: _customRange != null ? EnhancedTheme.primaryTeal : context.labelColor,
              size: 18),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [EnhancedTheme.accentPurple, EnhancedTheme.infoBlue],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: EnhancedTheme.accentPurple.withValues(alpha: 0.35), blurRadius: 8)],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.medical_services_rounded, color: Colors.black, size: 13),
          SizedBox(width: 5),
          Text('Rx Log', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    ]),
  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _statsRow(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: statsAsync.when(
        loading: () => Row(children: [
          Expanded(child: EnhancedTheme.loadingShimmer(height: 82, radius: 16)),
          const SizedBox(width: 10),
          Expanded(child: EnhancedTheme.loadingShimmer(height: 82, radius: 16)),
          const SizedBox(width: 10),
          Expanded(child: EnhancedTheme.loadingShimmer(height: 82, radius: 16)),
          const SizedBox(width: 10),
          Expanded(child: EnhancedTheme.loadingShimmer(height: 82, radius: 16)),
        ]),
        error: (e, _) => const SizedBox.shrink(),
        data: (stats) {
          final daily   = stats['daily']   as Map<String, dynamic>? ?? {};
          final monthly = stats['monthly'] as Map<String, dynamic>? ?? {};
          final dailyCount    = daily['count']     ?? 0;
          final dailyRevenue  = (daily['revenue']   as num?)?.toDouble() ?? 0;
          final monthlyCount  = monthly['count']   ?? 0;
          final monthlyRevenue = (monthly['revenue'] as num?)?.toDouble() ?? 0;
          return Row(children: [
            Expanded(child: _statCard('$dailyCount', 'Daily\nCount', EnhancedTheme.primaryTeal, Icons.today_rounded, index: 0)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(_fmtNaira(dailyRevenue), 'Daily\nRevenue', EnhancedTheme.accentCyan, Icons.payments_rounded, index: 1)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('$monthlyCount', 'Monthly\nCount', EnhancedTheme.accentPurple, Icons.calendar_month_rounded, index: 2)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(_fmtNaira(monthlyRevenue), 'Monthly\nRevenue', EnhancedTheme.successGreen, Icons.trending_up_rounded, index: 3)),
          ]);
        },
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon, {required int index}) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.06)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: context.hintColor, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ),
    ),
  ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 80 * index)).scale(begin: const Offset(0.9, 0.9));

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _searchBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name or brand...',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    ),
  );

  // ── Date Filter Chips ──────────────────────────────────────────────────────

  Widget _dateFilterChips() {
    // 0=Today  1=This Week  2=This Month  3=All  4=Custom
    const labels = ['Today', 'This Week', 'This Month', 'All', 'Custom'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final idx      = e.key;
          final isCustom = idx == 4;
          final active   = isCustom ? _dateFilter == 4 : (_customRange == null && idx == _dateFilter);

          // Custom chip shows selected date range when active
          String label = e.value;
          if (isCustom && active && _customRange != null) {
            label = '${_fmtDate(_customRange!.start)} – ${_fmtDate(_customRange!.end)}';
          }

          return GestureDetector(
            onTap: () {
              if (isCustom) {
                _openDatePicker();
              } else {
                setState(() {
                  _dateFilter = idx;
                  _customRange = null;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: active ? EnhancedTheme.primaryTeal : context.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? EnhancedTheme.primaryTeal : context.borderColor,
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active ? [
                  BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3),
                      blurRadius: 8, offset: const Offset(0, 2)),
                ] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isCustom) ...[
                  Icon(Icons.date_range_rounded, size: 11,
                      color: active ? Colors.black : context.subLabelColor),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        color: active ? Colors.black : context.subLabelColor,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Custom Range Banner ────────────────────────────────────────────────────

  Widget _customRangeBanner() {
    if (_customRange == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
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
              '${_fmtDate(_customRange!.start)} – ${_fmtDate(_customRange!.end)}',
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

  // ── Log List ───────────────────────────────────────────────────────────────

  Widget _logList(AsyncValue<List<dynamic>> logAsync) {
    return logAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EnhancedTheme.loadingShimmer(height: 88, radius: 18),
        ),
      ),
      error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Failed to load', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ])),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.05),
                ]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medication_rounded, color: EnhancedTheme.accentPurple, size: 48),
            ),
            const SizedBox(height: 16),
            Text('No dispensing records found',
                style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Try a different date range or search term',
                style: TextStyle(color: context.subLabelColor, fontSize: 13)),
          ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (_, i) => _logEntryCard(entries[i] as Map<String, dynamic>, i),
        );
      },
    );
  }

  Widget _logEntryCard(Map<String, dynamic> entry, int index) {
    final name = entry['name'] as String? ?? entry['itemName'] as String? ?? 'Unknown';
    final brand = entry['brand'] as String? ?? '';
    final quantity = entry['quantity'] ?? 0;
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final status = (entry['status'] as String? ?? 'dispensed').toLowerCase();
    final dateStr = entry['createdAt'] as String? ?? entry['date'] as String? ?? entry['dispensedAt'] as String? ?? '';
    final dispenser = entry['dispenser'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        statusIcon = Icons.undo_rounded;
        break;
      case 'partially_returned':
      case 'partial':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial';
        statusIcon = Icons.remove_circle_outline_rounded;
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Dispensed';
        statusIcon = Icons.check_circle_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(children: [
              // Left color accent via border-left workaround
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    statusColor.withValues(alpha: 0.8),
                    statusColor.withValues(alpha: 0.2),
                  ]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.2),
                            statusColor.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Icon(Icons.medication_rounded, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name,
                          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (brand.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.business_rounded, color: context.hintColor, size: 11),
                          const SizedBox(width: 4),
                          Text(brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                        ]),
                      ],
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_fmtNaira(amount),
                          style: const TextStyle(color: EnhancedTheme.primaryTeal,
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(statusIcon, color: statusColor, size: 10),
                          const SizedBox(width: 3),
                          Text(statusLabel,
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  // Bottom meta row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      Icon(Icons.shopping_bag_outlined, color: context.hintColor, size: 12),
                      const SizedBox(width: 4),
                      Text('Qty: $quantity', style: TextStyle(color: context.hintColor, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                      if (dispenser.isNotEmpty) ...[
                        Container(margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 3, height: 3,
                            decoration: BoxDecoration(color: context.hintColor, shape: BoxShape.circle)),
                        Icon(Icons.person_outline_rounded, color: context.hintColor, size: 12),
                        const SizedBox(width: 3),
                        Flexible(child: Text(dispenser,
                            style: TextStyle(color: context.hintColor, fontSize: 11),
                            overflow: TextOverflow.ellipsis)),
                      ],
                      const Spacer(),
                      if (dateStr.isNotEmpty) ...[
                        Icon(Icons.access_time_rounded, color: context.hintColor, size: 11),
                        const SizedBox(width: 3),
                        Text(_formatTimestamp(dateStr),
                            style: TextStyle(color: context.hintColor, fontSize: 10)),
                      ],
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.05);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}';
  }


  String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, $hour:$minute';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}
