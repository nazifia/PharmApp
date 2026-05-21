import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/models/prescriber.dart';
import '../providers/prescriber_provider.dart';
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
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prescribers',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                            Text('Registered prescribers & doctors',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name, license, specialty…',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.5)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12)),
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
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6))),
                    ),
                    data: (prescribers) {
                      if (prescribers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search_rounded,
                                  size: 64,
                                  color:
                                      Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text(
                                _query.isEmpty
                                    ? 'No prescribers registered yet'
                                    : 'No results for "$_query"',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
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

  const _PrescriberCard({
    required this.prescriber,
    required this.canWrite,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                              style: const TextStyle(
                                  color: Colors.white,
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
                          prescriber.clinic != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (prescriber.licenseNumber != null)
                              _MetaChip(
                                icon: Icons.badge_rounded,
                                label: prescriber.licenseNumber!,
                              ),
                            if (prescriber.licenseNumber != null &&
                                prescriber.clinic != null)
                              const SizedBox(width: 8),
                            if (prescriber.clinic != null)
                              Expanded(
                                child: _MetaChip(
                                  icon: Icons.local_hospital_rounded,
                                  label: prescriber.clinic!,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (prescriber.isNetworkShared) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.public_rounded,
                                size: 12,
                                color: EnhancedTheme.accentCyan
                                    .withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text('Shared across network',
                                style: TextStyle(
                                    color: EnhancedTheme.accentCyan
                                        .withValues(alpha: 0.8),
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (canWrite)
                  Icon(Icons.edit_rounded,
                      color: Colors.white.withValues(alpha: 0.3), size: 18),
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
        Icon(icon, size: 11, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
