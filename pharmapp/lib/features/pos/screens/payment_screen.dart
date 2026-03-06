import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/cart_item_widget.dart';
import 'package:pharmapp/shared/widgets/split_payment_dialog.dart';
import 'package:pharmapp/shared/models/cart_item.dart';
import 'package:pharmapp/shared/models/payment_model.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final List<CartItem> _cartItems = [];
  double _totalAmount = 0.0;
  double _discountAmount = 0.0;
  double _taxAmount = 0.0;
  double _finalAmount = 0.0;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isLoading = false;
  bool _showSplitPayment = false;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  void _loadCartItems() {
    // TODO: Load actual cart items from provider
    // For demo purposes, we'll use mock data
    setState(() {
      _cartItems.addAll([
        CartItem(
          id: 1,
          userId: 1,
          itemId: 1,
          quantity: 2,
          unitPrice: 75.0,
          subtotal: 150.0,
          discount: 15.0,
          total: 135.0,
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isWholesale: false,
          customerPhone: null,
          customerName: null,
        ),
        CartItem(
          id: 2,
          userId: 1,
          itemId: 2,
          quantity: 1,
          unitPrice: 125.0,
          subtotal: 125.0,
          discount: 0.0,
          total: 125.0,
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isWholesale: false,
          customerPhone: null,
          customerName: null,
        ),
      ]);

      _calculateTotals();
    });
  }

  void _calculateTotals() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) => sum + item.total);
    _discountAmount = _cartItems.fold(0.0, (sum, item) => sum + item.discount);
    _taxAmount = _totalAmount * 0.05; // 5% tax
    _finalAmount = _totalAmount + _taxAmount - _discountAmount;
  }

  void _handlePayment() {
    setState(() => _isLoading = true);

    try {
      // TODO: Process payment
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment processing...'),
          backgroundColor: EnhancedTheme.infoBlue,
        ),
      );

      // Navigate to receipt or success screen
      context.read(enhancedThemeProvider.notifier).navigateTo('/receipt');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleSplitPayment() {
    setState(() {
      _showSplitPayment = true;
      _selectedPaymentMethod = PaymentMethod.split;
    });
  }

  void _handlePaymentOption(PaymentMethod method) {
    setState(() {
      _selectedPaymentMethod = method;
      _showSplitPayment = method == PaymentMethod.split;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: EnhancedTheme.surfaceColor,
        elevation: 0,
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cart Items
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cart Items (${_cartItems.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_cartItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.glassLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Your cart is empty',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._cartItems.map((item) {
                          return CartItemWidget(
                            item: item,
                            showRemoveButton: false,
                            showQuantityControls: false,
                          );
                        }).toList(),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Payment Summary
                  EnhancedTheme.glassContainer(
                    context,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Payment Summary',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Summary Rows
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${_totalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: EnhancedTheme.warningAmber,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '-₹${_discountAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: EnhancedTheme.warningAmber,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tax (5%)',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: EnhancedTheme.infoBlue,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${_taxAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: EnhancedTheme.infoBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                          color: Colors.white54,
                          height: 1,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₹${_finalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: EnhancedTheme.successGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Methods
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Select Payment Method',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      PaymentMethodCard(
                        method: PaymentMethod.cash,
                        isSelected: _selectedPaymentMethod == PaymentMethod.cash,
                        onTap: () => _handlePaymentOption(PaymentMethod.cash),
                      ),

                      const SizedBox(height: 12),

                      PaymentMethodCard(
                        method: PaymentMethod.card,
                        isSelected: _selectedPaymentMethod == PaymentMethod.card,
                        onTap: () => _handlePaymentOption(PaymentMethod.card),
                      ),

                      const SizedBox(height: 12),

                      PaymentMethodCard(
                        method: PaymentMethod.wallet,
                        isSelected: _selectedPaymentMethod == PaymentMethod.wallet,
                        onTap: () => _handlePaymentOption(PaymentMethod.wallet),
                      ),

                      const SizedBox(height: 12),

                      PaymentMethodCard(
                        method: PaymentMethod.split,
                        isSelected: _selectedPaymentMethod == PaymentMethod.split,
                        onTap: () => _handlePaymentOption(PaymentMethod.split),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Customer Information
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Customer Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      EnhancedTheme.glassContainer(
                        context,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomTextField(
                              labelText: 'Customer Name (Optional)',
                              hintText: 'Enter customer name',
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              labelText: 'Phone Number (Optional)',
                              hintText: '+91 98765 43210',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Checkout Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EnhancedTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: CustomButton(
                onPressed: _isLoading ? null : _handlePayment,
                text: _isLoading ? 'Processing...' : 'Complete Payment',
                isLoading: _isLoading,
                backgroundColor: EnhancedTheme.primaryTeal,
              ),
            ),
          ),

          if (_showSplitPayment)
            SplitPaymentDialog(
              totalAmount: _finalAmount,
              onConfirm: (payment) {
                setState(() {
                  _showSplitPayment = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Split payment: ${payment.paymentBreakdown}'),
                    backgroundColor: EnhancedTheme.infoBlue,
                  ),
                );
              },
              onCancel: () {
                setState(() {
                  _showSplitPayment = false;
                  _selectedPaymentMethod = PaymentMethod.cash;
                });
              },
            ),
        ],
      ),
    );
  }
}

class PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentMethodCard({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    final methodData = {
      PaymentMethod.cash: {
        'icon': Icons.account_balance_wallet,
        'color': colors.primaryTeal,
        'title': 'Cash',
        'description': 'Pay with cash',
      },
      PaymentMethod.card: {
        'icon': Icons.credit_card,
        'color': colors.accentCyan,
        'title': 'Card',
        'description': 'Credit/Debit Card',
      },
      PaymentMethod.wallet: {
        'icon': Icons.account_balance_wallet,
        'color': colors.successGreen,
        'title': 'Wallet',
        'description': 'Use wallet balance',
      },
      PaymentMethod.split: {
        'icon': Icons.split,
        'color': colors.warningAmber,
        'title': 'Split',
        'description': 'Multiple payment methods',
      },
    };

    return EnhancedTheme.glassContainer(
      context,
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? methodData[method]!['color'] : colors.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? methodData[method]!['color']! : colors.primaryTeal.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    methodData[method]!['icon'],
                    color: isSelected ? Colors.white : methodData[method]!['color'],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        methodData[method]!['title'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected ? Colors.white : colors.primaryTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        methodData[method]!['description'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected ? Colors.white54 : colors.primaryTeal.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: EnhancedTheme.primaryTeal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum PaymentMethod {
  cash,
  card,
  wallet,
  split,
}