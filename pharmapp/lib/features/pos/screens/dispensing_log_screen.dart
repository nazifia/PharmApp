import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/pos_api_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final dispensingStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(posApiProvider).fetchDispensingStats();
});

final dispensingLogProvider = FutureProvider.autoDispose.family<List<dynamic>, DispensingLogParams>((ref, params) {
  return ref.watch(posApiProvider).fetchDispensingLog(
    search: params.search,
    from: params.from,
    to: params.to,
  );
});

class DispensingLogParams {
  final String? search;
  final String? from;
  final String? to;
  const DispensingLogParams({this.search, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is DispensingLogParams &&
      other.search == search && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(search, from, to);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class DispensingLogScreen extends ConsumerStatefulWidget {
  const DispensingLogScreen({super.key});

  @override
  ConsumerState<DispensingLogScreen> createState() => _DispensingLogScreenState();
}

class _DispensingLogScreenState extends ConsumerState<DispensingLogScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _dateFilter = 0; // 0=Today, 1=Week, 2=Month, 3=All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DispensingLogParams get _params {
    final now = DateTime.now();
    String? from;
    String? to;
    switch (_dateFilter) {
      case 0: // Today
        from = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
        to = now.toIso8601String().split('T').first;
        break;
      case 1: // This Week
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String().split('T').first;
        to = now.toIso8601String().split('T').first;
        break;
      case 2: // This Month
        from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
        to = now.toIso8601String().split('T').first;
        break;
      default: // All
        break;
    }
    return DispensingLogParams(search: _searchQuery.isEmpty ? null : _searchQuery, from: from, to: to);
  }

  Future<void> _refresh() async {
    ref.invalidate(dispensingStatsProvider);
    ref.invalidate(dispensingLogProvider(_params));
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dispensingStatsProvider);
    final logAsync = ref.watch(dispensingLogProvider(_params));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _header(context),
          _statsRow(statsAsync),
          _searchBar(context),
          _dateFilterChips(),
          Expanded(child: RefreshIndicator(
            color: EnhancedTheme.primaryTeal,
            onRefresh: _refresh,
            child: _logList(logAsync),
          )),
        ])),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(children: [
      IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dispensing Log',
            style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
        Text('Track all dispensed medications',
            style: TextStyle(color: context.subLabelColor, fontSize: 11)),
      ])),
    ]),
  );

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _statsRow(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: statsAsync.when(
        loading: () => Row(children: [
          Expanded(child: EnhancedTheme.loadingShimmer(height: 72, radius: 14)),
          const SizedBox(width: 10),
          Expanded(child: EnhancedTheme.loadingShimmer(height: 72, radius: 14)),
          const SizedBox(width: 10),
          Expanded(child: EnhancedTheme.loadingShimmer(height: 72, radius: 14)),
          const SizedBox(width: 10),
          Expanded(child: EnhancedTheme.loadingShimmer(height: 72, radius: 14)),
        ]),
        error: (e, _) => const SizedBox.shrink(),
        data: (stats) {
          final dailyCount = stats['dailyCount'] ?? 0;
          final dailyRevenue = (stats['dailyRevenue'] as num?)?.toDouble() ?? 0;
          final monthlyCount = stats['monthlyCount'] ?? 0;
          final monthlyRevenue = (stats['monthlyRevenue'] as num?)?.toDouble() ?? 0;
          return Row(children: [
            Expanded(child: _statCard('$dailyCount', 'Daily\nCount', EnhancedTheme.primaryTeal, Icons.today_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(_fmtNaira(dailyRevenue), 'Daily\nRevenue', EnhancedTheme.accentCyan, Icons.payments_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('$monthlyCount', 'Monthly\nCount', EnhancedTheme.accentPurple, Icons.calendar_month_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(_fmtNaira(monthlyRevenue), 'Monthly\nRevenue', EnhancedTheme.successGreen, Icons.trending_up_rounded)),
          ]);
        },
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(color: context.hintColor, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ),
    ),
  );

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _searchBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      style: TextStyle(color: context.labelColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by name or brand...',
        hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: context.hintColor, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: context.hintColor, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: context.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );

  // ── Date Filter Chips ──────────────────────────────────────────────────────

  Widget _dateFilterChips() {
    const filters = ['Today', 'This Week', 'This Month', 'All'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(children: filters.asMap().entries.map((e) {
        final active = e.key == _dateFilter;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _dateFilter = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? EnhancedTheme.primaryTeal : context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? EnhancedTheme.primaryTeal : context.borderColor,
              ),
            ),
            child: Text(e.value, textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? Colors.white : context.subLabelColor,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ));
      }).toList()),
    );
  }

  // ── Log List ───────────────────────────────────────────────────────────────

  Widget _logList(AsyncValue<List<dynamic>> logAsync) {
    return logAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EnhancedTheme.loadingShimmer(height: 80, radius: 16),
        ),
      ),
      error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
        const SizedBox(height: 12),
        Text('$e', style: TextStyle(color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _refresh,
          child: const Text('Retry', style: TextStyle(color: EnhancedTheme.primaryTeal)),
        ),
      ])),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inbox_rounded, color: context.hintColor, size: 56),
            const SizedBox(height: 12),
            Text('No dispensing records found',
                style: TextStyle(color: context.subLabelColor, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Try a different date range or search term',
                style: TextStyle(color: context.hintColor, fontSize: 12)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (_, i) => _logEntryCard(entries[i] as Map<String, dynamic>),
        );
      },
    );
  }

  Widget _logEntryCard(Map<String, dynamic> entry) {
    final name = entry['name'] as String? ?? entry['itemName'] as String? ?? 'Unknown';
    final brand = entry['brand'] as String? ?? '';
    final quantity = entry['quantity'] ?? 0;
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final status = (entry['status'] as String? ?? 'dispensed').toLowerCase();
    final dateStr = entry['createdAt'] as String? ?? entry['date'] as String? ?? entry['dispensedAt'] as String? ?? '';
    final dispenser = entry['dispenser'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'returned':
        statusColor = EnhancedTheme.errorRed;
        statusLabel = 'Returned';
        break;
      case 'partially_returned':
      case 'partial':
        statusColor = EnhancedTheme.warningAmber;
        statusLabel = 'Partial';
        break;
      default:
        statusColor = EnhancedTheme.successGreen;
        statusLabel = 'Dispensed';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication_rounded, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (brand.isNotEmpty)
                    Text(brand, style: TextStyle(color: context.subLabelColor, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmtNaira(amount),
                      style: const TextStyle(color: EnhancedTheme.primaryTeal,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.shopping_bag_outlined, color: context.hintColor, size: 12),
                const SizedBox(width: 4),
                Text('Qty: $quantity', style: TextStyle(color: context.hintColor, fontSize: 11)),
                if (dispenser.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline_rounded, color: context.hintColor, size: 12),
                  const SizedBox(width: 4),
                  Flexible(child: Text(dispenser,
                      style: TextStyle(color: context.hintColor, fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
                ],
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time_rounded, color: context.hintColor, size: 12),
                  const SizedBox(width: 4),
                  Text(_formatTimestamp(dateStr),
                      style: TextStyle(color: context.hintColor, fontSize: 11)),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtNaira(double v) {
    if (v >= 1000000) return '₦${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₦${(v / 1000).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }

  String _formatTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, $hour:$minute';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}
