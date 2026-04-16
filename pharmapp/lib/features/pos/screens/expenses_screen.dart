import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Expense deleted', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Failed to delete: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    }
  }

  void _showManageCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollCtrl) {
              return Container(
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(children: [
                      Center(child: Container(
                        width: 44, height: 4,
                        decoration: BoxDecoration(
                          color: context.hintColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )),
                      const SizedBox(height: 20),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.category_rounded,
                              color: EnhancedTheme.accentPurple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Manage Categories',
                            style: GoogleFonts.outfit(
                                color: context.labelColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        // Add new category button
                        GestureDetector(
                          onTap: () => _showAddCategoryDialog(ctx, setSheet),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_rounded,
                                  color: EnhancedTheme.accentPurple, size: 16),
                              SizedBox(width: 4),
                              Text('Add',
                                  style: TextStyle(
                                      color: EnhancedTheme.accentPurple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ]),
                  ),
                  if (_categories.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.category_outlined,
                              color: context.hintColor, size: 48),
                          const SizedBox(height: 12),
                          Text('No categories yet',
                              style: TextStyle(color: context.subLabelColor, fontSize: 14)),
                        ]),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final catId = cat['id'] as int;
                          final catName = cat['name'] as String? ?? '';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.label_rounded,
                                    color: EnhancedTheme.accentPurple, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(catName,
                                    style: GoogleFonts.outfit(
                                        color: context.labelColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              // Edit button
                              GestureDetector(
                                onTap: () => _showEditCategoryDialog(
                                    ctx, setSheet, catId, catName),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: EnhancedTheme.primaryTeal, size: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              GestureDetector(
                                onTap: () => _confirmDeleteCategory(
                                    ctx, setSheet, catId, catName),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.delete_rounded,
                                      color: EnhancedTheme.errorRed, size: 16),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
                    ),
                ]),
              );
            },
          );
        });
      },
    );
  }

  void _showAddCategoryDialog(BuildContext sheetCtx, StateSetter setSheet) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Category',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: context.labelColor),
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: TextStyle(color: context.hintColor),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: EnhancedTheme.accentPurple, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel',
                style: TextStyle(color: context.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dCtx);
              try {
                await ref.read(posApiProvider).createExpenseCategory(name);
                await _loadCategories();
                setSheet(() {});
                if (mounted) {
                  _showSnack('Category "$name" created', EnhancedTheme.successGreen);
                }
              } catch (e) {
                if (mounted) _showSnack('Failed: $e', EnhancedTheme.errorRed);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(
      BuildContext sheetCtx, StateSetter setSheet, int id, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Category',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: context.labelColor),
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: TextStyle(color: context.hintColor),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: EnhancedTheme.primaryTeal, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel',
                style: TextStyle(color: context.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty || name == currentName) {
                Navigator.pop(dCtx);
                return;
              }
              Navigator.pop(dCtx);
              try {
                await ref.read(posApiProvider).updateExpenseCategory(id, name);
                await _loadCategories();
                setSheet(() {});
                if (mounted) {
                  _showSnack('Category updated', EnhancedTheme.successGreen);
                }
              } catch (e) {
                if (mounted) _showSnack('Failed: $e', EnhancedTheme.errorRed);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
      BuildContext sheetCtx, StateSetter setSheet, int id, String name) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Category',
            style: GoogleFonts.outfit(
                color: context.labelColor, fontWeight: FontWeight.w700)),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: context.subLabelColor, fontSize: 14),
            children: [
              const TextSpan(text: 'Delete '),
              TextSpan(
                  text: '"$name"',
                  style: const TextStyle(
                      color: EnhancedTheme.errorRed,
                      fontWeight: FontWeight.w700)),
              const TextSpan(
                  text: '? Expenses using this category will be unlinked.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel',
                style: TextStyle(color: context.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              try {
                await ref.read(posApiProvider).deleteExpenseCategory(id);
                await _loadCategories();
                setSheet(() {});
                if (mounted) {
                  _showSnack('Category deleted', EnhancedTheme.successGreen);
                }
              } catch (e) {
                if (mounted) _showSnack('Failed: $e', EnhancedTheme.errorRed);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(
          color == EnhancedTheme.successGreen
              ? Icons.check_circle_rounded
              : Icons.error_rounded,
          color: Colors.black,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600)),
        ),
      ]),
    ));
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
                color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(color: context.hintColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.errorRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('New Expense',
                      style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 24),

                // Category dropdown
                Text('Category', style: TextStyle(color: context.subLabelColor, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
                      dropdownColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
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
                  style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: context.subLabelColor),
                    prefixText: '₦ ',
                    prefixStyle: const TextStyle(color: EnhancedTheme.primaryTeal, fontWeight: FontWeight.w700),
                    filled: true,
                    fillColor: context.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: context.labelColor),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: context.subLabelColor),
                    prefixIcon: Icon(Icons.notes_rounded, color: context.hintColor, size: 18),
                    filled: true,
                    fillColor: context.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: EnhancedTheme.primaryTeal,
                            surface: Color(0xFF1E293B),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheet(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, color: EnhancedTheme.accentCyan, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      const Text('Change', style: TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 12,
                          fontWeight: FontWeight.w600)),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                          content: const Row(children: [
                            Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                            SizedBox(width: 10),
                            Expanded(child: Text('Expense added', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                          ]),
                        ));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                          content: Row(children: [
                            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                          ]),
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: EnhancedTheme.errorRed.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_rounded, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Text('Add Expense',
                            style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                      ]),
                    ),
                  ),
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
        backgroundColor: EnhancedTheme.errorRed,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Expense', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blobs
        Positioned(top: -50, right: -30,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.errorRed.withValues(alpha: 0.06)))),
        Positioned(bottom: 100, left: -60,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.accentOrange.withValues(alpha: 0.05)))),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.labelColor, size: 20),
                  onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expenses',
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 24, fontWeight: FontWeight.w800)),
                Text('Track business expenses', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ])),
              // Manage categories button
              GestureDetector(
                onTap: _showManageCategoriesSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.accentPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.category_rounded,
                        color: EnhancedTheme.accentPurple, size: 16),
                    SizedBox(width: 6),
                    Text('Categories',
                        style: TextStyle(
                            color: EnhancedTheme.accentPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Total badge
              if (!_loading && _expenses.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Text('₦${_totalExpenses.toStringAsFixed(0)}',
                      style: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
            ]),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
          const SizedBox(height: 16),

          Expanded(child: RefreshIndicator(
            onRefresh: _loadAll,
            color: EnhancedTheme.primaryTeal,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), children: [
              // Monthly report card
              _buildReportCard()
                  .animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 16),

              // Period selector
              Row(children: [
                _periodChip(_Period.thisMonth, 'This Month', Icons.calendar_month_rounded),
                const SizedBox(width: 10),
                _periodChip(_Period.lastMonth, 'Last Month', Icons.history_rounded),
              ]).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.date_range_rounded, size: 14, color: EnhancedTheme.accentCyan),
                const SizedBox(width: 6),
                Text(_rangeLabel, style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12,
                    fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 20),

              // Section header
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(width: 3, height: 16,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [EnhancedTheme.errorRed, EnhancedTheme.warningAmber],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(2),
                    )),
                  const SizedBox(width: 10),
                  Text('Expense Log',
                      style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
                if (!_loading)
                  Text('${_expenses.length} records',
                      style: TextStyle(color: context.hintColor, fontSize: 12)),
              ]).animate().fadeIn(duration: 400.ms, delay: 180.ms),
              const SizedBox(height: 12),

              // Expenses list
              if (_loading)
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EnhancedTheme.loadingShimmer(height: 76, radius: 16),
                ))
              else if (_expenses.isEmpty)
                _emptyState()
              else
                ..._expenses.asMap().entries.map((e) => _expenseTile(e.value)
                    .animate(delay: (e.key * 50).ms)
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.05, end: 0)),

              const SizedBox(height: 16),

              // Total summary
              if (_expenses.isNotEmpty)
                _totalSummary()
                    .animate().fadeIn(duration: 400.ms, delay: 200.ms),
            ]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildReportCard() {
    final totalSales = (_report?['totalSales'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (_report?['totalExpenses'] as num?)?.toDouble() ?? 0;
    final netProfit = (_report?['netProfit'] as num?)?.toDouble() ?? (totalSales - totalExpenses);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EnhancedTheme.accentCyan.withValues(alpha: 0.08),
                context.cardColor,
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded, color: EnhancedTheme.accentCyan, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Monthly Report',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: Text(
                  _period == _Period.thisMonth ? 'This Month' : 'Last Month',
                  style: TextStyle(color: context.subLabelColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            if (_loadingReport)
              Row(children: List.generate(3, (_) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: EnhancedTheme.loadingShimmer(height: 56, radius: 12),
              ))))
            else
              Row(children: [
                _reportStat('Sales', '₦${totalSales.toStringAsFixed(0)}',
                    EnhancedTheme.successGreen, Icons.trending_up_rounded),
                _vDivider(),
                _reportStat('Expenses', '₦${totalExpenses.toStringAsFixed(0)}',
                    EnhancedTheme.errorRed, Icons.trending_down_rounded),
                _vDivider(),
                _reportStat('Profit', '₦${netProfit.toStringAsFixed(0)}',
                    netProfit >= 0 ? EnhancedTheme.primaryTeal : EnhancedTheme.errorRed,
                    netProfit >= 0 ? Icons.account_balance_rounded : Icons.warning_amber_rounded),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 48,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: context.dividerColor,
  );

  Widget _reportStat(String label, String value, Color color, IconData icon) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: context.hintColor, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
    ]));
  }

  Widget _periodChip(_Period p, String label, IconData icon) {
    final active = _period == p;
    return GestureDetector(
      onTap: () => _onPeriodChanged(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? EnhancedTheme.primaryTeal.withValues(alpha: 0.12) : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? EnhancedTheme.primaryTeal : context.borderColor,
              width: active ? 1.5 : 1),
          boxShadow: active
              ? [BoxShadow(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                  blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? EnhancedTheme.primaryTeal : context.subLabelColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: active ? EnhancedTheme.primaryTeal : context.subLabelColor,
            fontSize: 12, fontWeight: FontWeight.w700,
          )),
        ]),
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
            gradient: LinearGradient(colors: [
              EnhancedTheme.errorRed.withValues(alpha: 0.05),
              EnhancedTheme.errorRed.withValues(alpha: 0.2),
            ]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.delete_rounded, color: EnhancedTheme.errorRed, size: 22),
            SizedBox(height: 2),
            Text('Delete', style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 10,
                fontWeight: FontWeight.w600)),
          ]),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.errorRed.withValues(alpha: 0.15),
                      EnhancedTheme.errorRed.withValues(alpha: 0.05),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: EnhancedTheme.errorRed, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(categoryName,
                      style: GoogleFonts.outfit(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(description,
                        style: TextStyle(color: context.subLabelColor, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 10, color: EnhancedTheme.accentCyan),
                    const SizedBox(width: 4),
                    Text(dateStr, style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 11,
                        fontWeight: FontWeight.w500)),
                  ]),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₦${amount.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(color: EnhancedTheme.errorRed, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Icon(Icons.swipe_left_rounded, color: context.hintColor, size: 14),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [
              EnhancedTheme.errorRed.withValues(alpha: 0.1),
              EnhancedTheme.errorRed.withValues(alpha: 0.02),
            ]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long_outlined, color: EnhancedTheme.errorRed, size: 52),
        ),
        const SizedBox(height: 20),
        Text('No expenses yet',
            style: GoogleFonts.outfit(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Tap + to record a business expense',
            style: TextStyle(color: context.subLabelColor, fontSize: 13)),
      ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }

  Widget _totalSummary() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              EnhancedTheme.errorRed.withValues(alpha: 0.1),
              EnhancedTheme.errorRed.withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.summarize_rounded, color: EnhancedTheme.errorRed, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Expenses',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('${_expenses.length} records this period',
                  style: TextStyle(color: context.subLabelColor, fontSize: 12)),
            ])),
            Text('₦${_totalExpenses.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(color: EnhancedTheme.errorRed, fontSize: 20, fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}
