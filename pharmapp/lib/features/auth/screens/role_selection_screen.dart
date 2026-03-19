import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  static const _roles = [
    {'role': 'Pharmacist',        'desc': 'Manage inventory and daily pharmacy operations.', 'icon': Icons.medical_services, 'color': Color(0xFF0D9488)},
    {'role': 'Cashier',           'desc': 'Handle sales, payments, and customer transactions.', 'icon': Icons.point_of_sale, 'color': Color(0xFFF59E0B)},
    {'role': 'Salesperson',       'desc': 'Attend customers and process retail orders.', 'icon': Icons.sell, 'color': Color(0xFF3B82F6)},
    {'role': 'Admin',             'desc': 'Full access: user management and analytics.', 'icon': Icons.admin_panel_settings, 'color': Color(0xFF8B5CF6)},
    {'role': 'Wholesale Manager', 'desc': 'Manage bulk orders and wholesale operations.', 'icon': Icons.warehouse, 'color': Color(0xFF06B6D4)},
  ];

  String _dashboardFor(String role) {
    switch (role) {
      case 'Admin':
      case 'Manager':
        return '/admin-dashboard';
      case 'Wholesale Manager':
      case 'Wholesale Operator':
      case 'Wholesale Salesperson':
        return '/wholesale-dashboard';
      default:
        return '/dashboard';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.go('/login'),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Select Role',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                  ]),
                ),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0D9488), size: 48),
                      const SizedBox(height: 12),
                      const Text('Select Your Role',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Choose the role that best describes your position',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 13)),
                      const SizedBox(height: 36),
                  ...(_roles.map((r) {
                    final color = r['color'] as Color;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RoleCard(
                        role:  r['role'] as String,
                        desc:  r['desc'] as String,
                        icon:  r['icon'] as IconData,
                        color: color,
                        onTap: () => context.go(_dashboardFor(r['role'] as String)),
                      ),
                    );
                  })),
                ],
              ),
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

class _RoleCard extends StatelessWidget {
  final String role;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha:0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha:0.3)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(desc, style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color.withValues(alpha:0.6), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
