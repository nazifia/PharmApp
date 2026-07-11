import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

/// Shared custom date-range support for report screens.
/// Period key format understood by ReportsApiClient / LocalDb / backend:
/// 'custom:yyyy-MM-dd:yyyy-MM-dd'

String customPeriodKey(DateTimeRange r) {
  final from = r.start.toIso8601String().split('T').first;
  final to = r.end.toIso8601String().split('T').first;
  return 'custom:$from:$to';
}

String fmtRangeDate(DateTime dt) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${m[dt.month - 1]} ${dt.day}';
}

String fmtRangeLabel(DateTimeRange r) =>
    '${fmtRangeDate(r.start)} – ${fmtRangeDate(r.end)}';

/// Dark-glass themed date range picker used by all report screens.
Future<DateTimeRange?> pickReportDateRange(BuildContext context,
    {DateTimeRange? initial}) {
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    initialDateRange: initial,
    builder: (ctx, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: EnhancedTheme.primaryTeal,
          onPrimary: Colors.white,
          secondary: EnhancedTheme.accentCyan,
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFE2E8F0),
          onSurfaceVariant: Color(0xFF94A3B8),
          outline: Color(0xFF334155),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          surfaceTintColor: Colors.transparent,
          rangePickerBackgroundColor: const Color(0xFF0F172A),
          rangePickerElevation: 0,
          rangePickerSurfaceTintColor: Colors.transparent,
          rangePickerHeaderBackgroundColor: EnhancedTheme.primaryTeal,
          rangePickerHeaderForegroundColor: Colors.white,
          rangePickerHeaderHeadlineStyle: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          weekdayStyle: TextStyle(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700, fontSize: 11),
          dayStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          dayForegroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return Colors.white;
            if (s.contains(WidgetState.disabled)) return const Color(0xFF475569);
            return const Color(0xFFE2E8F0);
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return EnhancedTheme.primaryTeal;
            return Colors.transparent;
          }),
          dayOverlayColor: WidgetStatePropertyAll(
              EnhancedTheme.primaryTeal.withValues(alpha: 0.12)),
          todayForegroundColor:
              const WidgetStatePropertyAll(EnhancedTheme.accentCyan),
          todayBackgroundColor: WidgetStatePropertyAll(
              EnhancedTheme.accentCyan.withValues(alpha: 0.12)),
          todayBorder: const BorderSide(color: EnhancedTheme.accentCyan, width: 1.5),
          rangeSelectionBackgroundColor:
              EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
          rangeSelectionOverlayColor: WidgetStatePropertyAll(
              EnhancedTheme.primaryTeal.withValues(alpha: 0.10)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: EnhancedTheme.primaryTeal,
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
          ),
        ),
        dividerColor: const Color(0xFF334155),
      ),
      child: child!,
    ),
  );
}

/// Header icon button that opens the range picker; highlighted when active.
Widget dateRangeButton(BuildContext context,
    {required DateTimeRange? range,
    required VoidCallback onTap,
    Color color = EnhancedTheme.primaryTeal}) {
  final active = range != null;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(Icons.date_range_rounded,
          color: active ? color : context.labelColor, size: 18),
    ),
  );
}

/// Banner shown while a custom range is active. Tap = change, X = clear.
Widget customRangeBanner({
  required DateTimeRange? range,
  required VoidCallback onChange,
  required VoidCallback onClear,
  Color color = EnhancedTheme.primaryTeal,
  Color accent = EnhancedTheme.accentCyan,
}) {
  if (range == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: GestureDetector(
      onTap: onChange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_month_rounded, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(
            fmtRangeLabel(range),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
          )),
          Text('Change', style: TextStyle(
              color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close_rounded, color: color, size: 13),
            ),
          ),
        ]),
      ),
    ),
  ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.15, end: 0);
}
