import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';
import '../providers/pos_api_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  PAYMENT REQUESTS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class PaymentRequestsScreen extends ConsumerStatefulWidget {
  const PaymentRequestsScreen({super.key});

  @override
  ConsumerState<PaymentRequestsScreen> createState() => _PaymentRequestsScreenState();
}

class _PaymentRequestsScreenState extends ConsumerState<PaymentRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  // Detail state
  Map<String, dynamic>? _selectedRequest;
  List<dynamic> _detailItems = [];
  bool _detailLoading = false;

  static const _filters = ['all', 'pending', 'accepted', 'completed', 'rejected'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = _filter == 'all' ? null : _filter;
      final reqs = await ref.read(posApiProvider).fetchPaymentRequests(status: status);
      if (!mounted) return;
      setState(() { _requests = reqs; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDetail(Map<String, dynamic> request) async {
    setState(() {
      _selectedRequest = request;
      _detailItems = (request['items'] as List<dynamic>?) ?? [];
      _detailLoading = false;
    });
  }

  Future<void> _acceptRequest(int id) async {
    try {
      await ref.read(posApiProvider).acceptPaymentRequest(id);
      if (!mounted) return;
      _showSnack('Request accepted', EnhancedTheme.successGreen);
      setState(() => _selectedRequest = null);
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to accept: $e');
    }
  }

  Future<void> _rejectRequest(int id) async {
    try {
      await ref.read(posApiProvider).rejectPaymentRequest(id);
      if (!mounted) return;
      _showSnack('Request rejected', EnhancedTheme.errorRed);
      setState(() => _selectedRequest = null);
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to reject: $e');
    }
  }

  Future<void> _completeRequest(int id) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _CompletePaymentDialog(
        requestId: id,
        totalAmount: (_selectedRequest?['totalAmount'] as num?)?.toDouble() ?? 0,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(posApiProvider).completePaymentRequest(
        id,
        result['payment'] as Map<String, dynamic>,
        result['paymentMethod'] as String,
      );
      if (!mounted) return;
      _showSnack('Payment completed', EnhancedTheme.successGreen);
      setState(() => _selectedRequest = null);
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to complete: $e');
    }
  }

  void _showSnack(String msg, Color color) {
    final isError = color == EnhancedTheme.errorRed;
    final isSuccess = color == EnhancedTheme.successGreen;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(
          isError ? Icons.error_rounded : isSuccess ? Icons.check_circle_rounded : Icons.info_rounded,
          color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  void _showError(String msg) => _showSnack(msg, EnhancedTheme.errorRed);

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':   return EnhancedTheme.warningAmber;
      case 'accepted':  return EnhancedTheme.infoBlue;
      case 'completed': return EnhancedTheme.successGreen;
      case 'rejected':  return EnhancedTheme.errorRed;
      default:          return context.subLabelColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':   return Icons.hourglass_empty_rounded;
      case 'accepted':  return Icons.check_circle_outline_rounded;
      case 'completed': return Icons.verified_rounded;
      case 'rejected':  return Icons.cancel_rounded;
      default:          return Icons.help_outline_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':   return 'Pending';
      case 'accepted':  return 'Accepted';
      case 'completed': return 'Completed';
      case 'rejected':  return 'Rejected';
      default:          return status;
    }
  }

  // ── Detail View ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_selectedRequest != null) return _buildDetail();
    return _buildList();
  }

  Widget _buildDetail() {
    final req = _selectedRequest!;
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final status = (req['status'] as String?) ?? 'unknown';
    final dispenser = (req['dispenserName'] as String?) ?? (req['dispenser'] as String?) ?? 'Unknown';
    final customer = (req['customerName'] as String?) ?? (req['customer'] as String?) ?? 'Walk-in';
    final totalAmount = (req['totalAmount'] as num?)?.toDouble() ?? 0;
    final date = (req['createdAt'] as String?) ?? '';
    final color = _statusColor(status);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blob
        Positioned(top: -40, right: -30,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: color.withValues(alpha: 0.06)))),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: context.labelColor, size: 20),
                  onPressed: () => setState(() { _selectedRequest = null; _detailItems = []; }),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Request #$id',
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('$dispenser → $customer', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ])),
              _statusBadge(status, color),
            ]),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),

          // Summary card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      EnhancedTheme.primaryTeal.withValues(alpha: 0.08),
                      context.cardColor,
                    ]),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Amount', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('₦${totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                              color: EnhancedTheme.primaryTeal, fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.calendar_today_rounded, size: 11, color: EnhancedTheme.accentCyan),
                        const SizedBox(width: 4),
                        Text(date, style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 11)),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EnhancedTheme.primaryTeal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_rounded, color: EnhancedTheme.primaryTeal, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text('${_detailItems.length}',
                          style: GoogleFonts.outfit(color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('items', style: TextStyle(color: context.hintColor, fontSize: 11)),
                    ]),
                  ]),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),

          // Action buttons
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _acceptRequest(id),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text('Accept', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _rejectRequest(id),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.errorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
              ]),
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
          if (status == 'accepted')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => _completeRequest(id),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text('Complete Payment', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
          if (status == 'pending' || status == 'accepted') const SizedBox(height: 12),

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(width: 3, height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(width: 10),
              Text('Items',
                  style: GoogleFonts.outfit(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_detailItems.length} items',
                  style: TextStyle(color: context.hintColor, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),

          // Items list
          Expanded(child: _detailLoading
              ? const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))
              : _detailItems.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, color: context.hintColor, size: 40),
                      const SizedBox(height: 12),
                      Text('No items in this request',
                          style: TextStyle(color: context.subLabelColor, fontSize: 14)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: _detailItems.length,
                      itemBuilder: (_, i) => _detailItemCard(_detailItems[i])
                          .animate(delay: (i * 50).ms)
                          .fadeIn(duration: 300.ms)
                          .slideX(begin: 0.05, end: 0),
                    )),
        ])),
      ]),
    );
  }

  Widget _statusBadge(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_statusIcon(status), color: color, size: 14),
      const SizedBox(width: 5),
      Text(_statusLabel(status),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _detailItemCard(dynamic item) {
    final name = (item['itemName'] as String?) ?? (item['name'] as String?) ?? 'Unknown Item';
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (price * qty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.05),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.medication_rounded, color: EnhancedTheme.primaryTeal, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('₦${price.toStringAsFixed(2)}',
                      style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                  Text(' × $qty',
                      style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ])),
              Text('₦${subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                      color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── List View ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    // Count by status
    final pendingCount = _requests.where((r) => r['status'] == 'pending').length;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        // Decorative blobs
        Positioned(top: -50, right: -30,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.06)))),
        Positioned(bottom: 80, left: -50,
          child: Container(width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: EnhancedTheme.accentPurple.withValues(alpha: 0.05)))),
        SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
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
                Text('Payment Requests',
                    style: GoogleFonts.outfit(color: context.labelColor, fontSize: 22, fontWeight: FontWeight.w800)),
                Text('Review & process requests', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ])),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.hourglass_empty_rounded, color: EnhancedTheme.warningAmber, size: 12),
                    const SizedBox(width: 4),
                    Text('$pendingCount',
                        style: const TextStyle(color: EnhancedTheme.warningAmber, fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
            ]),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
          const SizedBox(height: 14),

          // Filter chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _filterChip(_filters[i]),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 14),

          // List
          Expanded(child: _loading
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EnhancedTheme.loadingShimmer(height: 100, radius: 18),
                  )),
                )
              : _error != null
                  ? _errorState()
                  : _requests.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: EnhancedTheme.primaryTeal,
                          onRefresh: _loadRequests,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) => _requestCard(_requests[i])
                                .animate(delay: (i * 50).ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.05, end: 0),
                          ),
                        )),
        ])),
      ]),
    );
  }

  Widget _filterChip(String label) {
    final active = _filter == label;
    final labelCapitalized = label[0].toUpperCase() + label.substring(1);
    Color? chipColor;
    if (label != 'all') chipColor = _statusColor(label);

    return GestureDetector(
      onTap: () {
        setState(() => _filter = label);
        _loadRequests();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? (chipColor ?? EnhancedTheme.primaryTeal).withValues(alpha: 0.12)
              : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? (chipColor ?? EnhancedTheme.primaryTeal)
                : context.borderColor,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: (chipColor ?? EnhancedTheme.primaryTeal).withValues(alpha: 0.2),
                  blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (label != 'all') ...[
            Icon(_statusIcon(label),
                color: active ? (chipColor ?? EnhancedTheme.primaryTeal) : context.hintColor, size: 13),
            const SizedBox(width: 5),
          ],
          Text(labelCapitalized, style: TextStyle(
            color: active ? (chipColor ?? EnhancedTheme.primaryTeal) : context.subLabelColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          )),
        ]),
      ),
    );
  }

  Widget _requestCard(dynamic req) {
    final id = (req['id'] as num?)?.toInt() ?? 0;
    final status = (req['status'] as String?) ?? 'unknown';
    final dispenser = (req['dispenserName'] as String?) ?? (req['dispenser'] as String?) ?? 'Unknown';
    final customer = (req['customerName'] as String?) ?? (req['customer'] as String?) ?? 'Walk-in';
    final totalAmount = (req['totalAmount'] as num?)?.toDouble() ?? 0;
    final date = (req['createdAt'] as String?) ?? '';
    final color = _statusColor(status);
    final itemCount = ((req['items'] as List<dynamic>?)?.length ?? 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _loadDetail(req),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: status == 'pending' ? EnhancedTheme.warningAmber.withValues(alpha: 0.3)
                        : context.borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Request icon
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(_statusIcon(status), color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Request #$id',
                        style: GoogleFonts.outfit(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(date, style: TextStyle(color: context.hintColor, fontSize: 12)),
                  ])),
                  _statusBadge(status, color),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    Icon(Icons.medication_rounded, color: context.hintColor, size: 14),
                    const SizedBox(width: 6),
                    Text('$itemCount items', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 12, color: context.dividerColor),
                    const SizedBox(width: 10),
                    Icon(Icons.person_outline_rounded, color: context.hintColor, size: 14),
                    const SizedBox(width: 4),
                    Expanded(child: Text('$dispenser → $customer',
                        style: TextStyle(color: context.subLabelColor, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('₦${totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                          color: EnhancedTheme.primaryTeal, fontSize: 20, fontWeight: FontWeight.w900)),
                  Row(children: [
                    Text('View details',
                        style: const TextStyle(color: EnhancedTheme.accentCyan, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, color: EnhancedTheme.accentCyan, size: 12),
                  ]),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [
            EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
            EnhancedTheme.primaryTeal.withValues(alpha: 0.03),
          ]),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.receipt_long_outlined, color: EnhancedTheme.primaryTeal, size: 56),
      ),
      const SizedBox(height: 20),
      Text('No payment requests',
          style: GoogleFonts.outfit(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        _filter == 'all' ? 'No requests found' : 'No $_filter requests found',
        style: TextStyle(color: context.subLabelColor, fontSize: 13),
      ),
    ]).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)));
  }

  Widget _errorState() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded, color: EnhancedTheme.errorRed, size: 40),
        ),
        const SizedBox(height: 20),
        Text('Something went wrong',
            style: GoogleFonts.outfit(color: context.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_error ?? '', style: TextStyle(color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loadRequests,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text('Retry', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedTheme.primaryTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]).animate().fadeIn(duration: 400.ms),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  COMPLETE PAYMENT DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _CompletePaymentDialog extends StatefulWidget {
  final int requestId;
  final double totalAmount;
  const _CompletePaymentDialog({required this.requestId, required this.totalAmount});

  @override
  State<_CompletePaymentDialog> createState() => _CompletePaymentDialogState();
}

class _CompletePaymentDialogState extends State<_CompletePaymentDialog> {
  String _method = 'cash';
  final _cashCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _transferCtrl = TextEditingController();
  final _walletCtrl = TextEditingController();

  static const _methods = [
    {'key': 'cash',   'label': 'Cash',   'icon': Icons.payments_rounded},
    {'key': 'pos',    'label': 'POS',    'icon': Icons.credit_card_rounded},
    {'key': 'transfer', 'label': 'Transfer', 'icon': Icons.swap_horiz_rounded},
    {'key': 'wallet', 'label': 'Wallet', 'icon': Icons.account_balance_wallet_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _cashCtrl.text = widget.totalAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _posCtrl.dispose();
    _transferCtrl.dispose();
    _walletCtrl.dispose();
    super.dispose();
  }

  void _selectMethod(String key) {
    setState(() {
      _method = key;
      _cashCtrl.text = '';
      _posCtrl.text = '';
      _transferCtrl.text = '';
      _walletCtrl.text = '';
      switch (key) {
        case 'cash':     _cashCtrl.text = widget.totalAmount.toStringAsFixed(2); break;
        case 'pos':      _posCtrl.text = widget.totalAmount.toStringAsFixed(2); break;
        case 'transfer': _transferCtrl.text = widget.totalAmount.toStringAsFixed(2); break;
        case 'wallet':   _walletCtrl.text = widget.totalAmount.toStringAsFixed(2); break;
      }
    });
  }

  void _confirm() {
    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    final pos = double.tryParse(_posCtrl.text) ?? 0;
    final transfer = double.tryParse(_transferCtrl.text) ?? 0;
    final wallet = double.tryParse(_walletCtrl.text) ?? 0;

    Navigator.pop(context, {
      'paymentMethod': _method,
      'payment': {
        'cash': cash,
        'pos': pos,
        'bankTransfer': transfer,
        'wallet': wallet,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EnhancedTheme.surfaceColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40, offset: const Offset(0, 16))],
            ),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [EnhancedTheme.primaryTeal, EnhancedTheme.accentCyan]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Complete Payment',
                      style: GoogleFonts.outfit(color: context.labelColor, fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('Select payment method', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 16),

              // Amount display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                    EnhancedTheme.accentCyan.withValues(alpha: 0.06),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Amount Due', style: TextStyle(color: context.hintColor, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('₦${widget.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                          color: EnhancedTheme.primaryTeal, fontSize: 24, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 20),

              // Method selector
              Text('Payment Method', style: TextStyle(color: context.subLabelColor, fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.8,
                children: _methods.map((m) {
                  final key = m['key'] as String;
                  final active = _method == key;
                  return GestureDetector(
                    onTap: () => _selectMethod(key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: active
                            ? LinearGradient(colors: [
                                EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                                EnhancedTheme.accentCyan.withValues(alpha: 0.1),
                              ])
                            : null,
                        color: active ? null : context.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? EnhancedTheme.primaryTeal : context.borderColor,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(m['icon'] as IconData,
                            color: active ? EnhancedTheme.primaryTeal : context.subLabelColor, size: 16),
                        const SizedBox(width: 6),
                        Text(m['label'] as String, style: TextStyle(
                          color: active ? EnhancedTheme.primaryTeal : context.subLabelColor,
                          fontSize: 13, fontWeight: FontWeight.w700,
                        )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Amount inputs
              Text('Amount Breakdown', style: TextStyle(color: context.subLabelColor, fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              _amountField('Cash', _cashCtrl, Icons.payments_rounded),
              const SizedBox(height: 8),
              _amountField('POS', _posCtrl, Icons.credit_card_rounded),
              const SizedBox(height: 8),
              _amountField('Transfer', _transferCtrl, Icons.swap_horiz_rounded),
              const SizedBox(height: 8),
              _amountField('Wallet', _walletCtrl, Icons.account_balance_wallet_rounded),
              const SizedBox(height: 24),

              // Actions
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.subLabelColor,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [EnhancedTheme.successGreen, Color(0xFF059669)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('Confirm Payment',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                )),
              ]),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _amountField(String label, TextEditingController ctrl, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderColor),
        ),
        child: Icon(icon, color: context.hintColor, size: 16),
      ),
      const SizedBox(width: 10),
      SizedBox(width: 72, child: Text(label,
          style: TextStyle(color: context.subLabelColor, fontSize: 13, fontWeight: FontWeight.w500))),
      Expanded(child: SizedBox(
        height: 44,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true,
            prefixText: '₦ ',
            prefixStyle: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 13, fontWeight: FontWeight.w600),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 2),
            ),
          ),
        ),
      )),
    ]);
  }
}
