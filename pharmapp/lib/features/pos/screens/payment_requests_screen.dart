import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
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
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => setState(() { _selectedRequest = null; _detailItems = []; }),
              ),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Request #$id', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('$dispenser → $customer · $date', style: TextStyle(color: context.subLabelColor, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Summary card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Amount', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('₦${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 24, fontWeight: FontWeight.w800)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${_detailItems.length}', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('items', style: TextStyle(color: context.hintColor, fontSize: 11)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action buttons
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _acceptRequest(id),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _rejectRequest(id),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.errorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
              ]),
            ),
          if (status == 'accepted')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => _completeRequest(id),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Complete Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnhancedTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ),
          if (status == 'pending' || status == 'accepted') const SizedBox(height: 8),

          // Items list
          Expanded(child: _detailLoading
              ? const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))
              : _detailItems.isEmpty
                  ? Center(child: Text('No items', style: TextStyle(color: context.subLabelColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _detailItems.length,
                      itemBuilder: (_, i) => _detailItemCard(_detailItems[i]),
                    )),
        ])),
      ]),
    );
  }

  Widget _detailItemCard(dynamic item) {
    final name = (item['itemName'] as String?) ?? (item['name'] as String?) ?? 'Unknown Item';
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toDouble() ?? (price * qty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₦${price.toStringAsFixed(2)} × $qty', style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ])),
              Text('₦${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── List View ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
                onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
              ),
              const SizedBox(width: 4),
              Text('Payment Requests', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _filterChip(_filters[i]),
            ),
          ),
          const SizedBox(height: 12),

          // List
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal))
              : _error != null
                  ? _errorState()
                  : _requests.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: EnhancedTheme.primaryTeal,
                          onRefresh: _loadRequests,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) => _requestCard(_requests[i]),
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
    if (active && label != 'all') {
      chipColor = _statusColor(label);
    }

    return GestureDetector(
      onTap: () {
        setState(() => _filter = label);
        _loadRequests();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? (chipColor ?? EnhancedTheme.primaryTeal).withValues(alpha: 0.15)
              : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? (chipColor ?? EnhancedTheme.primaryTeal).withValues(alpha: 0.4)
                : context.borderColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(labelCapitalized, style: TextStyle(
            color: active ? (chipColor ?? EnhancedTheme.primaryTeal) : context.subLabelColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
        ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _loadDetail(req),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Request #$id',
                      style: TextStyle(color: context.labelColor, fontSize: 15, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.person_outline_rounded, color: context.hintColor, size: 14),
                  const SizedBox(width: 4),
                  Text(dispenser, style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: context.hintColor, size: 12),
                  const SizedBox(width: 4),
                  Text(customer, style: TextStyle(color: context.subLabelColor, fontSize: 12)),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('₦${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(date, style: TextStyle(color: context.hintColor, fontSize: 12)),
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
      Icon(Icons.receipt_long_outlined, color: context.hintColor, size: 64),
      const SizedBox(height: 16),
      Text('No payment requests', style: TextStyle(color: context.subLabelColor, fontSize: 16)),
    ]));
  }

  Widget _errorState() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: EnhancedTheme.errorRed, size: 48),
      const SizedBox(height: 16),
      Text('Something went wrong', style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(_error ?? '', style: TextStyle(color: context.subLabelColor, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _loadRequests,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry'),
        style: ElevatedButton.styleFrom(
          backgroundColor: EnhancedTheme.primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]));
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
      // Pre-fill the selected method with the total amount
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
              color: EnhancedTheme.surfaceColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.payment_rounded, color: EnhancedTheme.primaryTeal, size: 24),
                const SizedBox(width: 10),
                Text('Complete Payment', style: TextStyle(color: context.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text('Amount: ₦${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Method selector
              Text('Payment Method', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: _methods.map((m) {
                final key = m['key'] as String;
                final active = _method == key;
                return GestureDetector(
                  onTap: () => _selectMethod(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? EnhancedTheme.primaryTeal.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? EnhancedTheme.primaryTeal : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m['icon'] as IconData, color: active ? EnhancedTheme.primaryTeal : context.subLabelColor, size: 16),
                      const SizedBox(width: 6),
                      Text(m['label'] as String, style: TextStyle(
                        color: active ? EnhancedTheme.primaryTeal : context.subLabelColor,
                        fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                    ]),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),

              // Amount inputs
              Text('Amount Breakdown', style: TextStyle(color: context.subLabelColor, fontSize: 12, fontWeight: FontWeight.w600)),
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
                    backgroundColor: EnhancedTheme.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
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
      Icon(icon, color: context.hintColor, size: 16),
      const SizedBox(width: 8),
      SizedBox(width: 70, child: Text(label, style: TextStyle(color: context.subLabelColor, fontSize: 13))),
      Expanded(child: SizedBox(
        height: 42,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            prefixText: '₦ ',
            prefixStyle: TextStyle(color: context.hintColor, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
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
              borderSide: BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
            ),
          ),
        ),
      )),
    ]);
  }
}
