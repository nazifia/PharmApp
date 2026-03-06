import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/dashboard_card.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/shared/models/sale_model.dart';
import 'package:pharmapp/shared/models/item_model.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  User? _currentUser;
  List<Sale> _recentSales = [];
  List<Item> _lowStockItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final isAuthenticated = await authService.checkAuthStatus();
      if (isAuthenticated) {
        _currentUser = authService.currentUser;

        // TODO: Load actual data from backend
        // For demo purposes, we'll use mock data
        _recentSales = [
          Sale(
            id: 1,
            userId: 1,
            customerId: 1,
            totalAmount: 2500.0,
            discountAmount: 200.0,
            taxAmount: 150.0,
            finalAmount: 2450.0,
            paymentMethod: 'cash',
            paymentStatus: 'paid',
            isWholesale: false,
            isReturn: false,
            returnReason: '',
            saleDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            cashPayment: 2450.0,
            cardPayment: 0.0,
            walletPayment: 0.0,
            bankTransferPayment: 0.0,
            invoiceNumber: 'INV-2025-001',
            customerName: 'John Doe',
            customerPhone: '+91 98765 43210',
            itemIds: [1, 2, 3],
            quantities: [2, 1, 5],
            prices: [500.0, 1200.0, 150.0],
          ),
          // Add more mock sales
        ];

        _lowStockItems = [
          Item(
            id: 1,
            name: 'Paracetamol',
            brand: 'Cipla',
            dosageForm: 'Tablet',
            genericName: 'Paracetamol',
            manufacturer: 'Cipla Ltd',
            category: 'Medicine',
            subCategory: 'Pain Relief',
            purchasePrice: 50.0,
            sellingPrice: 75.0,
            wholesalePrice: 65.0,
            stock: 5,
            lowStockThreshold: 10,
            reorderLevel: 15,
            isPrescriptionRequired: false,
            expiryDate: DateTime(2025, 12, 31),
            manufactureDate: DateTime(2023, 1, 1),
            barcode: '1234567890123',
            batchNumber: 'BATCH-001',
            storageCondition: 'Room Temperature',
            isDiscountable: true,
            discountPercentage: 10.0,
            unit: 'Strip',
            packageSize: '10',
            packageUnit: 'Tablets',
            isTaxable: true,
            taxRate: 5.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: ['Pain Relief', 'OTC'],
            alternativeBrands: ['Dolo', 'Calpol'],
            imageUrl: null,
            description: 'Paracetamol 500mg tablets for pain relief',
            isFeatured: false,
            isPopular: true,
          ),
          // Add more mock low stock items
        ];

        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard data: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),

                  // Header
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,${_currentUser?.firstName ?? 'User'}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                ),
                              ),
                              const Text(
                                'Have a great day at work!',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: EnhancedTheme.primaryTeal,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Today is ${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: () {
                            // Navigate to POS
                            ref.read(enhancedThemeProvider.notifier).navigateTo('/pos');
                          },
                          text: 'New Sale',
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                          backgroundColor: EnhancedTheme.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          onPressed: () {
                            // Navigate to Inventory
                            ref.read(enhancedThemeProvider.notifier).navigateTo('/inventory');
                          },
                          text: 'Inventory',
                          icon: const Icon(Icons.medical_services, color: Colors.white),
                          backgroundColor: EnhancedTheme.accentCyan,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          title: 'Total Sales',
                          value: '₹5,000',
                          subtitle: 'This month',
                          icon: Icons.monetization_on,
                          color: EnhancedTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardCard(
                          title: 'Items Sold',
                          value: '1,250',
                          subtitle: 'This month',
                          icon: Icons.inventory,
                          color: EnhancedTheme.accentOrange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          title: 'Low Stock',
                          value: '${_lowStockItems.length}',
                          subtitle: 'Items need attention',
                          icon: Icons.warning,
                          color: EnhancedTheme.warningAmber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardCard(
                          title: 'Customers',
                          value: '150',
                          subtitle: 'Registered customers',
                          icon: Icons.people,
                          color: EnhancedTheme.infoBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Recent Sales
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Recent Sales',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else if (_recentSales.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.glassLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'No recent sales found',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._recentSales.map((sale) {
                          return SaleCard(
                            sale: sale,
                            onTap: () {
                              // Navigate to sale details
                              ref.read(enhancedThemeProvider.notifier).navigateTo('/sale/${sale.id}');
                            },
                          );
                        }).toList(),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Low Stock Items
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Low Stock Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else if (_lowStockItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.glassLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'All items are sufficiently stocked',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._lowStockItems.map((item) {
                          return LowStockCard(
                            item: item,
                            onTap: () {
                              // Navigate to item details
                              ref.read(enhancedThemeProvider.notifier).navigateTo('/item/${item.id}');
                            },
                          );
                        }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SaleCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const SaleCard({
    super.key,
    required this.sale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTheme.glassContainer(
      context,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sale.invoiceInfo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sale.isWholesale ? EnhancedTheme.accentCyan.withOpacity(0.2) : EnhancedTheme.primaryTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sale.isWholesale ? EnhancedTheme.accentCyan.withOpacity(0.3) : EnhancedTheme.primaryTeal.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      sale.saleType,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: sale.isWholesale ? EnhancedTheme.accentCyan : EnhancedTheme.primaryTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                sale.customerInfo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    sale.formattedFinalAmount,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: EnhancedTheme.successGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'for ${sale.itemsCount} items',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sale.paymentStatus == 'paid'
                         ? EnhancedTheme.successGreen.withOpacity(0.2)
                          : EnhancedTheme.warningAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: sale.paymentStatus == 'paid'
                           ? EnhancedTheme.successGreen.withOpacity(0.3)
                            : EnhancedTheme.warningAmber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      sale.paymentStatus.capitalize(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: sale.paymentStatus == 'paid'
                           ? EnhancedTheme.successGreen
                            : EnhancedTheme.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sale.formattedSaleDate,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LowStockCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const LowStockCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTheme.glassContainer(
      context,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: EnhancedTheme.warningAmber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: EnhancedTheme.warningAmber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.brand,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Stock: ${item.stock}/${item.lowStockThreshold}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: EnhancedTheme.warningAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: EnhancedTheme.warningAmber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Low Stock',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: EnhancedTheme.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}