import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  static const _roles = [
    {
      'role':  'Pharmacist',
      'desc':  'Manage inventory and daily pharmacy operations.',
      'icon':  Icons.medical_services,
      'color': Color(0xFF0D9488),
    },
    {
      'role':  'Cashier',
      'desc':  'Handle sales, payments, and customer transactions.',
      'icon':  Icons.point_of_sale,
      'color': Color(0xFFF59E0B),
    },
    {
      'role':  'Salesperson',
      'desc':  'Attend customers and process retail orders.',
      'icon':  Icons.sell,
      'color': Color(0xFF3B82F6),
    },
    {
      'role':  'Admin',
      'desc':  'Full access: user management and analytics.',
      'icon':  Icons.admin_panel_settings,
      'color': Color(0xFF8B5CF6),
    },
    {
      'role':  'Wholesale Manager',
      'desc':  'Manage bulk orders and wholesale operations.',
      'icon':  Icons.warehouse,
      'color': Color(0xFF06B6D4),
    },
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
          // ── Rich multi-stop background gradient ─────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A1628),
                  Color(0xFF0F172A),
                  Color(0xFF1A1F3C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative teal glow — top center ──────────────────────────
          Positioned(
            top: -120, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 380, height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF0D9488).withValues(alpha: 0.22),
                    const Color(0xFF0D9488).withValues(alpha: 0.0),
                  ]),
                ),
              ),
            ),
          ),

          // ── Decorative purple glow — bottom right ───────────────────────
          Positioned(
            bottom: -80, right: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          // ── Decorative cyan glow — mid left ────────────────────────────
          Positioned(
            top: 280, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top nav ───────────────────────────────────────────────
                _buildNavBar(context)
                    .animate()
                    .fadeIn(duration: 400.ms),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    child: Column(
                      children: [
                        const SizedBox(height: 28),

                        // ── Hero section ─────────────────────────────────
                        _buildHero()
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 500.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 36),

                        // ── Role cards ───────────────────────────────────
                        ..._roles.asMap().entries.map((entry) {
                          final i = entry.key;
                          final r = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _RoleCard(
                              role:  r['role'] as String,
                              desc:  r['desc'] as String,
                              icon:  r['icon'] as IconData,
                              color: r['color'] as Color,
                              onTap: () => context.go(
                                  _dashboardFor(r['role'] as String)),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 200 + i * 80),
                                duration: 400.ms,
                              )
                              .slideX(begin: 0.08, end: 0);
                        }),

                        const SizedBox(height: 20),
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

  Widget _buildNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Select Role',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.40),
              ),
            ),
            child: Text(
              'Step 1 of 2',
              style: GoogleFonts.inter(
                color: const Color(0xFF0D9488),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        // Layered icon
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF0D9488).withValues(alpha: 0.22),
                  const Color(0xFF0D9488).withValues(alpha: 0.0),
                ]),
              ),
            ),
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.50),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_pharmacy_rounded,
                color: Colors.white, size: 42,
              ),
            ),
          ],
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),

        Text(
          'What\'s Your Role?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          'Choose the role that best describes your position\nin the pharmacy.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ── Role Card ──────────────────────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
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
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // Subtle gradient card background
                gradient: LinearGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.28),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ── Icon container with gradient ──────────────────────
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.color.withValues(alpha: 0.28),
                          widget.color.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 28),
                  ),

                  const SizedBox(width: 16),

                  // ── Text ─────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.desc,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── Arrow chip ────────────────────────────────────────
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: widget.color,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
