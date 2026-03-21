import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/models/item.dart';
import '../providers/inventory_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  // Local override updated after stock-adjust / edit saves.
  Item? _itemOverride;

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
    final formKey = GlobalKey<FormState>();
    bool _saving = false;

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Handle
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.edit_rounded, color: EnhancedTheme.primaryTeal, size: 20),
                    const SizedBox(width: 8),
                    Text('Edit Medication', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 20),

                  // Name
                  _field(nameCtrl, 'Item Name *', validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  // Brand
                  _field(brandCtrl, 'Brand / Manufacturer'),
                  const SizedBox(height: 12),
                  // Price + Cost
                  Row(children: [
                    Expanded(child: _field(priceCtrl, 'Retail Price (₦) *',
                        keyboardType: TextInputType.number,
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(costCtrl, 'Cost Price (₦)',
                        keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  // Threshold + Barcode
                  Row(children: [
                    Expanded(child: _field(thresholdCtrl, 'Low Stock Alert *',
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(barcodeCtrl, 'Barcode')),
                  ]),
                  const SizedBox(height: 12),
                  // Expiry date
                  _field(expiryCtrl, 'Expiry Date (YYYY-MM-DD)',
                      keyboardType: TextInputType.datetime,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today_rounded, color: context.hintColor, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: item.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
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
                          if (picked != null) {
                            expiryCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          }
                        },
                      )),
                  const SizedBox(height: 16),

                  // Dosage form chips
                  Text('Dosage Form', style: TextStyle(color: context.hintColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Tablet', 'Capsule', 'Syrup', 'Inhaler', 'Sachet', 'Injection'].map((f) =>
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setModal(() => dosageForm = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: dosageForm == f ? EnhancedTheme.primaryTeal : ctx.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: dosageForm == f ? EnhancedTheme.primaryTeal : ctx.borderColor),
                              ),
                              child: Text(f, style: TextStyle(
                                color: dosageForm == f ? Colors.white : ctx.subLabelColor, fontSize: 12)),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModal(() => _saving = true);
                        final payload = {
                          'name':               nameCtrl.text.trim(),
                          'brand':              brandCtrl.text.trim().isEmpty ? 'Unknown' : brandCtrl.text.trim(),
                          'dosageForm':         dosageForm,
                          'price':              double.parse(priceCtrl.text),
                          'costPrice':          double.tryParse(costCtrl.text) ?? 0,
                          'lowStockThreshold':  int.parse(thresholdCtrl.text),
                          'barcode':            barcodeCtrl.text.trim().isEmpty ? 'N/A' : barcodeCtrl.text.trim(),
                          'expiryDate':         expiryCtrl.text.trim().isEmpty ? null : expiryCtrl.text.trim(),
                        };
                        try {
                          final updated = await ref.read(inventoryApiProvider).updateItem(item.id, payload);
                          ref.invalidate(itemDetailProvider(item.id));
                          ref.invalidate(retailInventoryProvider);
                          ref.invalidate(wholesaleInventoryProvider);
                          setState(() => _itemOverride = updated);
                          if (!context.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('${updated.name} updated successfully'),
                            backgroundColor: EnhancedTheme.successGreen,
                          ));
                        } catch (e) {
                          setModal(() => _saving = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e'), backgroundColor: EnhancedTheme.errorRed,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
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
        backgroundColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Delete Medication', style: TextStyle(color: ctx.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
              style: TextStyle(color: ctx.subLabelColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ctx.subLabelColor,
                  side: BorderSide(color: ctx.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await ref.read(inventoryApiProvider).deleteItem(item.id);
                    ref.invalidate(retailInventoryProvider);
                    ref.invalidate(wholesaleInventoryProvider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${item.name} deleted'),
                      backgroundColor: EnhancedTheme.errorRed,
                    ));
                    context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref));
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'), backgroundColor: EnhancedTheme.errorRed,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.errorRed, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
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
          backgroundColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Adjust Stock', style: TextStyle(color: ctx.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Current stock: $current units', style: TextStyle(color: ctx.hintColor, fontSize: 13)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  onPressed: () => setDialog(() { adjustment--; qtyCtrl.text = adjustment.toString(); }),
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 32)),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextField(
                  controller: qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                  style: TextStyle(color: ctx.labelColor, fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    filled: true, fillColor: ctx.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ctx.borderColor)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setDialog(() => adjustment = int.tryParse(v) ?? 0),
                )),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setDialog(() { adjustment++; qtyCtrl.text = adjustment.toString(); }),
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 32)),
              ]),
              const SizedBox(height: 6),
              Center(child: Text(
                adjustment >= 0 ? '+$adjustment units' : '$adjustment units',
                style: TextStyle(
                  color: adjustment >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 13, fontWeight: FontWeight.w600),
              )),
              const SizedBox(height: 20),
              Text('Reason', style: TextStyle(color: ctx.subLabelColor, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: reasons.map((r) => GestureDetector(
                onTap: () => setDialog(() => reason = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: reason == r ? EnhancedTheme.accentCyan.withValues(alpha: 0.2) : ctx.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: reason == r ? EnhancedTheme.accentCyan : ctx.borderColor),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final updated = await ref.read(inventoryApiProvider).adjustStock(item.id, adjustment, reason);
                      setState(() => _itemOverride = updated);
                      ref.invalidate(itemDetailProvider(item.id));
                      ref.invalidate(retailInventoryProvider);
                      ref.invalidate(wholesaleInventoryProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Stock updated to ${updated.stock} units ($reason)'),
                          backgroundColor: EnhancedTheme.successGreen));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'), backgroundColor: EnhancedTheme.errorRed));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.accentCyan, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
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
        SafeArea(child: itemAsync.when(
          loading: () => Column(children: [
            _header(context, null, null),
            const Expanded(child: Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))),
          ]),
          error: (e, _) => Column(children: [
            _header(context, null, null),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, color: context.hintColor, size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: context.subLabelColor), textAlign: TextAlign.center),
              TextButton(onPressed: () => ref.invalidate(itemDetailProvider(itemId)),
                  child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
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
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
        onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
      ),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item?.name ?? 'Item Details',
            style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(subtitle, style: TextStyle(color: context.hintColor, fontSize: 11)),
      ])),
      if (item != null) ...[
        // Edit button
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: EnhancedTheme.primaryTeal),
          tooltip: 'Edit',
          onPressed: () => _showEditSheet(context, item),
        ),
        // More menu (delete)
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: context.subLabelColor),
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (val) {
            if (val == 'delete') _confirmDelete(context, item);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, color: EnhancedTheme.errorRed, size: 18),
                SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: EnhancedTheme.errorRed, fontSize: 13)),
              ]),
            ),
          ],
        ),
      ],
    ]),
  );

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
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Hero card
          _glassCard(child: Row(children: [
            Container(width: 72, height: 72,
              decoration: BoxDecoration(color: stockColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
              child: Icon(Icons.medication_rounded, color: stockColor, size: 36)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(item.brand, style: TextStyle(color: context.subLabelColor, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _chip(item.dosageForm, EnhancedTheme.primaryTeal),
                const SizedBox(width: 6),
                if (expired) _chip('Expired', EnhancedTheme.errorRed),
                if (!expired && item.stock <= item.lowStockThreshold && item.stock > 0)
                  _chip('Low Stock', EnhancedTheme.warningAmber),
                if (item.stock == 0) _chip('Out of Stock', EnhancedTheme.errorRed),
              ]),
            ])),
          ])),
          const SizedBox(height: 16),

          // Key metrics
          Row(children: [
            Expanded(child: _metricCard('Price', '₦${item.price.toStringAsFixed(0)}', EnhancedTheme.primaryTeal, Icons.sell_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Stock', '${item.stock} units', stockColor, Icons.inventory_2_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Expiry',
                item.expiryDate != null
                    ? '${item.expiryDate!.month.toString().padLeft(2,'0')}/${item.expiryDate!.year}'
                    : 'N/A',
                expired ? EnhancedTheme.errorRed : EnhancedTheme.accentCyan,
                Icons.event_rounded)),
          ]),
          const SizedBox(height: 16),

          // Product details
          _sectionTitle('Product Details'),
          _glassCard(child: Column(children: [
            _detailRow('Dosage Form',     item.dosageForm),
            _divider(),
            _detailRow('Barcode',         item.barcode),
            _divider(),
            _detailRow('Low Stock Alert', '${item.lowStockThreshold} units'),
            _divider(),
            _detailRow('Stock Status',
                item.stock == 0 ? 'Out of Stock'
                : item.stock <= item.lowStockThreshold ? 'Low Stock'
                : 'In Stock'),
          ])),
          const SizedBox(height: 16),

          // Pricing
          _sectionTitle('Pricing'),
          _glassCard(child: Column(children: [
            _detailRow('Price', '₦${item.price.toStringAsFixed(2)}'),
            if (item.costPrice > 0) ...[
              _divider(),
              _detailRow('Cost Price', '₦${item.costPrice.toStringAsFixed(2)}'),
              _divider(),
              _detailRow('Margin', '₦${(item.price - item.costPrice).toStringAsFixed(2)}'),
            ],
          ])),
          const SizedBox(height: 24),

          // Action buttons
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _showEditSheet(context, item),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit'),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _showAdjustStockDialog(item),
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.accentCyan,
                side: const BorderSide(color: EnhancedTheme.accentCyan),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Adjust Stock'),
            )),
          ]),
          const SizedBox(height: 24),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
        errorStyle: const TextStyle(color: EnhancedTheme.errorRed, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardColor,
            borderRadius: BorderRadius.circular(18), border: Border.all(color: context.borderColor)),
        child: child)));

  Widget _metricCard(String label, String value, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.hintColor, fontSize: 10), textAlign: TextAlign.center),
        ]))));

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      SizedBox(width: 130, child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13))),
      Expanded(child: Text(value,
          style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500),
          textAlign: TextAlign.right)),
    ]));

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)));

  Widget _divider() => Divider(height: 1, color: context.dividerColor);

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
}
