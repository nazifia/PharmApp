import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/models/prescriber.dart';
import '../providers/prescriber_provider.dart';
import 'prescriber_commissions_screen.dart';
import 'prescriber_consultations_screen.dart';
import 'prescriber_form_screen.dart';

class PrescriberListScreen extends ConsumerStatefulWidget {
  const PrescriberListScreen({super.key});

  @override
  ConsumerState<PrescriberListScreen> createState() =>
      _PrescriberListScreenState();
}

class _PrescriberListScreenState extends ConsumerState<PrescriberListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm({Prescriber? prescriber}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrescriberFormSheet(existing: prescriber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canWrite = Rbac.can(user, AppPermission.writePrescriptions);
    final listAsync = ref.watch(prescriberListProvider(_query));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                // ── App bar ──────────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: context.iconOnBg, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prescribers',
                                style: TextStyle(
                                    color: context.labelColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            Text('Registered prescribers & doctors',
                                style: TextStyle(
                                    color: context.subLabelColor,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      if (canWrite)
                        GestureDetector(
                          onTap: () => _openForm(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  EnhancedTheme.primaryTeal,
                                  EnhancedTheme.accentCyan
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    color: Colors.black, size: 18),
                                SizedBox(width: 6),
                                Text('Add',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Search ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: context.labelColor),
                    decoration: InputDecoration(
                      hintText: 'Search by name, license, specialty…',
                      hintStyle: TextStyle(
                          color: context.hintColor,
                          fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: context.hintColor),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  color: context.hintColor,
                                  size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: EnhancedTheme.primaryTeal),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),

                // ── List ─────────────────────────────────────────────────────
                Expanded(
                  child: listAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: EnhancedTheme.primaryTeal),
                    ),
                    error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: TextStyle(color: context.subLabelColor)),
                    ),
                    data: (prescribers) {
                      if (prescribers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_rounded,
                                  size: 64,
                                  color: context.iconOnBg.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text(
                                _query.isEmpty
                                    ? 'No prescribers registered yet'
                                    : 'No results for "$_query"',
                                style: TextStyle(
                                    color: context.hintColor,
                                    fontSize: 14),
                              ),
                              if (_query.isEmpty && canWrite) ...[
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _openForm(),
                                  icon: const Icon(Icons.add_rounded,
                                      size: 18),
                                  label: const Text('Add First Prescriber'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        EnhancedTheme.primaryTeal,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                        itemCount: prescribers.length,
                        itemBuilder: (_, i) => _PrescriberCard(
                          prescriber: prescribers[i],
                          canWrite: canWrite,
                          onEdit: () => _openForm(prescriber: prescribers[i]),
                          onViewCommissions: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrescriberCommissionsScreen(
                                prescriber: prescribers[i],
                                isAdminView: true,
                              ),
                            ),
                          ),
                          onViewConsultations: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrescriberConsultationsScreen(
                                prescriber: prescribers[i],
                                isAdminView: true,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                            delay: Duration(milliseconds: i * 40)),
                      );
                    },
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

// ── Prescriber card ───────────────────────────────────────────────────────────

class _PrescriberCard extends StatelessWidget {
  final Prescriber prescriber;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onViewCommissions;
  final VoidCallback onViewConsultations;

  const _PrescriberCard({
    required this.prescriber,
    required this.canWrite,
    required this.onEdit,
    required this.onViewCommissions,
    required this.onViewConsultations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canWrite ? onEdit : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        EnhancedTheme.accentPurple,
                        EnhancedTheme.infoBlue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      prescriber.name.isNotEmpty
                          ? prescriber.name[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prescriber.name,
                              style: TextStyle(
                                  color: context.labelColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (prescriber.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.successGreen
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: EnhancedTheme.successGreen
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Text('Verified',
                                  style: TextStyle(
                                      color: EnhancedTheme.successGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prescriber.specialtyLabel,
                        style: TextStyle(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      if (prescriber.licenseNumber != null ||
                          prescriber.hospitalName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (prescriber.licenseNumber != null)
                              _MetaChip(
                                icon: Icons.badge_rounded,
                                label: prescriber.licenseNumber!,
                              ),
                            if (prescriber.licenseNumber != null &&
                                prescriber.hospitalName != null)
                              const SizedBox(width: 8),
                            if (prescriber.hospitalName != null)
                              Expanded(
                                child: _MetaChip(
                                  icon: Icons.local_hospital_rounded,
                                  label: prescriber.hospitalName!,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (prescriber.commissionRate > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: EnhancedTheme.accentOrange
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: EnhancedTheme.accentOrange
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.percent_rounded,
                                      size: 10,
                                      color: EnhancedTheme.accentOrange),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${prescriber.commissionRate.toStringAsFixed(prescriber.commissionRate % 1 == 0 ? 0 : 1)}%',
                                    style: const TextStyle(
                                        color: EnhancedTheme.accentOrange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          GestureDetector(
                            onTap: onViewCommissions,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on_outlined,
                                    size: 11,
                                    color: context.subLabelColor),
                                const SizedBox(width: 3),
                                Text('Commissions',
                                    style: TextStyle(
                                        color: context.subLabelColor,
                                        fontSize: 10,
                                        decoration:
                                            TextDecoration.underline)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onViewConsultations,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.medical_services_outlined,
                                    size: 11,
                                    color: EnhancedTheme.accentCyan),
                                const SizedBox(width: 3),
                                Text('Consultations',
                                    style: TextStyle(
                                        color: context.subLabelColor,
                                        fontSize: 10,
                                        decoration:
                                            TextDecoration.underline)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canWrite)
                  Icon(Icons.edit_rounded,
                      color: context.iconOnBg.withValues(alpha: 0.3), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: context.subLabelColor),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: context.subLabelColor, fontSize: 11),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
