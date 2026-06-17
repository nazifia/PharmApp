import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/utils/currency_format.dart';
import 'package:pharmapp/shared/models/prescriber.dart';
import '../providers/prescriber_provider.dart';

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
                        onTap: () => context.go('/prescriber-login'),
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

                  // Consultation fee bands (editable)
                  _ConsultFeesCard(prescriber: prescriber),

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
                          onTap: () => context.push('/prescriber-portal/patients'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.edit_document,
                          label: 'Write Rx',
                          subtitle: 'New prescription',
                          color: EnhancedTheme.accentPurple,
                          onTap: () => context.push('/prescriber-portal/write-rx'),
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
                        onTap: () => context.push('/prescriber-portal/commissions'),
                      ),
                    ),

                  if (_kConsultCats.any(
                      (c) => (prescriber.consultationFees[c] ?? 0) > 0)) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _ActionCard(
                        icon: Icons.medical_services_rounded,
                        label: 'Consultation Fees',
                        subtitle: 'Total fees paid to you',
                        color: EnhancedTheme.accentCyan,
                        onTap: () =>
                            context.push('/prescriber-portal/consultations'),
                      ),
                    ),
                  ],

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

// ── Consultation fee bands card ───────────────────────────────────────────────

const _kConsultCats = ['A', 'B', 'C', 'D', 'E'];

class _ConsultFeesCard extends ConsumerWidget {
  final Prescriber prescriber;
  const _ConsultFeesCard({required this.prescriber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fees = prescriber.consultationFees;
    final hasAny = _kConsultCats.any((c) => (fees[c] ?? 0) > 0);

    return ClipRRect(
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
                  Expanded(
                    child: Text('Consultation Fees',
                        style: TextStyle(
                            color: context.subLabelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ),
                  GestureDetector(
                    onTap: () => _edit(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: EnhancedTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: EnhancedTheme.accentPurple
                                .withValues(alpha: 0.4)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded,
                            color: EnhancedTheme.accentPurple, size: 14),
                        SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                color: EnhancedTheme.accentPurple,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a band when writing a prescription. The fee is added at the pharmacy at payment time.',
                style: TextStyle(color: context.subLabelColor, fontSize: 11),
              ),
              const SizedBox(height: 14),
              if (!hasAny)
                Text('No fees set yet — tap Edit to configure bands A–E.',
                    style: TextStyle(color: context.subLabelColor, fontSize: 13))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _kConsultCats)
                      if ((fees[c] ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.accentPurple
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: EnhancedTheme.accentPurple
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Cat $c',
                                  style: TextStyle(
                                      color: context.subLabelColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              Text(fmtN(fees[c] ?? 0),
                                  style: TextStyle(
                                      color: context.labelColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
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

  void _edit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConsultFeesSheet(prescriber: prescriber),
    );
  }
}

class _ConsultFeesSheet extends ConsumerStatefulWidget {
  final Prescriber prescriber;
  const _ConsultFeesSheet({required this.prescriber});

  @override
  ConsumerState<_ConsultFeesSheet> createState() => _ConsultFeesSheetState();
}

class _ConsultFeesSheetState extends ConsumerState<_ConsultFeesSheet> {
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fees = widget.prescriber.consultationFees;
    _ctrls = {
      for (final c in _kConsultCats)
        c: TextEditingController(
            text: (fees[c] ?? 0) > 0 ? (fees[c]!).toStringAsFixed(0) : ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final fees = <String, double>{
      for (final c in _kConsultCats)
        c: double.tryParse(_ctrls[c]!.text.trim()) ?? 0,
    };
    final updated = await ref
        .read(prescriberNotifierProvider.notifier)
        .updatePrescriber(widget.prescriber.id, {'consultation_fees': fees},
            portal: true);
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      ref.read(currentPrescriberProvider.notifier).state = updated;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: EnhancedTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        content: Text('Consultation fees updated.'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: EnhancedTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        content: Text('Failed to update fees.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Consultation Fee Bands',
                  style: TextStyle(
                      color: context.labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Set the amount (₦) for each category. Leave blank for none.',
                  style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              const SizedBox(height: 16),
              for (final c in _kConsultCats) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text('Cat $c',
                          style: TextStyle(
                              color: context.labelColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrls[c],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(color: context.labelColor, fontSize: 14),
                        decoration: InputDecoration(
                          prefixText: '₦ ',
                          prefixStyle: TextStyle(color: context.hintColor),
                          hintText: '0',
                          hintStyle: TextStyle(color: context.hintColor),
                          filled: true,
                          fillColor: context.isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: context.borderColor)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: context.borderColor)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: EnhancedTheme.accentPurple,
                                  width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.accentPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save Fees',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

