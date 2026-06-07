import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/models/commission_config.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/commission_provider.dart';

class CommissionReportScreen extends ConsumerStatefulWidget {
  const CommissionReportScreen({super.key});

  @override
  ConsumerState<CommissionReportScreen> createState() =>
      _CommissionReportScreenState();
}

class _CommissionReportScreenState
    extends ConsumerState<CommissionReportScreen> {
  String _period = 'Today';
  final _periods = ['Today', 'This Week', 'This Month', 'This Quarter', 'This Year'];

  final Map<int, TextEditingController> _rateControllers = {};
  final Map<int, TextEditingController> _bonusControllers = {};
  final Set<int> _editingIds = {};

  String get _apiPeriod {
    switch (_period) {
      case 'This Week':    return 'week';
      case 'This Month':   return 'month';
      case 'This Quarter': return 'quarter';
      case 'This Year':    return 'year';
      default:             return 'today';
    }
  }

  String _fmt(double v) => fmtN(v);

  @override
  void dispose() {
    for (final c in _rateControllers.values) { c.dispose(); }
    for (final c in _bonusControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(staffPerformanceProvider(_apiPeriod));
    ref.invalidate(commissionConfigsProvider);
  }

  void _shareReport(StaffPerformanceData data) {
    final buf = StringBuffer();
    buf.writeln('PharmApp — Commission Report ($_period)');
    buf.writeln('Total Commissions: ${_fmt(data.totalCommissions)}');
    buf.writeln('');
    for (final s in data.staff) {
      buf.writeln('${s.userName} (${s.role})');
      buf.writeln('  Sales: ${s.salesCount} | Amount: ${_fmt(s.totalSales)}');
      buf.writeln('  Rate: ${(s.commissionRate * 100).toStringAsFixed(1)}%'
          ' | Earned: ${_fmt(s.commissionEarned)}');
      if ((s.fixedBonus ?? 0) > 0) {
        buf.writeln('  Bonus: ${_fmt(s.fixedBonus!)}');
      }
      buf.writeln('  Payout: ${_fmt(s.totalPayout)}');
      buf.writeln('');
    }
    Share.share(buf.toString(), subject: 'Commission Report — $_period');
  }

  Future<void> _saveRate(int userId, double? bonus) async {
    final ctrl = _rateControllers[userId];
    if (ctrl == null) return;
    final rate = double.tryParse(ctrl.text);
    if (rate == null || rate < 0 || rate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid rate between 0 and 100'),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
      return;
    }
    try {
      await ref
          .read(commissionNotifierProvider.notifier)
          .updateRate(userId, rate / 100, bonus);
      setState(() => _editingIds.remove(userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission rate updated'),
            backgroundColor: EnhancedTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: EnhancedTheme.errorRed,
          ),
        );
      }
    }
  }

  Color _roleColor(String role) {
    if (role == 'Admin' || role == 'Manager') return EnhancedTheme.accentPurple;
    if (role == 'Cashier') return EnhancedTheme.primaryTeal;
    if (role.contains('Wholesale')) return EnhancedTheme.accentCyan;
    return EnhancedTheme.infoBlue;
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final isSenior  = Rbac.isSenior(user);
    final perfAsync = ref.watch(staffPerformanceProvider(_apiPeriod));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        Positioned(
          top: -50, right: -50,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EnhancedTheme.successGreen.withValues(alpha: 0.07)),
          ),
        ),
        Positioned(
          bottom: 80, left: -60,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.05)),
          ),
        ),
        SafeArea(child: Column(children: [
          _buildHeader(context, isSenior, perfAsync),
          const SizedBox(height: 8),
          _periodSelector(),
          const SizedBox(height: 4),
          Expanded(child: RefreshIndicator(
            onRefresh: _refresh,
            color: EnhancedTheme.successGreen,
            child: perfAsync.when(
              loading: () => _loadingState(),
              error: (e, _) => _errorState(e),
              data: (data) => _buildBody(context, data, isSenior),
            ),
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSenior,
      AsyncValue<StaffPerformanceData> perfAsync) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
              child: Icon(Icons.arrow_back_rounded,
                  color: context.labelColor, size: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Commission Report',
                style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            Text('Staff earnings & payout tracking',
                style: TextStyle(color: context.hintColor, fontSize: 11)),
          ])),
          if (perfAsync.hasValue)
            GestureDetector(
              onTap: () => _shareReport(perfAsync.requireValue),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: EnhancedTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: EnhancedTheme.successGreen.withValues(alpha: 0.25))),
                child: const Icon(Icons.share_rounded,
                    color: EnhancedTheme.successGreen, size: 18)),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.25))),
            child: const Icon(Icons.payments_rounded,
                color: EnhancedTheme.accentPurple, size: 18)),
        ]),
      ).animate().fadeIn(duration: 350.ms);

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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _periods.map((p) {
              final active = p == _period;
              return GestureDetector(
                onTap: () => setState(() => _period = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(colors: [
                            EnhancedTheme.successGreen.withValues(alpha: 0.9),
                            EnhancedTheme.primaryTeal.withValues(alpha: 0.8),
                          ])
                        : null,
                    color: active ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(p, textAlign: TextAlign.center,
                      style: TextStyle(
                          color: active ? Colors.white : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              );
            }).toList()),
          ),
        ),
      ),
    ),
  ).animate().fadeIn(duration: 350.ms, delay: 80.ms);

  Widget _loadingState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: EnhancedTheme.successGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle),
        child: const CircularProgressIndicator(
            color: EnhancedTheme.successGreen, strokeWidth: 3)),
      const SizedBox(height: 16),
      Text('Loading commissions…',
          style: TextStyle(
              color: EnhancedTheme.successGreen.withValues(alpha: 0.8),
              fontSize: 13)),
    ]),
  );

  Widget _errorState(Object e) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2))),
        child: Icon(Icons.cloud_off_rounded,
            color: EnhancedTheme.errorRed.withValues(alpha: 0.6), size: 40)),
      const SizedBox(height: 16),
      Text('Failed to load commissions',
          style: GoogleFonts.outfit(
              color: context.labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('$e',
          style: TextStyle(color: context.subLabelColor, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _refresh,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [EnhancedTheme.successGreen, EnhancedTheme.primaryTeal]),
            borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  ));

  Widget _buildBody(BuildContext context, StaffPerformanceData data, bool isSenior) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Summary hero ────────────────────────────────────────────────────────
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
                    EnhancedTheme.successGreen.withValues(alpha: 0.20),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: EnhancedTheme.successGreen.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.successGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.payments_rounded,
                        color: EnhancedTheme.successGreen, size: 20)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Commissions',
                        style: TextStyle(
                            color: context.subLabelColor,
                            fontSize: 12,
                            letterSpacing: 0.4)),
                    Text(_fmt(data.totalCommissions),
                        style: GoogleFonts.outfit(
                            color: context.labelColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                  ]),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _kpiBadge(
                      'Staff', '${data.staff.length}',
                      Icons.group_rounded, EnhancedTheme.accentPurple)),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBadge(
                      'Total Sales',
                      _fmt(data.staff.fold(0.0, (s, e) => s + e.totalSales)),
                      Icons.receipt_long_rounded, EnhancedTheme.primaryTeal)),
                  const SizedBox(width: 10),
                  Expanded(child: _kpiBadge(
                      'Period', _periodLabel(data.period),
                      Icons.calendar_today_rounded, EnhancedTheme.accentCyan)),
                ]),
              ]),
            ),
          ),
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(height: 22),

        // ── Staff cards ─────────────────────────────────────────────────────────
        _sectionHeader(context, 'Staff Commissions',
            Icons.leaderboard_rounded, EnhancedTheme.successGreen),
        const SizedBox(height: 12),

        if (data.staff.isEmpty)
          _emptyState()
        else
          ...data.staff.asMap().entries.map((e) => _staffCommissionCard(
                context, e.value, e.key, isSenior)
              .animate()
              .fadeIn(duration: 300.ms, delay: (60 * e.key).ms)
              .slideX(begin: 0.05, end: 0)),

        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _staffCommissionCard(BuildContext context, StaffPerformanceEntry entry,
      int index, bool isSenior) {
    final color = _roleColor(entry.role);
    final isEditing = _editingIds.contains(entry.userId);

    _rateControllers.putIfAbsent(entry.userId, () => TextEditingController(
        text: (entry.commissionRate * 100).toStringAsFixed(1)));
    _bonusControllers.putIfAbsent(entry.userId, () => TextEditingController(
        text: entry.fixedBonus != null
            ? entry.fixedBonus!.toStringAsFixed(0)
            : ''));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Name + role + rank
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3))),
                  child: Center(child: Text('${index + 1}',
                      style: TextStyle(
                          color: color, fontSize: 14, fontWeight: FontWeight.w800)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.userName.isNotEmpty ? entry.userName : 'Staff #${entry.userId}',
                      style: GoogleFonts.outfit(
                          color: context.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4)),
                    child: Text(entry.role,
                        style: TextStyle(
                            color: color, fontSize: 9, fontWeight: FontWeight.w700))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmt(entry.totalPayout),
                      style: const TextStyle(
                          color: EnhancedTheme.successGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text('Total payout',
                      style: TextStyle(color: context.subLabelColor, fontSize: 10)),
                ]),
              ]),

              const SizedBox(height: 12),

              // Sales stats row
              Row(children: [
                _miniStat('Sales', '${entry.salesCount}', EnhancedTheme.primaryTeal),
                _miniStat('Revenue', _fmt(entry.totalSales), color),
                _miniStat('Earned', _fmt(entry.commissionEarned), EnhancedTheme.successGreen),
                if ((entry.fixedBonus ?? 0) > 0)
                  _miniStat('Bonus', _fmt(entry.fixedBonus!), EnhancedTheme.accentOrange),
              ]),

              const SizedBox(height: 12),

              // Commission rate row — editable for Admin/Manager
              if (!isEditing)
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: EnhancedTheme.accentPurple.withValues(alpha: 0.25))),
                    child: Row(children: [
                      const Icon(Icons.percent_rounded,
                          color: EnhancedTheme.accentPurple, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '${(entry.commissionRate * 100).toStringAsFixed(1)}% rate',
                        style: const TextStyle(
                            color: EnhancedTheme.accentPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                  if ((entry.fixedBonus ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: EnhancedTheme.accentOrange.withValues(alpha: 0.25))),
                      child: Text(
                        '+ ${_fmt(entry.fixedBonus!)} bonus',
                        style: const TextStyle(
                            color: EnhancedTheme.accentOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isSenior)
                    GestureDetector(
                      onTap: () {
                        _rateControllers[entry.userId]?.text =
                            (entry.commissionRate * 100).toStringAsFixed(1);
                        _bonusControllers[entry.userId]?.text =
                            entry.fixedBonus != null
                                ? entry.fixedBonus!.toStringAsFixed(0)
                                : '';
                        setState(() => _editingIds.add(entry.userId));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.borderColor)),
                        child: Icon(Icons.edit_rounded,
                            color: context.subLabelColor, size: 14)),
                    ),
                ])
              else
                _editRateRow(context, entry),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _editRateRow(BuildContext context, StaffPerformanceEntry entry) {
    final saveAsync = ref.watch(commissionNotifierProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextFormField(
          controller: _rateControllers[entry.userId],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: TextStyle(color: context.labelColor, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Rate (%)',
            labelStyle: TextStyle(color: context.hintColor, fontSize: 12),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: EnhancedTheme.accentPurple, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(
          controller: _bonusControllers[entry.userId],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: TextStyle(color: context.labelColor, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Fixed Bonus (₦)',
            labelStyle: TextStyle(color: context.hintColor, fontSize: 12),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide:
                    BorderSide(color: EnhancedTheme.accentOrange, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => _editingIds.remove(entry.userId)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor)),
            child: Text('Cancel',
                style: TextStyle(
                    color: context.subLabelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        ),
        const SizedBox(width: 8),
        Expanded(child: GestureDetector(
          onTap: saveAsync.isLoading
              ? null
              : () {
                  final bonusText = _bonusControllers[entry.userId]?.text ?? '';
                  final bonus = bonusText.isEmpty ? null : double.tryParse(bonusText);
                  _saveRate(entry.userId, bonus);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [EnhancedTheme.successGreen, EnhancedTheme.primaryTeal]),
              borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: saveAsync.isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        )),
      ]),
    ]);
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(color: context.hintColor, fontSize: 8),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _kpiBadge(String label, String value, IconData icon, Color color) =>
      Container(
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
                  color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.black45, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _sectionHeader(
          BuildContext context, String title, IconData icon, Color color) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.outfit(
                color: context.labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ]);

  Widget _emptyState() => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: EnhancedTheme.successGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: EnhancedTheme.successGreen.withValues(alpha: 0.15))),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle),
            child: const Icon(Icons.payments_rounded,
                color: EnhancedTheme.successGreen, size: 32)),
          const SizedBox(height: 14),
          Text('No commission data for this period',
              style: TextStyle(color: context.subLabelColor, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  String _periodLabel(String p) {
    switch (p) {
      case 'today':   return 'Today';
      case 'week':    return 'Week';
      case 'month':   return 'Month';
      case 'quarter': return 'Quarter';
      case 'year':    return 'Year';
      default:        return p;
    }
  }
}
