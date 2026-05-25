import 'package:intl/intl.dart';

final _comma = NumberFormat('#,##0', 'en_US');
final _commaDecimal = NumberFormat('#,##0.00', 'en_US');

/// Full naira format with commas. Auto picks decimals: ₦10,000 or ₦10,000.50
String fmtN(double v) {
  if (v == v.truncateToDouble()) return '₦${_comma.format(v)}';
  return '₦${_commaDecimal.format(v)}';
}

/// Compact: ₦1.5M, ₦10K, or ₦10,000 (falls back to fmtN for small values)
String fmtNCompact(double v) {
  if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
  return fmtN(v);
}

/// Number with commas, no symbol (for column data). e.g. 10,000
String fmtNum(double v) {
  if (v == v.truncateToDouble()) return _comma.format(v);
  return _commaDecimal.format(v);
}
