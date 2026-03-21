import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/pos_api_provider.dart';

enum _Period { thisMonth, lastMonth }

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  _Period _period = _Period.thisMonth;
  List<dynamic> _expenses = [];
  List<dynamic> _categories = [];
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _loadingReport = true;

  DateTime get _rangeStart {
    final now = DateTime.now();
    if (_period == _Period.thisMonth) return DateTime(now.year, now.month, 1);
    return DateTime(now.year, now.month - 1, 1);
  }

  DateTime get _rangeEnd {
    final now = DateTime.now();
    if (_period == _Period.thisMonth) return DateTime(now.year, now.month + 1, 0);
    return DateTime(now.year, now.month, 0);
  }

  String get _rangeLabel =>
      '${_rangeStart.day}/${_rangeStart.month}/${_rangeStart.year} – ${_rangeEnd.day}/${_rangeEnd.month}/${_rangeEnd.year}';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadExpenses(), _loadReport(), _loadCategories()]);
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(posApiProvider).fetchExpenses(
            from: _rangeStart.toIso8601String().split('T').first,
            to: _rangeEnd.toIso8601String().split('T').first,
          );
      if (mounted) setState(() { _expenses = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReport() async {
    setState(() => _loadingReport = true);
    try {
      final data = await ref.read(posApiProvider).fetchMonthlyReport(
            month: _rangeStart.month,
            year: _rangeStart.year,
          );
      if (mounted) setState(() { _report = data; _loadingReport = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await ref.read(posApiProvider).fetchExpenseCategories();
      if (mounted) setState(() => _categories = data);
    } catch (_) {}
  }

  double get _totalExpenses => _expenses.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));

  void _onPeriodChanged(_Period p) {
    if (_period == p) return;
    setState(() => _period = p);
    _loadAll();
  }

  Future<void> _deleteExpense(int id) async {
    try {
      await ref.read(posApiProvider).deleteExpense(id);
      if (mounted) {
        setState(() => _expenses.removeWhere((e) => e['id'] == id));
        _loadReport();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted'), backgroundColor: EnhancedTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: EnhancedTheme.errorRed),
        );
      }
    }
  }

  void _showAddSheet() {
    int? selectedCategoryId;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: context.scaffoldBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: context.hintColor, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Text('New Expense', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // Category dropdown
                Text('Category', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      hint: Text('Select category', style: TextStyle(color: context.hintColor)),
                      dropdownColor: context.scaffoldBg,
                      items: _categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['name'] ?? '', style: TextStyle(color: context.labelColor)),
                      )).toList(),
                      onChanged: (v) => setSheet(() => selectedCategoryId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.labelColor),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: context.subLabelColor),
                    prefixText: '₦ ',
                    prefixStyle: TextStyle(color: context.labelColor),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: context.labelColor),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: context.subLabelColor),
                  ),
                ),
                const SizedBox(height: 16),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheet(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded, color: context.subLabelColor, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: TextStyle(color: context.labelColor, fontSize: 14),
                      ),
                      const Spacer(),
                      Icon(Icons.edit, color: context.hintColor, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () async {
                    if (selectedCategoryId == null || amountCtrl.text.isEmpty) return;
                    try {
                      await ref.read(posApiProvider).createExpense(
                        categoryId: selectedCategoryId!,
                        amount: double.tryParse(amountCtrl.text) ?? 0,
                        description: descCtrl.text,
                        date: selectedDate.toIso8601String().split('T').first,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense added'), backgroundColor: EnhancedTheme.successGreen),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: EnhancedTheme.errorRed),
                        );
                      }
                    }
                  },
                  child: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                )),
              ]),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: EnhancedTheme.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expenses', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Manage business expenses', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 8),

          Expanded(child: RefreshIndicator(
            onRefresh: _loadAll,
            color: EnhancedTheme.primaryTeal,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
              // Monthly report card
              _buildReportCard(),
              const SizedBox(height: 16),

              // Period selector
              Row(children: [
                _periodChip(_Period.thisMonth, 'This Month'),
                const SizedBox(width: 10),
                _periodChip(_Period.lastMonth, 'Last Month'),
              ]),
              const SizedBox(height: 6),
              Text(_rangeLabel, style: TextStyle(color: context.hintColor, fontSize: 11)),
              const SizedBox(height: 16),

              // Expenses list
              if (_loading)
                ...List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EnhancedTheme.loadingShimmer(height: 72),
                ))
              else if (_expenses.isEmpty)
                _emptyState()
              else
                ..._expenses.map((e) => _expenseTile(e)),

              const SizedBox(height: 16),

              // Total summary
              if (_expenses.isNotEmpty) _totalSummary(),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildReportCard() {
    final totalSales = (_report?['totalSales'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (_report?['totalExpenses'] as num?)?.toDouble() ?? 0;
    final netProfit = totalSales - totalExpenses;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.analytics_rounded, color: EnhancedTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text('Monthly Report', style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            if (_loadingReport)
              Row(children: List.generate(3, (_) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: EnhancedTheme.loadingShimmer(height: 48),
              ))))
            else
              Row(children: [
                _reportStat('Sales', '₦${totalSales.toStringAsFixed(0)}', EnhancedTheme.successGreen),
                const SizedBox(width: 12),
                _reportStat('Expenses', '₦${totalExpenses.toStringAsFixed(0)}', EnhancedTheme.errorRed),
                const SizedBox(width: 12),
                _reportStat('Profit', '₦${netProfit.toStringAsFixed(0)}', netProfit >= 0 ? EnhancedTheme.primaryTeal : EnhancedTheme.errorRed),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _reportStat(String label, String value, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: context.hintColor, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _periodChip(_Period p, String label) {
    final active = _period == p;
    return GestureDetector(
      onTap: () => _onPeriodChanged(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? EnhancedTheme.primaryTeal.withValues(alpha: 0.2) : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? EnhancedTheme.primaryTeal : context.borderColor, width: 1.5),
        ),
        child: Text(label, style: TextStyle(
          color: active ? EnhancedTheme.primaryTeal : context.subLabelColor,
          fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  Widget _expenseTile(Map<String, dynamic> e) {
    final categoryName = e['category']?['name'] ?? e['categoryName'] ?? 'Uncategorized';
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final description = e['description'] ?? '';
    final dateStr = e['date'] ?? '';
    final id = e['id'] as int?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(id ?? UniqueKey()),
        direction: DismissDirection.endToStart,
        onDismissed: (_) { if (id != null) _deleteExpense(id); },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: EnhancedTheme.errorRed),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.errorRed, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(categoryName, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(description, style: TextStyle(color: context.subLabelColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 2),
                  Text(dateStr, style: TextStyle(color: context.hintColor, fontSize: 11)),
                ])),
                const SizedBox(width: 8),
                Text('₦${amount.toStringAsFixed(0)}',
                  style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined, color: context.hintColor, size: 48),
        const SizedBox(height: 12),
        Text('No expenses found', style: TextStyle(color: context.subLabelColor, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Tap + to add a new expense', style: TextStyle(color: context.hintColor, fontSize: 12)),
      ]),
    );
  }

  Widget _totalSummary() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Expenses', style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('₦${_totalExpenses.toStringAsFixed(2)}',
              style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}
