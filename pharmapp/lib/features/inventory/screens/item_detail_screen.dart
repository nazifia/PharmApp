import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  int _currentStock = 5; // mirrors mock item's initial stock

  void _showAdjustStockDialog() {
    int adjustment    = 0;
    String reason     = 'Purchase';
    final qtyCtrl     = TextEditingController();
    final reasons     = ['Purchase', 'Return', 'Correction', 'Damage', 'Expiry'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Adjust Stock', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Current stock: $_currentStock units',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 20),

              // +/- quantity row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  onPressed: () => setDialog(() { adjustment--; qtyCtrl.text = adjustment.toString(); }),
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 32),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setDialog(() => adjustment = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setDialog(() { adjustment++; qtyCtrl.text = adjustment.toString(); }),
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 32),
                ),
              ]),
              const SizedBox(height: 6),
              Center(child: Text(
                adjustment >= 0 ? '+$adjustment units' : '$adjustment units',
                style: TextStyle(
                  color: adjustment >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontSize: 13, fontWeight: FontWeight.w600),
              )),
              const SizedBox(height: 20),

              // Reason
              Text('Reason', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: reasons.map((r) => GestureDetector(
                onTap: () => setDialog(() => reason = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: reason == r ? EnhancedTheme.accentCyan.withOpacity(0.2) : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: reason == r ? EnhancedTheme.accentCyan : Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(r, style: TextStyle(
                    color: reason == r ? EnhancedTheme.accentCyan : Colors.white54,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )).toList()),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    final newStock = (_currentStock + adjustment).clamp(0, 99999);
                    setState(() => _currentStock = newStock);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Stock updated to $newStock units ($reason)'),
                      backgroundColor: EnhancedTheme.successGreen,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.accentCyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
    final itemId = GoRouterState.of(context).pathParameters['id'] ?? '0';

    // Mock item data – in production, fetch from provider/API using itemId
    final item = {
      'id': int.tryParse(itemId) ?? 1,
      'name': 'Paracetamol 500mg',
      'brand': 'Cipla Ltd',
      'form': 'Tablet',
      'generic': 'Acetaminophen',
      'category': 'Analgesic / Antipyretic',
      'barcode': '8901234567890',
      'batch': 'BATCH-2024-001',
      'unit': 'Strip',
      'packageSize': '10 Tablets',
      'price': 75.0,
      'wholesale': 60.0,
      'cost': 45.0,
      'stock': _currentStock,
      'low': 20,
      'expiry': 'Dec 2026',
      'storage': 'Room Temperature (<25°C)',
      'rx': false,
      'description': 'Paracetamol 500mg tablets for relief of mild to moderate pain and fever.',
    };

    final stockColor = _currentStock == 0
        ? EnhancedTheme.errorRed
        : _currentStock <= 20
            ? EnhancedTheme.warningAmber
            : EnhancedTheme.successGreen;

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0,0.5,1]))),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
                    Expanded(child: Text(item['name'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Edit item – coming soon'))),
                    ),
                  ]),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Hero card
                      _glassCard(child: Row(children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(Icons.medication_rounded, color: stockColor, size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(item['brand'] as String, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, children: [
                            _chip(item['form'] as String, EnhancedTheme.primaryTeal),
                            if (item['rx'] as bool) _chip('Rx', EnhancedTheme.accentPurple),
                          ]),
                        ])),
                      ])),
                      const SizedBox(height: 16),

                      // Key metrics
                      Row(children: [
                        Expanded(child: _metricCard('Retail Price', '₹${(item['price'] as double).toStringAsFixed(0)}', EnhancedTheme.primaryTeal, Icons.sell)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricCard('Stock', '${item['stock']} units', stockColor, Icons.inventory_2)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricCard('Expiry', item['expiry'] as String, EnhancedTheme.accentCyan, Icons.event)),
                      ]),
                      const SizedBox(height: 16),

                      // Details
                      _sectionTitle('Product Details'),
                      _glassCard(child: Column(children: [
                        _detailRow('Generic Name',   item['generic'] as String),
                        _divider(),
                        _detailRow('Category',       item['category'] as String),
                        _divider(),
                        _detailRow('Dosage Form',    item['form'] as String),
                        _divider(),
                        _detailRow('Package',        item['packageSize'] as String),
                        _divider(),
                        _detailRow('Unit',           item['unit'] as String),
                        _divider(),
                        _detailRow('Barcode',        item['barcode'] as String),
                        _divider(),
                        _detailRow('Batch No.',      item['batch'] as String),
                        _divider(),
                        _detailRow('Storage',        item['storage'] as String),
                      ])),
                      const SizedBox(height: 16),

                      // Pricing
                      _sectionTitle('Pricing'),
                      _glassCard(child: Column(children: [
                        _detailRow('Cost Price',       '₹${(item['cost'] as double).toStringAsFixed(2)}'),
                        _divider(),
                        _detailRow('Retail Price',     '₹${(item['price'] as double).toStringAsFixed(2)}'),
                        _divider(),
                        _detailRow('Wholesale Price',  '₹${(item['wholesale'] as double).toStringAsFixed(2)}'),
                        _divider(),
                        _detailRow('Profit Margin',
                            '${(((item['price'] as double) - (item['cost'] as double)) / (item['cost'] as double) * 100).toStringAsFixed(1)}%'),
                      ])),
                      const SizedBox(height: 16),

                      // Description
                      _sectionTitle('Description'),
                      _glassCard(child: Text(item['description'] as String,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.6))),
                      const SizedBox(height: 24),

                      // Actions
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EnhancedTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                            label: const Text('Add to Cart'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showAdjustStockDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EnhancedTheme.accentCyan,
                              side: const BorderSide(color: EnhancedTheme.accentCyan),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('Adjust Stock'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.11)),
        ),
        child: child,
      ),
    ),
  );

  Widget _metricCard(String label, String value, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
    ]),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
  );

  Widget _divider() => Divider(height: 1, color: Colors.white.withOpacity(0.07));

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
