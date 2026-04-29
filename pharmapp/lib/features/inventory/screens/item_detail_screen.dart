import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/offline/offline_queue.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/branches/providers/branch_provider.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../providers/inventory_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

const _kPermEditItems = 'can_edit_items';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  // Local override updated after stock-adjust / edit saves.
  Item? _itemOverride;

  static const _adminRoles = {'Admin', 'Manager'};

  bool get _canEdit {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;
    if (_adminRoles.contains(user.role)) return true;
    return user.permissions[_kPermEditItems] == true;
  }

  bool get _canAdjustStock {
    final user = ref.read(currentUserProvider);
    if (user == null) return false;
    return Rbac.can(user, AppPermission.adjustStock);
  }

  bool get _canDelete {
    final user = ref.read(currentUserProvider);
    return _adminRoles.contains(user?.role);
  }

  void _showNoPermissionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: const Row(children: [
        Icon(Icons.lock_rounded, color: Colors.black, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text(
          'No permission to edit items. Ask an Admin or Manager.',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        )),
      ]),
    ));
  }

  void _showNoAdjustStockPermissionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: const Row(children: [
        Icon(Icons.lock_rounded, color: Colors.black, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text(
          'No permission to adjust stock. Ask an Admin or Manager.',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        )),
      ]),
    ));
  }

  // ── Edit sheet ────────────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, Item item) {
    final nameCtrl      = TextEditingController(text: item.name);
    final brandCtrl     = TextEditingController(text: item.brand);
    final priceCtrl     = TextEditingController(text: item.price.toStringAsFixed(0));
    final costCtrl      = TextEditingController(text: item.costPrice > 0 ? item.costPrice.toStringAsFixed(0) : '');
    final thresholdCtrl = TextEditingController(text: item.lowStockThreshold.toString());
    final barcodeCtrl   = TextEditingController(text: item.barcode == 'N/A' ? '' : item.barcode);
    final expiryCtrl    = TextEditingController(
      text: item.expiryDate != null
          ? '${item.expiryDate!.year}-${item.expiryDate!.month.toString().padLeft(2, '0')}-${item.expiryDate!.day.toString().padLeft(2, '0')}'
          : '',
    );

    String dosageForm = item.dosageForm;
    String unitOfDispensing = item.unitOfDispensing;
    double markup = item.markup;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 44, height: 4,
                      decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_rounded, color: EnhancedTheme.primaryTeal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit Medication',
                        style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 24),

                  _field(nameCtrl, 'Item Name *', validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field(brandCtrl, 'Brand / Manufacturer'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(priceCtrl, 'Retail Price (₦) *',
                        keyboardType: TextInputType.number,
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(costCtrl, 'Cost Price (₦)',
                        keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(thresholdCtrl, 'Low Stock Alert *',
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(barcodeCtrl, 'Barcode')),
                  ]),
                  const SizedBox(height: 12),
                  _field(expiryCtrl, 'Expiry Date (YYYY-MM-DD)',
                      keyboardType: TextInputType.datetime,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_rounded, color: EnhancedTheme.primaryTeal, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: item.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            builder: (ctx, child) => Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: EnhancedTheme.primaryTeal,
                                  onPrimary: Colors.white,
                                  surface: Color(0xFFF8FAFC),
                                  onSurface: Color(0xFF0F172A),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            expiryCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          }
                        },
                      )),
                  const SizedBox(height: 20),

                  Text('Dosage Form', style: TextStyle(color: context.hintColor, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Tablet','Capsule','Cream','Consumable','Galenical','Injection','Infusion','Inhaler','Suspension','Syrup','Drops','Solution','Eye-drop','Ear-drop','Eye-ointment','Rectal','Vaginal','Detergent','Drinks','Paste','Patch','Table-water','Food-item','Sweets','Soaps','Biscuits'].map((f) =>
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() => dosageForm = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: dosageForm == f ? EnhancedTheme.accentPurple.withValues(alpha: 0.15) : ctx.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: dosageForm == f ? EnhancedTheme.accentPurple : ctx.borderColor,
                                    width: dosageForm == f ? 1.5 : 1),
                              ),
                              child: Text(f, style: TextStyle(
                                  color: dosageForm == f ? EnhancedTheme.accentPurple : ctx.subLabelColor,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Unit of Dispensing', style: TextStyle(color: context.hintColor, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Tablet','Capsule','ml','mg','Pack','Bottle','Vial','Sachet','Tube','Ampoule','Strip','Piece','Teaspoon','Tablespoon'].map((u) =>
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() => unitOfDispensing = u),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: unitOfDispensing == u ? EnhancedTheme.accentCyan.withValues(alpha: 0.15) : ctx.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: unitOfDispensing == u ? EnhancedTheme.accentCyan : ctx.borderColor,
                                    width: unitOfDispensing == u ? 1.5 : 1),
                              ),
                              child: Text(u, style: TextStyle(
                                  color: unitOfDispensing == u ? EnhancedTheme.accentCyan : ctx.subLabelColor,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Markup selector
                  Text('Markup %', style: TextStyle(color: context.hintColor, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [0.0, 2.5, 5.0, 7.5, 10.0, 12.5, 15.0, 17.5, 20.0, 22.5, 25.0, 27.5, 30.0, 35.0, 40.0, 45.0, 50.0, 60.0, 70.0, 80.0, 100.0].map((m) =>
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            final cost = double.tryParse(costCtrl.text) ?? 0;
                            setModal(() {
                              markup = m;
                              if (cost > 0) priceCtrl.text = (cost * (1 + m / 100)).toStringAsFixed(0);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: markup == m ? EnhancedTheme.successGreen.withValues(alpha: 0.15) : ctx.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: markup == m ? EnhancedTheme.successGreen : ctx.borderColor, width: markup == m ? 1.5 : 1),
                            ),
                            child: Text('${m % 1 == 0 ? m.toInt() : m}%', style: TextStyle(
                                color: markup == m ? EnhancedTheme.successGreen : ctx.subLabelColor,
                                fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      )).toList()),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModal(() => saving = true);
                        final payload = {
                          'name':                nameCtrl.text.trim(),
                          'brand':               brandCtrl.text.trim().isEmpty ? 'Unknown' : brandCtrl.text.trim(),
                          'dosage_form':         dosageForm,
                          'price':               double.parse(priceCtrl.text),
                          'cost_price':          double.tryParse(costCtrl.text) ?? 0,
                          'markup':              markup,
                          'low_stock_threshold': int.parse(thresholdCtrl.text),
                          'barcode':             barcodeCtrl.text.trim().isEmpty ? 'N/A' : barcodeCtrl.text.trim(),
                          'expiry_date':         expiryCtrl.text.trim().isEmpty ? null : expiryCtrl.text.trim(),
                          'unit_of_dispensing':  unitOfDispensing,
                        };
                        final updated = await ref.read(inventoryNotifierProvider.notifier)
                            .updateItem(item.id, payload);
                        final notifierState = ref.read(inventoryNotifierProvider);
                        if (!context.mounted) return;
                        if (updated != null) {
                          setState(() => _itemOverride = updated.copyWith(
                            dosageForm: dosageForm,
                            unitOfDispensing: unitOfDispensing,
                            markup: markup,
                          ));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${payload['name']} updated successfully', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } else if (notifierState is AsyncData) {
                          // Offline — queued; apply changes optimistically
                          setState(() => _itemOverride = item.copyWith(
                            name: payload['name'] as String,
                            brand: payload['brand'] as String,
                            dosageForm: dosageForm,
                            price: payload['price'] as double,
                            costPrice: payload['cost_price'] as double,
                            markup: markup,
                            lowStockThreshold: payload['low_stock_threshold'] as int,
                            barcode: payload['barcode'] as String,
                            expiryDate: (payload['expiry_date'] as String?) != null
                                ? DateTime.tryParse(payload['expiry_date'] as String)
                                : null,
                            unitOfDispensing: unitOfDispensing,
                          ));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: const Row(children: [
                              Icon(Icons.cloud_off_rounded, color: Colors.black, size: 20),
                              SizedBox(width: 10),
                              Expanded(child: Text('Offline — changes queued for sync', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } else {
                          setModal(() => saving = false);
                          final errMsg = notifierState is AsyncError ? '${notifierState.error}' : 'Update failed';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Error: $errMsg', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: saving
                              ? null
                              : const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                          color: saving ? EnhancedTheme.primaryTeal.withValues(alpha: 0.4) : null,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: saving
                              ? const SizedBox(height: 20, width: 20,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                              : Text('Save Changes',
                                  style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      EnhancedTheme.errorRed.withValues(alpha: 0.15),
                      EnhancedTheme.errorRed.withValues(alpha: 0.05),
                    ]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Delete Medication',
                    style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
                  style: TextStyle(color: ctx.subLabelColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ctx.subLabelColor,
                      side: BorderSide(color: ctx.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Cancel'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final success = await ref.read(inventoryNotifierProvider.notifier)
                          .deleteItem(item.id);
                      if (!context.mounted) return;
                      if (success) {
                        final isQueued = ref.read(offlineMutationQueueProvider).any(
                          (m) => m.method == 'DELETE' && m.path == '/inventory/items/${item.id}/');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: (isQueued
                              ? EnhancedTheme.warningAmber
                              : EnhancedTheme.successGreen).withValues(alpha: 0.92),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                          content: Row(children: [
                            Icon(isQueued ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                                color: Colors.black, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              isQueued ? 'Offline — deletion queued for sync' : '${item.name} deleted',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                          ]),
                        ));
                        context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref));
                      } else {
                        final errState = ref.read(inventoryNotifierProvider);
                        final errMsg = errState is AsyncError ? '${errState.error}' : 'Delete failed';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                          content: Row(children: [
                            const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Error: $errMsg', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                          ]),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnhancedTheme.errorRed, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Transfer stock to another branch ─────────────────────────────────────

  void _showTransferDialog(BuildContext context, Item item) {
    final branches   = ref.read(branchListProvider);
    final current    = ref.read(activeBranchProvider);
    // Only show branches other than the current one.
    final targets    = branches.where((b) => b.id != (current?.id ?? -1)).toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('No other branches available to transfer to.',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
      return;
    }

    int    qty      = 1;
    int    toBranch = targets.first.id;
    String reason   = 'Restock';
    final  reasons  = ['Restock', 'Overstock', 'Recall', 'Other'];
    final  qtyCtrl  = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: EnhancedTheme.accentPurple.withValues(alpha: 0.2)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Title
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: EnhancedTheme.accentPurple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Transfer Stock',
                        style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  // Info banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.infoBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: EnhancedTheme.infoBlue.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_rounded, color: EnhancedTheme.infoBlue, size: 14),
                      const SizedBox(width: 8),
                      Text('Available: ${item.stock} units · ${item.name}',
                          style: const TextStyle(color: EnhancedTheme.infoBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Destination branch picker
                  Text('Transfer To', style: TextStyle(color: ctx.subLabelColor, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: ctx.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ctx.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: toBranch,
                        isExpanded: true,
                        dropdownColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(color: ctx.labelColor, fontSize: 14, fontWeight: FontWeight.w600),
                        items: targets.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Row(children: [
                            Icon(b.isMain ? Icons.home_work_rounded : Icons.store_rounded,
                                color: EnhancedTheme.primaryTeal, size: 16),
                            const SizedBox(width: 8),
                            Text(b.name),
                          ]),
                        )).toList(),
                        onChanged: (v) { if (v != null) setDialog(() => toBranch = v); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quantity stepper
                  Text('Quantity', style: TextStyle(color: ctx.subLabelColor, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: ctx.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ctx.borderColor),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(
                        onTap: () => setDialog(() {
                          if (qty > 1) { qty--; qtyCtrl.text = qty.toString(); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_rounded, color: EnhancedTheme.errorRed, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(width: 70, child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 22, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          filled: true, fillColor: ctx.cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        onChanged: (v) => setDialog(() => qty = (int.tryParse(v) ?? 1).clamp(1, item.stock)),
                      )),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => setDialog(() {
                          if (qty < item.stock) { qty++; qtyCtrl.text = qty.toString(); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: EnhancedTheme.successGreen, size: 18),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Reason chips
                  Text('Reason', style: TextStyle(color: ctx.subLabelColor, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: reasons.map((r) => GestureDetector(
                    onTap: () => setDialog(() => reason = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: reason == r ? EnhancedTheme.accentPurple.withValues(alpha: 0.15) : ctx.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: reason == r ? EnhancedTheme.accentPurple : ctx.borderColor,
                            width: reason == r ? 1.5 : 1),
                      ),
                      child: Text(r, style: TextStyle(
                          color: reason == r ? EnhancedTheme.accentPurple : ctx.subLabelColor,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  )).toList()),
                  const SizedBox(height: 24),
                  // Actions
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ctx.subLabelColor,
                        side: BorderSide(color: ctx.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Cancel'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          final synced = await ref.read(inventoryNotifierProvider.notifier)
                              .transferStock(item.id, toBranch, qty, reason);
                          if (!context.mounted) return;
                          final branchName = targets.firstWhere((b) => b.id == toBranch).name;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: synced
                                ? EnhancedTheme.successGreen.withValues(alpha: 0.92)
                                : EnhancedTheme.warningAmber.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              Icon(synced ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                                  color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                synced
                                    ? 'Transferred $qty units to $branchName'
                                    : 'Offline — transfer queued for sync',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Error: $e',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: EnhancedTheme.accentPurple, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('Transfer', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Adjust stock ──────────────────────────────────────────────────────────

  void _showAdjustStockDialog(Item item) {
    int adjustment = 0;
    String reason  = 'Purchase';
    final qtyCtrl  = TextEditingController();
    final reasons  = ['Purchase', 'Return', 'Correction', 'Damage', 'Expiry'];
    final current  = (_itemOverride ?? item).stock;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: EnhancedTheme.accentCyan.withValues(alpha: 0.2)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: EnhancedTheme.accentCyan, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Adjust Stock',
                        style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.infoBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: EnhancedTheme.infoBlue.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_rounded, color: EnhancedTheme.infoBlue, size: 14),
                      const SizedBox(width: 8),
                      Text('Current stock: $current units',
                          style: const TextStyle(color: EnhancedTheme.infoBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Qty stepper
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: ctx.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ctx.borderColor),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(
                        onTap: () => setDialog(() { adjustment--; qtyCtrl.text = adjustment.toString(); }),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_rounded, color: EnhancedTheme.errorRed, size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(width: 80, child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: ctx.labelColor, fontSize: 24, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          filled: true, fillColor: ctx.cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (v) => setDialog(() => adjustment = int.tryParse(v) ?? 0),
                      )),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => setDialog(() { adjustment++; qtyCtrl.text = adjustment.toString(); }),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.successGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: EnhancedTheme.successGreen, size: 22),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Center(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: (adjustment >= 0 ? EnhancedTheme.successGreen : EnhancedTheme.errorRed).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      adjustment >= 0 ? '+$adjustment units' : '$adjustment units',
                      style: TextStyle(
                        color: adjustment >= 0 ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                        fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  )),
                  const SizedBox(height: 20),
                  Text('Reason', style: TextStyle(color: ctx.subLabelColor, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: reasons.map((r) => GestureDetector(
                    onTap: () => setDialog(() => reason = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: reason == r ? EnhancedTheme.accentCyan.withValues(alpha: 0.15) : ctx.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: reason == r ? EnhancedTheme.accentCyan : ctx.borderColor,
                            width: reason == r ? 1.5 : 1),
                      ),
                      child: Text(r, style: TextStyle(
                        color: reason == r ? EnhancedTheme.accentCyan : ctx.subLabelColor,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  )).toList()),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ctx.subLabelColor,
                        side: BorderSide(color: ctx.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Cancel'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final updated = await ref.read(inventoryNotifierProvider.notifier)
                            .adjustStock(item.id, adjustment, reason);
                        final notifierState = ref.read(inventoryNotifierProvider);
                        if (!mounted) return;
                        if (updated != null) {
                          setState(() => _itemOverride = updated);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Stock updated to ${updated.stock} units ($reason)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } else if (notifierState is AsyncData) {
                          // Offline — queued; apply adjustment optimistically
                          final before = (_itemOverride ?? item).stock;
                          setState(() => _itemOverride = (_itemOverride ?? item)
                              .copyWith(stock: before + adjustment));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: const Row(children: [
                              Icon(Icons.cloud_off_rounded, color: Colors.black, size: 20),
                              SizedBox(width: 10),
                              Expanded(child: Text('Offline — stock adjustment queued for sync', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        } else {
                          final errMsg = notifierState is AsyncError ? '${notifierState.error}' : 'Adjustment failed';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: Row(children: [
                              const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Error: $errMsg', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.accentCyan, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('Apply', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemId = int.tryParse(GoRouterState.of(context).pathParameters['id'] ?? '') ?? 0;
    final itemAsync = ref.watch(itemDetailProvider(itemId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blobs
        Positioned(top: -40, right: -30,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.06)))),
        SafeArea(child: itemAsync.when(
          loading: () => Column(children: [
            _header(context, null, null),
            Expanded(child: ListView(
              padding: const EdgeInsets.all(20),
              children: List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EnhancedTheme.loadingShimmer(height: i == 0 ? 100 : 72, radius: 18),
              )),
            )),
          ]),
          error: (e, _) => Column(children: [
            _header(context, null, null),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: EnhancedTheme.errorRed, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Failed to load item', style: GoogleFonts.outfit(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(itemDetailProvider(itemId)),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]))),
          ]),
          data: (fetchedItem) {
            final item = _itemOverride ?? fetchedItem;
            return _buildContent(context, item);
          },
        )),
      ]),
    );
  }

  Widget _header(BuildContext context, Item? item, String? subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
        Text(item?.name ?? 'Item Details',
            style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(subtitle, style: TextStyle(color: context.hintColor, fontSize: 12)),
      ])),
      if (item != null) ...[
        if (_canEdit)
          Container(
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit_rounded, color: EnhancedTheme.primaryTeal, size: 20),
              tooltip: 'Edit',
              onPressed: () => _showEditSheet(context, item),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.edit_off_rounded, color: context.hintColor, size: 20),
              tooltip: 'No edit permission',
              onPressed: _showNoPermissionSnackBar,
            ),
          ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: context.subLabelColor, size: 20),
            color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'transfer') _showTransferDialog(context, item);
              if (val == 'delete') _confirmDelete(context, item);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'transfer',
                child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, color: EnhancedTheme.accentPurple, size: 18),
                  SizedBox(width: 10),
                  Text('Transfer to Branch', style: TextStyle(color: EnhancedTheme.accentPurple, fontSize: 13)),
                ]),
              ),
              if (_canDelete) const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 18),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ),
      ],
    ]),
  ).animate().fadeIn(duration: 400.ms);

  Widget _buildContent(BuildContext context, Item item) {
    final now     = DateTime.now();
    final expired = item.expiryDate != null && item.expiryDate!.isBefore(now);
    final stockColor = item.stock == 0
        ? EnhancedTheme.errorRed
        : item.stock <= item.lowStockThreshold
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.successGreen;

    return Column(children: [
      _header(context, item, item.brand),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Hero card
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      stockColor.withValues(alpha: 0.08),
                      context.cardColor,
                    ],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: stockColor.withValues(alpha: 0.25), width: 1.5),
                  boxShadow: [BoxShadow(color: stockColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [stockColor.withValues(alpha: 0.2), stockColor.withValues(alpha: 0.06)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: stockColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.medication_rounded, color: stockColor, size: 38),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name,
                        style: GoogleFonts.outfit(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip(item.dosageForm, EnhancedTheme.accentPurple),
                      if (expired) _chip('Expired', EnhancedTheme.errorRed),
                      if (!expired && item.stock <= item.lowStockThreshold && item.stock > 0)
                        _chip('Low Stock', EnhancedTheme.warningAmber),
                      if (item.stock == 0) _chip('Out of Stock', EnhancedTheme.errorRed),
                      if (!expired && item.stock > item.lowStockThreshold)
                        _chip('In Stock', EnhancedTheme.successGreen),
                    ]),
                  ])),
                ]),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),

          // Key metrics
          Row(children: [
            Expanded(child: _metricCard('Price', '₦${item.price.toStringAsFixed(0)}',
                EnhancedTheme.primaryTeal, Icons.sell_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('Stock', '${item.stock}',
                stockColor, Icons.inventory_2_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('Expiry',
                item.expiryDate != null
                    ? '${item.expiryDate!.month.toString().padLeft(2,'0')}/${item.expiryDate!.year}'
                    : 'N/A',
                expired ? EnhancedTheme.errorRed : EnhancedTheme.accentCyan,
                Icons.event_rounded)),
          ]).animate().fadeIn(duration: 400.ms, delay: 160.ms),
          const SizedBox(height: 20),

          // Product details
          _sectionTitle('Product Details', Icons.info_outline_rounded),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(children: [
                  _detailRow('Dosage Form', item.dosageForm, Icons.medication_rounded, EnhancedTheme.accentPurple),
                  _divider(),
                  _detailRow('Dispensing Unit',
                      item.unitOfDispensing.isNotEmpty ? item.unitOfDispensing : 'N/A',
                      Icons.scale_rounded, EnhancedTheme.accentCyan),
                  _divider(),
                  _detailRow('Barcode', item.barcode, Icons.qr_code_rounded, EnhancedTheme.infoBlue),
                  _divider(),
                  _detailRow('Low Stock Alert', '${item.lowStockThreshold} units',
                      Icons.warning_amber_rounded, EnhancedTheme.warningAmber),
                  _divider(),
                  _detailRow('Stock Status',
                      item.stock == 0 ? 'Out of Stock'
                      : item.stock <= item.lowStockThreshold ? 'Low Stock'
                      : 'In Stock',
                      Icons.circle_rounded,
                      stockColor),
                ]),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 20),

          // Pricing
          _sectionTitle('Pricing', Icons.payments_rounded),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(children: [
                  _detailRow('Retail Price', '₦${item.price.toStringAsFixed(2)}',
                      Icons.sell_rounded, EnhancedTheme.primaryTeal),
                  if (item.costPrice > 0) ...[
                    _divider(),
                    _detailRow('Cost Price', '₦${item.costPrice.toStringAsFixed(2)}',
                        Icons.shopping_bag_rounded, EnhancedTheme.accentCyan),
                    if (item.markup > 0) ...[
                      _divider(),
                      _detailRow('Markup', '${item.markup % 1 == 0 ? item.markup.toInt() : item.markup}%',
                          Icons.percent_rounded, EnhancedTheme.warningAmber),
                    ],
                    _divider(),
                    _detailRow('Margin', '₦${(item.price - item.costPrice).toStringAsFixed(2)}',
                        Icons.trending_up_rounded, EnhancedTheme.successGreen),
                  ],
                ]),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
          const SizedBox(height: 28),

          // Action buttons
          Column(children: [
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _canEdit
                    ? () => _showEditSheet(context, item)
                    : _showNoPermissionSnackBar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const SizedBox.shrink(),
                label: Ink(
                  decoration: BoxDecoration(
                    gradient: _canEdit
                        ? const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan])
                        : null,
                    color: _canEdit ? null : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(_canEdit ? Icons.edit_rounded : Icons.edit_off_rounded,
                          size: 18,
                          color: _canEdit ? Colors.black : context.hintColor),
                      const SizedBox(width: 8),
                      Text('Edit',
                          style: GoogleFonts.outfit(
                              color: _canEdit ? Colors.black : context.hintColor,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                  ),
                ),
              )),
              const SizedBox(width: 14),
              Expanded(child: OutlinedButton.icon(
                onPressed: _canAdjustStock
                    ? () => _showAdjustStockDialog(item)
                    : _showNoAdjustStockPermissionSnackBar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _canAdjustStock
                      ? EnhancedTheme.accentCyan
                      : context.hintColor,
                  side: BorderSide(
                      color: _canAdjustStock
                          ? EnhancedTheme.accentCyan
                          : context.borderColor,
                      width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: Icon(
                    _canAdjustStock ? Icons.tune_rounded : Icons.lock_rounded,
                    size: 18),
                label: Text('Adjust Stock',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
              )),
            ]),
            const SizedBox(height: 12),
            // Transfer stock between branches
            Builder(builder: (ctx) {
              final branches = ref.watch(branchListProvider);
              final active   = ref.watch(activeBranchProvider);
              final hasOther = branches.any((b) => b.id != (active?.id ?? -1));
              if (!hasOther) return const SizedBox.shrink();
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showTransferDialog(context, item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EnhancedTheme.accentPurple,
                    side: const BorderSide(color: EnhancedTheme.accentPurple, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text('Transfer to Branch',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              );
            }),
          ]).animate().fadeIn(duration: 400.ms, delay: 300.ms),
        ]),
      )),
    ]);
  }

  // ── Field helper ─────────────────────────────────────────────────────────

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: context.labelColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.hintColor, fontSize: 13),
        filled: true, fillColor: context.cardColor,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 2)),
        errorStyle: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _metricCard(String label, String value, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.hintColor, fontSize: 10), textAlign: TextAlign.center),
        ]))));

  Widget _detailRow(String label, String value, IconData icon, Color iconColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 14),
      ),
      const SizedBox(width: 12),
      SizedBox(width: 110, child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13))),
      Expanded(child: Text(value,
          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
    ]));

  Widget _sectionTitle(String t, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width: 3, height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, color: EnhancedTheme.primaryTeal, size: 16),
      const SizedBox(width: 8),
      Text(t, style: GoogleFonts.outfit(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700)),
    ]));

  Widget _divider() => Divider(height: 1, color: context.dividerColor, indent: 18, endIndent: 18);

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)));
}
