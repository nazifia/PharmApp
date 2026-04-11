import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/models/user.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'All';

  final _roles = [
    'All', 'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech',
    'Salesperson', 'Cashier',
    'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson',
  ];

  final _createRoles = [
    'Admin', 'Manager', 'Pharmacist', 'Pharm-Tech',
    'Salesperson', 'Cashier',
    'Wholesale Manager', 'Wholesale Operator', 'Wholesale Salesperson',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin':                 return EnhancedTheme.errorRed;
      case 'Manager':               return EnhancedTheme.warningAmber;
      case 'Pharmacist':            return EnhancedTheme.primaryTeal;
      case 'Pharm-Tech':            return EnhancedTheme.successGreen;
      case 'Cashier':               return EnhancedTheme.accentCyan;
      case 'Salesperson':           return EnhancedTheme.accentPurple;
      case 'Wholesale Manager':     return EnhancedTheme.accentOrange;
      case 'Wholesale Operator':    return EnhancedTheme.infoBlue;
      case 'Wholesale Salesperson': return const Color(0xFF7C3AED);
      default:                      return EnhancedTheme.infoBlue;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'Admin':                 return Icons.admin_panel_settings_rounded;
      case 'Manager':               return Icons.manage_accounts_rounded;
      case 'Pharmacist':            return Icons.medical_services_rounded;
      case 'Pharm-Tech':            return Icons.science_rounded;
      case 'Cashier':               return Icons.point_of_sale_rounded;
      case 'Salesperson':           return Icons.sell_rounded;
      case 'Wholesale Manager':     return Icons.warehouse_rounded;
      case 'Wholesale Operator':    return Icons.inventory_2_rounded;
      case 'Wholesale Salesperson': return Icons.storefront_rounded;
      default:                      return Icons.person_rounded;
    }
  }

  List<User> _applyFilter(List<User> users) {
    final q = _searchCtrl.text;
    return users.where((u) {
      if (q.isNotEmpty && !u.phoneNumber.contains(q)) return false;
      if (_roleFilter != 'All' && u.role != _roleFilter) return false;
      return true;
    }).toList();
  }

  // ─── Input decoration helper ─────────────────────────────────────────────
  InputDecoration _inputDecoration(BuildContext ctx, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: ctx.hintColor, fontSize: 13),
      filled: true,
      fillColor: ctx.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ctx.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
            color: EnhancedTheme.primaryTeal, width: 1.5),
      ),
      errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─── Add user sheet ───────────────────────────────────────────────────────
  void _showAddUserSheet() {
    final phoneCtrl    = TextEditingController();
    final passCtrl     = TextEditingController();
    final usernameCtrl = TextEditingController();
    String role        = 'Cashier';
    final formKey      = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: ctx.isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(
                      color: EnhancedTheme.primaryTeal
                          .withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
                padding:
                    const EdgeInsets.fromLTRB(24, 16, 24, 36),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Handle ─────────────────────────────────────
                      Center(
                        child: Container(
                          width: 44, height: 4,
                          decoration: BoxDecoration(
                            color: ctx.dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Title row ──────────────────────────────────
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: EnhancedTheme.primaryTeal, size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add New User',
                          style: GoogleFonts.outfit(
                            color: ctx.labelColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 22),

                      // ── Username ──────────────────────────────────
                      TextFormField(
                        controller: usernameCtrl,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        style: GoogleFonts.inter(
                            color: ctx.labelColor, fontSize: 14),
                        decoration:
                            _inputDecoration(ctx, 'Username'),
                      ),
                      const SizedBox(height: 12),

                      // ── Phone ──────────────────────────────────────
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        style: GoogleFonts.inter(
                            color: ctx.labelColor, fontSize: 14),
                        decoration:
                            _inputDecoration(ctx, 'Phone Number'),
                      ),
                      const SizedBox(height: 12),

                      // ── Password ──────────────────────────────────
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        style: GoogleFonts.inter(
                            color: ctx.labelColor, fontSize: 14),
                        decoration:
                            _inputDecoration(ctx, 'Password'),
                      ),
                      const SizedBox(height: 18),

                      // ── Role chips ────────────────────────────────
                      Text(
                        'ASSIGN ROLE',
                        style: GoogleFonts.inter(
                          color: ctx.hintColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _createRoles.map((r) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setModal(() => role = r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: role == r
                                      ? _roleColor(r)
                                      : ctx.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: role == r
                                        ? _roleColor(r)
                                        : ctx.borderColor,
                                  ),
                                  boxShadow: role == r
                                      ? [
                                          BoxShadow(
                                            color: _roleColor(r)
                                                .withValues(alpha: 0.30),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  r,
                                  style: GoogleFonts.inter(
                                    color: role == r
                                        ? Colors.black
                                        : ctx.subLabelColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Submit button ─────────────────────────────
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0D9488),
                              Color(0xFF06B6D4),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: EnhancedTheme.primaryTeal
                                  .withValues(alpha: 0.40),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.of(ctx).pop();
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref
                                  .read(posApiProvider)
                                  .createUser(
                                    phoneNumber:
                                        phoneCtrl.text.trim(),
                                    password: passCtrl.text.trim(),
                                    role: role,
                                    username:
                                        usernameCtrl.text.trim(),
                                  );
                              if (!context.mounted) return;
                              setState(() {});
                              messenger.showSnackBar(SnackBar(
                                backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                                content: Row(children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(child: Text('User created', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                                ]),
                              ));
                            } catch (e) {
                              if (!context.mounted) return;
                              messenger.showSnackBar(SnackBar(
                                backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                                content: Row(children: [
                                  const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                                ]),
                              ));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Add User',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Change password dialog ───────────────────────────────────────────────
  void _showChangePasswordDialog(User user) {
    final passCtrl = TextEditingController();
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: EnhancedTheme.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_reset_rounded,
                color: EnhancedTheme.accentCyan, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Change Password',
            style: GoogleFonts.outfit(
              color: ctx.labelColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passCtrl,
            obscureText: true,
            autofocus: true,
            validator: (v) =>
                (v == null || v.length < 4) ? 'Min 4 characters' : null,
            style:
                GoogleFonts.inter(color: ctx.labelColor, fontSize: 14),
            decoration:
                _inputDecoration(ctx, 'New Password'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: ctx.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(posApiProvider)
                    .changePassword(user.id, passCtrl.text.trim());
                if (!context.mounted) return;
                messenger.showSnackBar(SnackBar(
                  backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  content: const Row(children: [
                    Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('Password changed', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                  ]),
                ));
              } catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(SnackBar(
                  backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  content: Row(children: [
                    const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                  ]),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.primaryTeal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Update',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Edit user sheet ──────────────────────────────────────────────────────
  void _showEditUserSheet(User user) {
    String role         = user.role;
    bool isActive       = user.isActive;
    final usernameCtrl  = TextEditingController(text: user.username);
    final fullnameCtrl  = TextEditingController(text: user.fullname);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: ctx.isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(
                      color: EnhancedTheme.accentPurple
                          .withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
                padding:
                    const EdgeInsets.fromLTRB(24, 16, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Handle ─────────────────────────────────────
                    Center(
                      child: Container(
                        width: 44, height: 4,
                        decoration: BoxDecoration(
                          color: ctx.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title row ──────────────────────────────────
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: EnhancedTheme.accentPurple
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: EnhancedTheme.accentPurple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit User',
                            style: GoogleFonts.outfit(
                              color: ctx.labelColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            user.username.isNotEmpty
                                ? user.username
                                : user.phoneNumber,
                            style: GoogleFonts.inter(
                              color: ctx.subLabelColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 22),

                    // ── Full Name field ────────────────────────────
                    TextField(
                      controller: fullnameCtrl,
                      style: GoogleFonts.inter(
                          color: ctx.labelColor, fontSize: 14),
                      decoration:
                          _inputDecoration(ctx, 'Full Name'),
                    ),
                    const SizedBox(height: 12),

                    // ── Username field ─────────────────────────────
                    TextField(
                      controller: usernameCtrl,
                      style: GoogleFonts.inter(
                          color: ctx.labelColor, fontSize: 14),
                      decoration:
                          _inputDecoration(ctx, 'Username'),
                    ),
                    const SizedBox(height: 18),

                    // ── Role chips ─────────────────────────────────
                    Text(
                      'ROLE',
                      style: GoogleFonts.inter(
                        color: ctx.hintColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _createRoles.map((r) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() => role = r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: role == r
                                    ? _roleColor(r)
                                    : ctx.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: role == r
                                      ? _roleColor(r)
                                      : ctx.borderColor,
                                ),
                                boxShadow: role == r
                                    ? [
                                        BoxShadow(
                                          color: _roleColor(r)
                                              .withValues(alpha: 0.30),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                r,
                                style: GoogleFonts.inter(
                                  color: role == r
                                      ? Colors.black
                                      : ctx.subLabelColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Status chips ───────────────────────────────
                    Text(
                      'STATUS',
                      style: GoogleFonts.inter(
                        color: ctx.hintColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      GestureDetector(
                        onTap: () => setModal(() => isActive = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: isActive
                                ? EnhancedTheme.successGreen
                                : ctx.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? EnhancedTheme.successGreen
                                  : ctx.borderColor,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: EnhancedTheme.successGreen
                                          .withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min,
                              children: [
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? Colors.black
                                    : ctx.subLabelColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Active',
                                style: GoogleFonts.inter(
                                  color: isActive
                                      ? Colors.black
                                      : ctx.subLabelColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setModal(() => isActive = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: !isActive
                                ? EnhancedTheme.errorRed
                                : ctx.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !isActive
                                  ? EnhancedTheme.errorRed
                                  : ctx.borderColor,
                            ),
                            boxShadow: !isActive
                                ? [
                                    BoxShadow(
                                      color: EnhancedTheme.errorRed
                                          .withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min,
                              children: [
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: !isActive
                                    ? Colors.black
                                    : ctx.subLabelColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Inactive',
                                style: GoogleFonts.inter(
                                  color: !isActive
                                      ? Colors.black
                                      : ctx.subLabelColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── Save button ───────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF06B6D4)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: EnhancedTheme.primaryTeal
                                .withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref.read(posApiProvider).updateUser(
                              user.id,
                              role: role,
                              isActive: isActive,
                              username: usernameCtrl.text.trim(),
                              fullname: fullnameCtrl.text.trim(),
                            );
                            if (!context.mounted) return;
                            setState(() {});
                            messenger.showSnackBar(SnackBar(
                              backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              content: const Row(children: [
                                Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                                SizedBox(width: 10),
                                Expanded(child: Text('User updated', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                              ]),
                            ));
                          } catch (e) {
                            if (!context.mounted) return;
                            messenger.showSnackBar(SnackBar(
                              backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                              content: Row(children: [
                                const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                              ]),
                            ));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Save Changes',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Permission overrides sheet ───────────────────────────────────────────
  void _showPermissionsSheet(User user) {
    final api = ref.read(posApiProvider);
    // overrides: permKey → 'inherit' | 'grant' | 'revoke'
    Map<String, String> overrides = {};
    List<Map<String, dynamic>> rows = [];
    bool loading = true;
    bool saving = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          // Load on first build
          if (loading && rows.isEmpty && error == null) {
            api.fetchUserPermissions(user.id).then((data) {
              final rawRows = (data['rows'] as List?) ?? [];
              setModal(() {
                rows = rawRows.cast<Map<String, dynamic>>();
                for (final r in rows) {
                  overrides[r['key'] as String] =
                      r['override_state'] as String? ?? 'inherit';
                }
                loading = false;
              });
            }).catchError((e) {
              setModal(() {
                error = e.toString();
                loading = false;
              });
            });
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: ctx.isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(
                        color: EnhancedTheme.accentOrange
                            .withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Handle ─────────────────────────────────
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 44, height: 4,
                          decoration: BoxDecoration(
                            color: ctx.dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Header ─────────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: EnhancedTheme.accentOrange
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.security_rounded,
                                color: EnhancedTheme.accentOrange,
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Permission Overrides',
                                    style: GoogleFonts.outfit(
                                      color: ctx.labelColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    )),
                                Text(
                                  user.username.isNotEmpty
                                      ? user.username
                                      : user.phoneNumber,
                                  style: GoogleFonts.inter(
                                    color: ctx.subLabelColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        child: Text(
                          'Overrides take priority over role defaults. '
                          'Set to Inherit to use role default.',
                          style: GoogleFonts.inter(
                              color: ctx.hintColor, fontSize: 11),
                        ),
                      ),
                      const Divider(height: 1),

                      // ── Body ───────────────────────────────────
                      Flexible(
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              )
                            : error != null
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(error!,
                                        style: GoogleFonts.inter(
                                            color:
                                                EnhancedTheme.errorRed)),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    itemCount: rows.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(
                                            height: 1,
                                            indent: 16,
                                            endIndent: 16),
                                    itemBuilder: (ctx, i) {
                                      final row = rows[i];
                                      final key =
                                          row['key'] as String;
                                      final label =
                                          row['label'] as String;
                                      final roleDefault =
                                          row['role_default'] as bool;
                                      final state =
                                          overrides[key] ?? 'inherit';
                                      final effective = state == 'grant'
                                          ? true
                                          : state == 'revoke'
                                              ? false
                                              : roleDefault;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 6),
                                        child: Row(children: [
                                          // Label + effective badge
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(label,
                                                    style: GoogleFonts.inter(
                                                      color: ctx.labelColor,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    )),
                                                Row(children: [
                                                  Icon(
                                                    effective
                                                        ? Icons
                                                            .check_circle_rounded
                                                        : Icons
                                                            .cancel_rounded,
                                                    color: effective
                                                        ? EnhancedTheme
                                                            .successGreen
                                                        : ctx.hintColor,
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    effective
                                                        ? 'Allowed'
                                                        : 'Denied',
                                                    style: GoogleFonts.inter(
                                                      color: effective
                                                          ? EnhancedTheme
                                                              .successGreen
                                                          : ctx.hintColor,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  if (roleDefault) ...[
                                                    const SizedBox(width: 6),
                                                    Text('role ✓',
                                                        style:
                                                            GoogleFonts.inter(
                                                          color:
                                                              ctx.hintColor,
                                                          fontSize: 10,
                                                        )),
                                                  ],
                                                ]),
                                              ],
                                            ),
                                          ),
                                          // 3-state toggle
                                          _PermToggle(
                                            value: state,
                                            onChanged: (v) => setModal(
                                                () => overrides[key] = v),
                                          ),
                                        ]),
                                      );
                                    },
                                  ),
                      ),

                      // ── Save button ────────────────────────────
                      if (!loading && error == null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EnhancedTheme.accentOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      setModal(() => saving = true);
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        await api.saveUserPermissions(
                                            user.id, overrides);
                                        // If the saved user is the currently
                                        // logged-in user, refresh their profile
                                        // so the new permissions take effect
                                        // immediately without re-login.
                                        final currentUser = ref.read(currentUserProvider);
                                        if (currentUser?.id == user.id) {
                                          await ref.read(authFlowProvider.notifier).refreshProfile();
                                        }
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (context.mounted) {
                                          messenger
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                'Permissions saved',
                                                style: GoogleFonts.inter()),
                                            backgroundColor:
                                                EnhancedTheme.successGreen,
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ));
                                        }
                                      } catch (e) {
                                        setModal(() {
                                          saving = false;
                                          error = e.toString();
                                        });
                                      }
                                    },
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                saving ? 'Saving…' : 'Save Permission Overrides',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Delete confirmation dialog ───────────────────────────────────────────
  void _showDeleteConfirmation(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: EnhancedTheme.errorRed, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Delete User',
            style: GoogleFonts.outfit(
              color: ctx.labelColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        content: Text(
          'Are you sure you want to delete '
          '${user.username.isNotEmpty ? user.username : user.phoneNumber} '
          '(${user.role})? This action cannot be undone.',
          style: GoogleFonts.inter(
              color: ctx.subLabelColor, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style:
                    GoogleFonts.inter(color: ctx.subLabelColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(posApiProvider)
                    .deleteUser(user.id);
                if (!context.mounted) return;
                setState(() {});
                messenger.showSnackBar(SnackBar(
                  backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  content: const Row(children: [
                    Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('User deleted', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                  ]),
                ));
              } catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(SnackBar(
                  backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  content: Row(children: [
                    const Icon(Icons.error_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Failed: $e', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                  ]),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.errorRed,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final api = ref.read(posApiProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserSheet,
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add User',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),

          // Decorative accent blob
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  EnhancedTheme.primaryTeal
                      .withValues(alpha: context.isDark ? 0.12 : 0.07),
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context)
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 4),
                _buildSearchBar()
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 8),
                _buildRoleFilterChips()
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: api.fetchUsers(),
                    builder: (_, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return _buildLoadingState();
                      }
                      if (snap.hasError) {
                        return _buildErrorState(snap.error);
                      }
                      final users = (snap.data ?? [])
                          .map((j) => User.fromJson(
                              j as Map<String, dynamic>))
                          .toList();
                      final filtered = _applyFilter(users);
                      if (filtered.isEmpty) {
                        return _buildEmptyState();
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            20, 8, 20, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _userCard(filtered[i])
                            .animate()
                            .fadeIn(
                              delay:
                                  Duration(milliseconds: i * 50),
                              duration: 350.ms,
                            )
                            .slideY(begin: 0.06, end: 0),
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

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: context.labelColor),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppShell.roleFallback(ref)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',
                  style: GoogleFonts.outfit(
                    color: context.labelColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Manage your pharmacy team',
                  style: GoogleFonts.inter(
                    color: context.subLabelColor, fontSize: 12),
                ),
              ],
            ),
          ),
          // Team icon badge
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    EnhancedTheme.primaryTeal.withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(Icons.people_rounded,
                color: EnhancedTheme.primaryTeal, size: 22),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(
                color: context.labelColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by phone number…',
              hintStyle: GoogleFonts.inter(
                  color: context.hintColor, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search, color: context.hintColor),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: context.hintColor, size: 18),
                      onPressed: () =>
                          setState(() => _searchCtrl.clear()),
                    )
                  : null,
              filled: true,
              fillColor: context.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: context.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: EnhancedTheme.primaryTeal, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Role filter chips ────────────────────────────────────────────────────
  Widget _buildRoleFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _roles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r      = _roles[i];
          final active = r == _roleFilter;
          final color  = r == 'All'
              ? EnhancedTheme.primaryTeal
              : _roleColor(r);
          return GestureDetector(
            onTap: () => setState(() => _roleFilter = r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? color : context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      active ? color : context.borderColor,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                r,
                style: GoogleFonts.inter(
                  color: active
                      ? Colors.black
                      : context.subLabelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Loading state ────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: EnhancedTheme.primaryTeal,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading users…',
            style: GoogleFonts.inter(
                color: context.subLabelColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────
  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: EnhancedTheme.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.cloud_off_rounded,
                color: EnhancedTheme.errorRed, size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load users',
            style: GoogleFonts.outfit(
              color: context.labelColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: GoogleFonts.inter(
              color: context.subLabelColor,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  EnhancedTheme.primaryTeal.withValues(alpha: 0.18),
                  EnhancedTheme.accentCyan.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.people_outline_rounded,
                color: EnhancedTheme.primaryTeal, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            'No Users Found',
            style: GoogleFonts.outfit(
              color: context.labelColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _roleFilter == 'All'
                ? 'No users in your organisation yet.'
                : 'No users with role "$_roleFilter".',
            style: GoogleFonts.inter(
                color: context.subLabelColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.92, 0.92)),
    );
  }

  // ─── User card ────────────────────────────────────────────────────────────
  Widget _userCard(User user) {
    final roleColor = _roleColor(user.role);
    final initials  = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : user.phoneNumber.isNotEmpty
            ? user.phoneNumber[0]
            : '?';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: roleColor.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Top accent strip ─────────────────────────────────
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: [
                      roleColor,
                      roleColor.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // ── Avatar with role icon ─────────────────────
                    Stack(
                      children: [
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                roleColor.withValues(alpha: 0.22),
                                roleColor.withValues(alpha: 0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  roleColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.outfit(
                                color: roleColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2, right: -2,
                          child: Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: roleColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.cardColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _roleIcon(user.role),
                              color: Colors.black, size: 10,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 14),

                    // ── Name + badges ─────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges row
                          Row(children: [
                            _roleBadge(user.role, roleColor),
                            const SizedBox(width: 6),
                            _statusBadge(user.isActive),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            user.username.isNotEmpty
                                ? user.username
                                : user.phoneNumber,
                            style: GoogleFonts.outfit(
                              color: context.labelColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (user.username.isEmpty && user.phoneNumber.isNotEmpty)
                            Text(
                              user.phoneNumber,
                              style: GoogleFonts.inter(
                                color: context.subLabelColor,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Action buttons ────────────────────────────
                    Column(
                      children: [
                        _iconButton(
                          Icons.edit_outlined,
                          EnhancedTheme.accentPurple,
                          () => _showEditUserSheet(user),
                        ),
                        const SizedBox(height: 6),
                        _iconButton(
                          Icons.security_rounded,
                          EnhancedTheme.accentOrange,
                          () => _showPermissionsSheet(user),
                        ),
                        const SizedBox(height: 6),
                        _iconButton(
                          Icons.lock_reset_rounded,
                          EnhancedTheme.accentCyan,
                          () => _showChangePasswordDialog(user),
                        ),
                        const SizedBox(height: 6),
                        _iconButton(
                          Icons.delete_outline_rounded,
                          EnhancedTheme.errorRed,
                          () => _showDeleteConfirmation(user),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        role,
        style: GoogleFonts.inter(
          color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    final color =
        isActive ? EnhancedTheme.successGreen : EnhancedTheme.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? 'Active' : 'Inactive',
          style: GoogleFonts.inter(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── 3-state permission toggle ─────────────────────────────────────────────────

class _PermToggle extends StatelessWidget {
  const _PermToggle({required this.value, required this.onChanged});
  final String value;           // 'inherit' | 'grant' | 'revoke'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _seg('Inherit', 'inherit', Colors.grey.shade600),
      const SizedBox(width: 4),
      _seg('Grant ↑', 'grant', EnhancedTheme.successGreen),
      const SizedBox(width: 4),
      _seg('Revoke ↓', 'revoke', EnhancedTheme.errorRed),
    ]);
  }

  Widget _seg(String label, String seg, Color activeColor) {
    final selected = value == seg;
    return GestureDetector(
      onTap: () => onChanged(seg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? activeColor : activeColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : activeColor,
          ),
        ),
      ),
    );
  }
}
