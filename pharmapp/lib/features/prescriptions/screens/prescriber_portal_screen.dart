import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import '../providers/prescriber_provider.dart';
import 'prescriber_commissions_screen.dart';
import 'prescriber_patients_screen.dart';
import 'prescriber_write_rx_screen.dart';

class PrescriberPortalScreen extends ConsumerWidget {
  const PrescriberPortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriber = ref.watch(currentPrescriberProvider);

    if (prescriber == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.medical_services_rounded,
                            color: EnhancedTheme.accentPurple, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prescriber Portal',
                                style: GoogleFonts.outfit(
                                    color: context.labelColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            Text('Welcome back, Dr. ${prescriber.name}',
                                style: TextStyle(
                                    color: context.subLabelColor, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Verification status card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.borderColor, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text('Verification Status',
                                      style: TextStyle(
                                          color: context.subLabelColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: prescriber.isVerified
                                        ? EnhancedTheme.successGreen.withValues(alpha: 0.15)
                                        : EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: prescriber.isVerified
                                          ? EnhancedTheme.successGreen.withValues(alpha: 0.4)
                                          : EnhancedTheme.warningAmber.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        prescriber.isVerified
                                            ? Icons.verified_rounded
                                            : Icons.hourglass_top_rounded,
                                        size: 13,
                                        color: prescriber.isVerified
                                            ? EnhancedTheme.successGreen
                                            : EnhancedTheme.warningAmber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        prescriber.isVerified ? 'Verified' : 'Pending Review',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: prescriber.isVerified
                                              ? EnhancedTheme.successGreen
                                              : EnhancedTheme.warningAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!prescriber.isVerified) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Your profile is under review. A pharmacy admin will verify your credentials.',
                                style: TextStyle(
                                    color: context.subLabelColor, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Profile card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.borderColor, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Profile',
                                style: TextStyle(
                                    color: context.subLabelColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 16),
                            _row(context, Icons.person_rounded, 'Name', prescriber.name),
                            if (prescriber.licenseNumber != null)
                              _row(context, Icons.badge_rounded, 'License No.',
                                  prescriber.licenseNumber!),
                            if (prescriber.specialty != null)
                              _row(context, Icons.medical_services_rounded,
                                  'Specialty', prescriber.specialty!),
                            if (prescriber.phone != null)
                              _row(context, Icons.phone_rounded, 'Phone',
                                  prescriber.phone!),
                            if (prescriber.hospitalName != null)
                              _row(context, Icons.local_hospital_rounded,
                                  'Hospital', prescriber.hospitalName!),
                            if (prescriber.address != null)
                              _row(context, Icons.location_on_rounded, 'Address',
                                  prescriber.address!),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action cards — row 1
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.people_rounded,
                          label: 'My Patients',
                          subtitle: 'Register & manage',
                          color: EnhancedTheme.accentCyan,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PrescriberPatientsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.edit_document,
                          label: 'Write Rx',
                          subtitle: 'New prescription',
                          color: EnhancedTheme.accentPurple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PrescriberWriteRxScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Action cards — row 2
                  if (prescriber.commissionRate > 0)
                    SizedBox(
                      width: double.infinity,
                      child: _ActionCard(
                        icon: Icons.monetization_on_rounded,
                        label: 'My Earnings',
                        subtitle: 'Commission from dispensed Rx',
                        color: EnhancedTheme.accentOrange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrescriberCommissionsScreen(
                              prescriber: prescriber,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Sign out
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(currentPrescriberProvider.notifier).state = null;
                        ref.read(prescriberTokenProvider.notifier).state = null;
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EnhancedTheme.errorRed,
                        side: BorderSide(
                            color: EnhancedTheme.errorRed.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.7),
                size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: ctx.subLabelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: ctx.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 12),
                Text(label,
                    style: TextStyle(
                        color: context.labelColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: context.subLabelColor, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

