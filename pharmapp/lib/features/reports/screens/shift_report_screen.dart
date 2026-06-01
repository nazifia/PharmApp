import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/shared/models/shift.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/shift_api_client.dart';

class ShiftReportScreen extends ConsumerStatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  ConsumerState<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends ConsumerState<ShiftReportScreen> {
  DateTimeRange? _range;
  String _period = 'Today';
  static const _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? get _from {
    if (_range != null) return _isoDate(_range!.start);
    final now = DateTime.now();
    switch (_period) {
      case 'Today':      return _isoDate(now);
      case 'This Week':  return _isoDate(now.subtract(Duration(days: now.weekday - 1)));
      case 'This Month': return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      default:           return null;
    }
  }

  String? get _to {
    if (_range != null) return _isoDate(_range!.end);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(activeBranchProvider);
    final query = ShiftQuery(
      from: _from,
      to: _to,
      branchId: branch != null && branch.id > 0 ? branch.id : null,
    );
    final shiftsAsync    = ref.watch(shiftListProvider(query));
    final currentAsync   = ref.watch(currentShiftProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
              ),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Shift Reports', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Staff shift summaries', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              _OpenShiftButton(currentAsync: currentAsync),
            ]),
          ),

          // Period chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              ..._periods.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() { _period = p; _range = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _period == p && _range == null
                          ? EnhancedTheme.primaryTeal.withValues(alpha: 0.2)
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _period == p && _range == null
                            ? EnhancedTheme.primaryTeal.withValues(alpha: 0.5)
                            : context.borderColor,
                      ),
                    ),
                    child: Text(p, style: TextStyle(
                      color: _period == p && _range == null ? EnhancedTheme.primaryTeal : context.labelColor,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
              )),
              GestureDetector(
                onTap: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: EnhancedTheme.primaryTeal),
                      ),
                      child: child!,
                    ),
                  );
                  if (r != null) setState(() { _range = r; _period = ''; });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _range != null ? EnhancedTheme.accentCyan.withValues(alpha: 0.15) : context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _range != null ? EnhancedTheme.accentCyan.withValues(alpha: 0.5) : context.borderColor,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.date_range_rounded,
                        color: _range != null ? EnhancedTheme.accentCyan : context.hintColor, size: 14),
                    const SizedBox(width: 6),
                    Text(_range != null
                        ? '${_range!.start.day}/${_range!.start.month} – ${_range!.end.day}/${_range!.end.month}'
                        : 'Custom',
                        style: TextStyle(
                          color: _range != null ? EnhancedTheme.accentCyan : context.labelColor,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                  ]),
                ),
              ),
            ]),
          ),

          // Current shift card (if open)
          currentAsync.whenOrNull(
            data: (shift) => shift != null && shift.isOpen
                ? _CurrentShiftCard(shift: shift)
                : null,
          ) ?? const SizedBox.shrink(),

          // Shifts list
          Expanded(child: shiftsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal, strokeWidth: 2)),
            error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.cloud_off_rounded, color: EnhancedTheme.errorRed, size: 40),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: () => ref.invalidate(shiftListProvider(query)), child: const Text('Retry')),
            ])),
            data: (shifts) => shifts.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.schedule_rounded, color: context.hintColor, size: 48),
                    const SizedBox(height: 12),
                    Text('No shifts for this period', style: TextStyle(color: context.subLabelColor, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Open a shift from the button above', style: TextStyle(color: context.hintColor, fontSize: 12)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: shifts.length,
                    itemBuilder: (_, i) => _ShiftCard(shift: shifts[i]),
                  ),
          )),
        ])),
      ]),
    );
  }
}

// ── Open / close shift button ─────────────────────────────────────────────────

