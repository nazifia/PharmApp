import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/network_provider.dart';

class MedicationAvailabilityScreen extends ConsumerStatefulWidget {
  final String drugName;
  const MedicationAvailabilityScreen({super.key, required this.drugName});

  @override
  ConsumerState<MedicationAvailabilityScreen> createState() =>
      _MedicationAvailabilityScreenState();
}

class _MedicationAvailabilityScreenState
    extends ConsumerState<MedicationAvailabilityScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availAsync =
        ref.watch(drugAvailabilityProvider(widget.drugName));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.black87, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Network Availability',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              widget.drugName,
                              style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Search bar ───────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 14),
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Filter pharmacies…',
                            hintStyle: const TextStyle(
                                color: Colors.black38, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Colors.black38, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.black38, size: 18),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Drug info banner ─────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          EnhancedTheme.primaryTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: EnhancedTheme.primaryTeal
                              .withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.medication_rounded,
                            color: EnhancedTheme.primaryTeal,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.drugName,
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                              const Text(
                                'Showing stock levels across your pharmacy network',
                                style: TextStyle(
                                    color: Colors.black45, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // ── Results ──────────────────────────────────────────────────
                Expanded(
                  child: availAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: EnhancedTheme.primaryTeal),
                    ),
                    error: (e, _) => _ErrorView(
                      message: e.toString(),
                      onRetry: () =>
                          ref.invalidate(drugAvailabilityProvider(widget.drugName)),
                    ),
                    data: (list) {
                      final filtered = _searchQuery.isEmpty
                          ? list
                          : list
                              .where((a) => a.pharmacyName
                                  .toLowerCase()
                                  .contains(_searchQuery))
                              .toList();

                      if (list.isEmpty) {
                        return _EmptyView(drugName: widget.drugName);
                      }
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  color: Colors.black26, size: 44),
                              SizedBox(height: 12),
                              Text(
                                'No pharmacies match your search.',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: EnhancedTheme.primaryTeal,
                        onRefresh: () async =>
                            ref.invalidate(drugAvailabilityProvider(widget.drugName)),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            return _PharmacyAvailabilityCard(
                              availability: item,
                            )
                                .animate()
                                .fadeIn(
                                    delay: Duration(milliseconds: i * 40))
                                .slideY(begin: 0.04, end: 0);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pharmacy availability card ─────────────────────────────────────────────────

class _PharmacyAvailabilityCard extends StatelessWidget {
  final DrugAvailability availability;
  const _PharmacyAvailabilityCard({required this.availability});

  @override
  Widget build(BuildContext context) {
    final qty = availability.stockQuantity;
    final Color stockColor;
    final String stockLabel;
    final IconData stockIcon;

    if (qty > 10) {
      stockColor = EnhancedTheme.successGreen;
      stockLabel = 'In Stock';
      stockIcon = Icons.check_circle_rounded;
    } else if (qty > 0) {
      stockColor = EnhancedTheme.warningAmber;
      stockLabel = 'Low Stock';
      stockIcon = Icons.warning_amber_rounded;
    } else {
      stockColor = EnhancedTheme.errorRed;
      stockLabel = 'Out of Stock';
      stockIcon = Icons.remove_shopping_cart_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 1.2),
            ),
            child: Row(
              children: [
                // Pharmacy icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.local_pharmacy_rounded,
                    color: stockColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Pharmacy details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        availability.pharmacyName,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      if (availability.address != null &&
                          availability.address!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 12, color: Colors.black38),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                availability.address!,
                                style: const TextStyle(
                                    color: Colors.black45, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (availability.phone != null &&
                          availability.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded,
                                size: 12, color: Colors.black38),
                            const SizedBox(width: 3),
                            Text(
                              availability.phone!,
                              style: const TextStyle(
                                  color: Colors.black45, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                      if (availability.distance != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.directions_walk_rounded,
                                size: 12, color: Colors.black38),
                            const SizedBox(width: 3),
                            Text(
                              availability.distance!,
                              style: const TextStyle(
                                  color: Colors.black45, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Stock indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: stockColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(stockIcon, color: stockColor, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            stockLabel,
                            style: TextStyle(
                                color: stockColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Quantity badge
                    Text(
                      qty > 0 ? '$qty units' : 'None',
                      style: TextStyle(
                          color: stockColor.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String drugName;
  const _EmptyView({required this.drugName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.search_off_rounded,
                  color: Colors.black26, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Not found in network',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'No network pharmacies currently stock "$drugName".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EnhancedTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Colors.black38, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Could not load availability',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EnhancedTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
