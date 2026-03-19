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
  // Local stock override — updated after a successful adjust-stock API call.
  int? _stockOverride;

  void _showAdjustStockDialog(Item item) {
    int adjustment = 0;
    String reason  = 'Purchase';
    final qtyCtrl  = TextEditingController();
    final reasons  = ['Purchase', 'Return', 'Correction', 'Damage', 'Expiry'];
    final current  = _stockOverride ?? item.stock;

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
              Text('Current stock: $current units',
                  style: TextStyle(color: ctx.hintColor, fontSize: 13)),
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
                      setState(() => _stockOverride = updated.stock);
                      ref.invalidate(itemDetailProvider(item.id));
                      ref.invalidate(inventoryListProvider);
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
            _header(context, null),
            const Expanded(child: Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))),
          ]),
          error: (e, _) => Column(children: [
            _header(context, null),
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, color: context.hintColor, size: 48),
              const SizedBox(height: 12),
              Text('$e', style: TextStyle(color: context.subLabelColor), textAlign: TextAlign.center),
              TextButton(onPressed: () => ref.invalidate(itemDetailProvider(itemId)),
                  child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal))),
            ]))),
          ]),
          data: (item) => _buildContent(context, item),
        )),
      ]),
    );
  }

  Widget _header(BuildContext context, Item? item) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
      Expanded(child: Text(item?.name ?? 'Item Details',
          style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _buildContent(BuildContext context, Item item) {
    final stock = _stockOverride ?? item.stock;
    final now   = DateTime.now();
    final expired = item.expiryDate != null && item.expiryDate!.isBefore(now);
    final stockColor = stock == 0
        ? EnhancedTheme.errorRed
        : stock <= item.lowStockThreshold
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.successGreen;

    return Column(children: [
      _header(context, item),
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
              _chip(item.dosageForm, EnhancedTheme.primaryTeal),
            ])),
          ])),
          const SizedBox(height: 16),

          // Key metrics
          Row(children: [
            Expanded(child: _metricCard('Retail Price', '₦${item.price.toStringAsFixed(0)}', EnhancedTheme.primaryTeal, Icons.sell)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Stock', '$stock units', stockColor, Icons.inventory_2)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Expiry',
                item.expiryDate != null ? '${item.expiryDate!.month}/${item.expiryDate!.year}' : 'N/A',
                expired ? EnhancedTheme.errorRed : EnhancedTheme.accentCyan, Icons.event)),
          ]),
          const SizedBox(height: 16),

          // Details
          _sectionTitle('Product Details'),
          _glassCard(child: Column(children: [
            _detailRow('Dosage Form',       item.dosageForm),
            _divider(),
            _detailRow('Barcode',           item.barcode),
            _divider(),
            _detailRow('Low Stock Alert',   '${item.lowStockThreshold} units'),
            _divider(),
            _detailRow('Stock Status',      stock == 0 ? 'Out of Stock' : stock <= item.lowStockThreshold ? 'Low Stock' : 'In Stock'),
          ])),
          const SizedBox(height: 16),

          // Pricing
          _sectionTitle('Pricing'),
          _glassCard(child: Column(children: [
            _detailRow('Retail Price', '₦${item.price.toStringAsFixed(2)}'),
          ])),
          const SizedBox(height: 24),

          // Actions
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Add to Cart'),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _showAdjustStockDialog(item),
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.accentCyan, side: const BorderSide(color: EnhancedTheme.accentCyan),
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
      SizedBox(width: 120, child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13))),
      Expanded(child: Text(value, style: TextStyle(color: context.labelColor, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
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