class _OpenShiftButton extends ConsumerWidget {
  final AsyncValue<Shift?> currentAsync;
  const _OpenShiftButton({required this.currentAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = currentAsync.valueOrNull;
    final isOpen  = current?.isOpen ?? false;

    return ElevatedButton.icon(
      onPressed: () => isOpen
          ? _showCloseSheet(context, ref, current!)
          : _showOpenSheet(context, ref),
      style: ElevatedButton.styleFrom(
        backgroundColor: isOpen ? EnhancedTheme.errorRed : EnhancedTheme.successGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: Icon(isOpen ? Icons.lock_clock : Icons.play_circle_rounded, size: 16),
      label: Text(isOpen ? 'Close Shift' : 'Open Shift',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  void _showOpenSheet(BuildContext context, WidgetRef ref) {
    final cashCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShiftSheet(
        title: 'Open Shift',
        label: 'Opening Cash (₦)',
        icon: Icons.play_circle_rounded,
        color: EnhancedTheme.successGreen,
        cashCtrl: cashCtrl,
        onSubmit: () async {
          final cash = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
          Navigator.pop(ctx);
          final ok = await ref.read(shiftNotifierProvider.notifier).openShift(openingCash: cash);
          if (context.mounted) {
            _showSnack(context, ok ? 'Shift opened' : 'Failed to open shift', ok);
          }
        },
      ),
    );
  }

  void _showCloseSheet(BuildContext context, WidgetRef ref, Shift current) {
    final cashCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShiftSheet(
        title: 'Close Shift',
        label: 'Closing Cash Count (₦)',
        icon: Icons.lock_clock,
        color: EnhancedTheme.errorRed,
        cashCtrl: cashCtrl,
        extraInfo: 'Shift sales: ${fmtN(current.totalSales)}  ·  ${current.salesCount} transactions',
        onSubmit: () async {
          final cash = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
          Navigator.pop(ctx);
          final ok = await ref.read(shiftNotifierProvider.notifier).closeShift(shiftId: current.id, closingCash: cash);
          if (context.mounted) {
            _showSnack(context, ok ? 'Shift closed' : 'Failed to close shift', ok);
          }
        },
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: (ok ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.black, size: 18),
        const SizedBox(width: 10),
        Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
      ]),
    ));
  }
}

class _ShiftSheet extends StatelessWidget {
  final String title;
  final String label;
  final IconData icon;
  final Color color;
  final TextEditingController cashCtrl;
  final String? extraInfo;
  final VoidCallback onSubmit;
  const _ShiftSheet({required this.title, required this.label, required this.icon,
      required this.color, required this.cashCtrl, this.extraInfo, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 44, height: 5,
                  decoration: BoxDecoration(color: context.hintColor.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.outfit(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              if (extraInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.infoBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnhancedTheme.infoBlue.withValues(alpha: 0.2)),
                  ),
                  child: Text(extraInfo!, style: TextStyle(color: context.labelColor, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: cashCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(Icons.currency_exchange_rounded, color: context.hintColor, size: 18),
                  filled: true,
                  fillColor: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                )),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Current shift card ────────────────────────────────────────────────────────

class _CurrentShiftCard extends StatelessWidget {
  final Shift shift;
  const _CurrentShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EnhancedTheme.successGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: EnhancedTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radio_button_checked, color: EnhancedTheme.successGreen, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Active Shift', style: TextStyle(color: EnhancedTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${shift.staffName}  ·  ${shift.salesCount} sales  ·  ${fmtN(shift.totalSales)}',
                    style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Shift card ────────────────────────────────────────────────────────────────

class _ShiftCard extends StatefulWidget {
  final Shift shift;
  const _ShiftCard({required this.shift});

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  bool _expanded = false;

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min  = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day}/${dt.month}/${dt.year}  $hour:$min $ampm';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final isOpen = s.isOpen;
    final color  = isOpen ? EnhancedTheme.successGreen : EnhancedTheme.primaryTeal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isOpen ? Icons.radio_button_checked : Icons.schedule_rounded,
                          color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(s.staffName,
                            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(isOpen ? 'OPEN' : 'CLOSED',
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(_fmt(s.openedAt), style: TextStyle(color: context.hintColor, fontSize: 11)),
                      if (s.branchName != null) Text(s.branchName!,
                          style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmtN(s.totalSales),
                          style: GoogleFonts.outfit(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('${s.salesCount} sales', style: TextStyle(color: context.hintColor, fontSize: 10)),
                    ]),
                    const SizedBox(width: 4),
                    Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: context.hintColor, size: 18),
                  ]),
                ),
                if (_expanded) ...[
                  Divider(height: 1, color: context.borderColor),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      _row(context, 'Opening Cash', fmtN(s.openingCash), EnhancedTheme.infoBlue),
                      if (!isOpen) _row(context, 'Closing Cash', fmtN(s.closingCash), EnhancedTheme.accentPurple),
                      const SizedBox(height: 8),
                      _row(context, 'Cash Sales', fmtN(s.totalCash), EnhancedTheme.successGreen),
                      _row(context, 'POS Sales', fmtN(s.totalPos), EnhancedTheme.primaryTeal),
                      _row(context, 'Bank Transfer', fmtN(s.totalTransfer), EnhancedTheme.accentCyan),
                      _row(context, 'Wallet', fmtN(s.totalWallet), EnhancedTheme.accentOrange),
                      const Divider(height: 16),
                      _row(context, 'Total Revenue', fmtN(s.totalSales), color, bold: true),
                      if (!isOpen && s.closedAt != null) ...[
                        const SizedBox(height: 8),
                        _row(context, 'Shift ended', _fmt(s.closedAt!), context.subLabelColor),
                      ],
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 12))),
          Text(value, style: TextStyle(
              color: color, fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}
