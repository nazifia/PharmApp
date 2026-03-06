import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/shared/widgets/custom_button.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/shared/models/user_model.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authService = ref.read(authServiceProvider);
    final isAuthenticated = await authService.checkAuthStatus();
    if (isAuthenticated) {
      _currentUser = authService.currentUser;
      setState(() {});
    } else {
      // Redirect to login if not authenticated
      ref.read(enhancedThemeProvider.notifier).navigateTo('/login');
    }
  }

  Future<void> _selectRole(String role) async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final updatedUser = _currentUser!.copyWith(role: role);

      // Update user role in backend
      final success = await authService.updateUserProfile({
        'role': role,
      });

      if (success) {
        // Navigate to appropriate dashboard
        String route = '/dashboard';
        if (role == 'Wholesaler') {
          route = '/wholesale-dashboard';
        } else if (role == 'Admin') {
          route = '/admin-dashboard';
        }

        ref.read(enhancedThemeProvider.notifier).navigateTo(route);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update user role'),
            backgroundColor: EnhancedTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: EnhancedTheme.errorRed,
        ),
      );
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

                  // Logo and App Name
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: EnhancedTheme.glassLight,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_pharmacy,
                          size: 48,
                          color: EnhancedTheme.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PharmApp',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const Text(
                        'Select Your Role',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // Role Cards
                  Column(
                    children: [
                      RoleCard(
                        role: 'Pharmacist',
                        description: 'Manage inventory, process prescriptions, and handle daily pharmacy operations.',
                        color: EnhancedTheme.primaryTeal,
                        icon: Icons.medical_services,
                        onPressed: () => _selectRole('Pharmacist'),
                      ),
                      const SizedBox(height: 16),
                      RoleCard(
                        role: 'Cashier',
                        description: 'Handle sales, process payments, and manage customer transactions.',
                        color: EnhancedTheme.accentOrange,
                        icon: Icons.shopping_cart,
                        onPressed: () => _selectRole('Cashier'),
                      ),
                      const SizedBox(height: 16),
                      RoleCard(
                        role: 'Admin',
                        description: 'Full access to all features including user management and analytics.',
                        color: EnhancedTheme.accentPurple,
                        icon: Icons.admin_panel_settings,
                        onPressed: () => _selectRole('Admin'),
                      ),
                      const SizedBox(height: 16),
                      RoleCard(
                        role: 'Wholesaler',
                        description: 'Manage bulk orders, supplier relationships, and wholesale operations.',
                        color: EnhancedTheme.accentCyan,
                        icon: Icons.monetization_on,
                        onPressed: () => _selectRole('Wholesaler'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Footer
                  Column(
                    children: [
                      const Text(
                        'Pharmacy Management Made Simple',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '© 2026 PharmApp. All rights reserved.',
                        style: TextStyle(
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

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final String role;
  final String description;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  const RoleCard({
    super.key,
    required this.role,
    required this.description,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTheme.glassContainer(
      context,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                role,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}