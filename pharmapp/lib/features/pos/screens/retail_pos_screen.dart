import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/shared/widgets/custom_textfield.dart';
import 'package:pharmapp/shared/widgets/cart_item_widget.dart';
import 'package:pharmapp/shared/widgets/cart_summary_panel.dart';
import 'package:pharmapp/core/services/barcode_service.dart';
import 'package:pharmapp/shared/models/item_model.dart';
import 'package:pharmapp/shared/models/cart_item.dart';

class RetailPOSScreen extends ConsumerStatefulWidget {
  const RetailPOSScreen({super.key});

  @override
  ConsumerState<RetailPOSScreen> createState() => _RetailPOSScreenState();
}

class _RetailPOSScreenState extends ConsumerState<RetailPOSScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isScanning = false;
  bool _isLoading = false;
  String? _selectedBarcode;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      // TODO: Search items by name or barcode
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search for: $query'),
          backgroundColor: EnhancedTheme.infoBlue,
        ),
      );
    }
  }

  Future<void> _scanBarcode() async {
    try {
      setState(() => _isScanning = true);

      final scanner = MobileScanner(
        title: 'Scan Product Barcode',
        android: const AndroidOptions(
          useAutoFocus: true,
          flashMode: FlashMode.off,
        ),
        ios: const IosOptions(
          logo: 'barcode_scanner',
          restriction: BarcodeFormatRestriction(
            upca: true,
            ean13: true,
            code39: true,
            code128: true,
            qr: true,
          ),
        ),
      );

      final result = await scanner.scan();
      if (result != null && result.format != null && result.value.isNotEmpty) {
        _selectedBarcode = result.value;
        // TODO: Find item by barcode and add to cart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: $_selectedBarcode'),
            backgroundColor: EnhancedTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanning failed: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _handleAddItem() {
    // TODO: Add selected item to cart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item added to cart'),
        backgroundColor: EnhancedTheme.successGreen,
      ),
    );
  }

  void _handleCheckout() {
    setState(() => _isLoading = true);

    try {
      // TODO: Process checkout
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Processing checkout...'),
          backgroundColor: EnhancedTheme.infoBlue,
        ),
      );

      // Navigate to payment screen
      context.read(enhancedThemeProvider.notifier).navigateTo('/payment');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkout failed: $e'),
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
      appBar: AppBar(
        backgroundColor: EnhancedTheme.surfaceColor,
        elevation: 0,
        title: const Text(
          'Retail POS',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          CustomIconButton(
            icon: Icons.shopping_cart,
            onPressed: () {
              // Navigate to cart
              context.read(enhancedThemeProvider.notifier).navigateTo('/payment');
            },
            color: Colors.white,
            showBorder: true,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search and Scan
                  EnhancedTheme.glassContainer(
                    context,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomSearchField(
                          hintText: 'Search items by name or barcode...',
                          controller: _searchController,
                          onChanged: (value) {
                            if (value.length >= 3) {
                              _handleSearch();
                            }
                          },
                          onClear: () {
                            _searchController.clear();
                          },
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                onPressed: _handleSearch,
                                text: 'Search',
                                icon: const Icon(Icons.search, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CustomButton(
                              onPressed: _scanBarcode,
                              text: 'Scan',
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                              backgroundColor: EnhancedTheme.accentCyan,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Featured Items
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Featured Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 8,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: FeaturedItemCard(
                                item: Item(
                                  id: index + 1,
                                  name: 'Product $index',
                                  brand: 'Brand $index',
                                  dosageForm: 'Tablet',
                                  genericName: 'Generic $index',
                                  manufacturer: 'Manufacturer $index',
                                  category: 'Medicine',
                                  subCategory: 'Pain Relief',
                                  purchasePrice: 50.0,
                                  sellingPrice: 75.0,
                                  wholesalePrice: 65.0,
                                  stock: 100,
                                  lowStockThreshold: 10,
                                  reorderLevel: 15,
                                  isPrescriptionRequired: false,
                                  expiryDate: DateTime(2025, 12, 31),
                                  manufactureDate: DateTime(2023, 1, 1),
                                  barcode: '123456789$index',
                                  batchNumber: 'BATCH-$index',
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
                                  alternativeBrands: ['Brand A', 'Brand B'],
                                  imageUrl: null,
                                  description: 'Description for product $index',
                                  isFeatured: true,
                                  isPopular: true,
                                ),
                                onTap: _handleAddItem,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Categories
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CategoryChip(
                            label: 'Pain Relief',
                            onTap: () {
                              // TODO: Filter items by category
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Filtering by Pain Relief'),
                                  backgroundColor: EnhancedTheme.infoBlue,
                                ),
                              );
                            },
                          ),
                          CategoryChip(
                            label: 'Cold & Flu',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Filtering by Cold & Flu'),
                                  backgroundColor: EnhancedTheme.infoBlue,
                                ),
                              );
                            },
                          ),
                          CategoryChip(
                            label: 'Vitamins',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Filtering by Vitamins'),
                                  backgroundColor: EnhancedTheme.infoBlue,
                                ),
                              );
                            },
                          ),
                          CategoryChip(
                            label: 'Skincare',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Filtering by Skincare'),
                                  backgroundColor: EnhancedTheme.infoBlue,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Cart Items
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cart Items',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // TODO: Display actual cart items
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Cart Summary Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CartSummaryPanel(
              itemCount: 0,
              totalAmount: 0.0,
              onCheckout: _handleCheckout,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const FeaturedItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTheme.glassContainer(
      context,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: EnhancedTheme.glassMedium,
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(item.itemImageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.brand,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    item.formattedSellingPrice,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: EnhancedTheme.successGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (item.discountPercentage > 0)
                    Text(
                      item.formattedPurchasePrice,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                        fontSize: 10,
                        decoration: TextDecoration.lineThrough,
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

class CategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: EnhancedTheme.primaryTeal,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      onPressed: onTap,
      backgroundColor: EnhancedTheme.surfaceGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: EnhancedTheme.primaryTeal.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }
}