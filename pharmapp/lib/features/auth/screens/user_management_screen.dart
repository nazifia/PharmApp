import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/pos/providers/pos_api_provider.dart';
import 'package:pharmapp/shared/models/user.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
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
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin':                return EnhancedTheme.errorRed;
      case 'Manager':              return EnhancedTheme.warningAmber;
      case 'Pharmacist':           return EnhancedTheme.primaryTeal;
      case 'Pharm-Tech':           return EnhancedTheme.successGreen;
      case 'Cashier':              return EnhancedTheme.accentCyan;
      case 'Salesperson':          return EnhancedTheme.accentPurple;
      case 'Wholesale Manager':    return EnhancedTheme.accentOrange;
      case 'Wholesale Operator':   return EnhancedTheme.infoBlue;
      case 'Wholesale Salesperson':return const Color(0xFF7C3AED);
      default:                     return EnhancedTheme.infoBlue;
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

  void _showAddUserSheet() {
    final phoneCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    String role     = 'Cashier';
    final formKey   = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: ctx.dividerColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Add User', style: TextStyle(color: ctx.labelColor, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: phoneCtrl, keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  style: TextStyle(color: ctx.labelColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Phone Number', labelStyle: TextStyle(color: ctx.hintColor, fontSize: 13),
                    filled: true, fillColor: ctx.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ctx.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
                    errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtrl, obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  style: TextStyle(color: ctx.labelColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password', labelStyle: TextStyle(color: ctx.hintColor, fontSize: 13),
                    filled: true, fillColor: ctx.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ctx.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
                    errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text('Role:', style: TextStyle(color: ctx.subLabelColor, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _createRoles.map((r) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setModal(() => role = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: role == r ? _roleColor(r) : ctx.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: role == r ? _roleColor(r) : ctx.borderColor),
                          ),
                          child: Text(r, style: TextStyle(
                              color: role == r ? Colors.white : ctx.subLabelColor,
                              fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    )).toList()),
                  )),
                ]),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(ctx).pop();
                    try {
                      await ref.read(posApiProvider).createUser(
                        phoneNumber: phoneCtrl.text.trim(),
                        password: passCtrl.text.trim(),
                        role: role,
                      );
                      if (!context.mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('User created'),
                        backgroundColor: EnhancedTheme.successGreen));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: EnhancedTheme.errorRed));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Add User', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(User user) {
    final passCtrl = TextEditingController();
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Password', style: TextStyle(color: ctx.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passCtrl, obscureText: true, autofocus: true,
            validator: (v) => (v == null || v.length < 4) ? 'Min 4 characters' : null,
            style: TextStyle(color: ctx.labelColor, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'New Password', labelStyle: TextStyle(color: ctx.hintColor, fontSize: 13),
              filled: true, fillColor: ctx.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ctx.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
              errorStyle: const TextStyle(color: EnhancedTheme.errorRed),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: ctx.subLabelColor))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              try {
                await ref.read(posApiProvider).changePassword(user.id, passCtrl.text.trim());
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Password changed'),
                  backgroundColor: EnhancedTheme.successGreen));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed: $e'),
                  backgroundColor: EnhancedTheme.errorRed));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.primaryTeal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete User', style: TextStyle(color: ctx.labelColor, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Delete user ${user.phoneNumber} (${user.role})?',
            style: TextStyle(color: ctx.subLabelColor, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: ctx.subLabelColor))),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(posApiProvider).deleteUser(user.id);
                if (!context.mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('User deleted'),
                  backgroundColor: EnhancedTheme.successGreen));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed: $e'),
                  backgroundColor: EnhancedTheme.errorRed));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EnhancedTheme.errorRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(posApiProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserSheet,
        backgroundColor: EnhancedTheme.primaryTeal,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add User'),
      ),
      body: Stack(children: [
        Container(decoration: context.bgGradient),
        SafeArea(child: Column(children: [
          _buildHeader(context),
          _buildSearchBar(),
          _buildRoleFilterChips(),
          Expanded(child: FutureBuilder<List<dynamic>>(
            future: api.fetchUsers(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: EnhancedTheme.primaryTeal));
              }
              if (snap.hasError) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cloud_off_rounded, color: context.hintColor, size: 48),
                  const SizedBox(height: 12),
                  Text('${snap.error}', style: TextStyle(color: context.subLabelColor), textAlign: TextAlign.center),
                ]));
              }
              final users = (snap.data ?? []).map((j) => User.fromJson(j as Map<String, dynamic>)).toList();
              final filtered = _applyFilter(users);
              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, color: context.hintColor, size: 64),
                  const SizedBox(height: 16),
                  Text('No users found', style: TextStyle(color: context.subLabelColor, fontSize: 16)),
                ]));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _userCard(filtered[i]),
              );
            },
          )),
        ])),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
    child: Row(children: [
      IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.labelColor), onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref))),
      const SizedBox(width: 4),
      Expanded(child: Text('User Management',
          style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: ClipRRect(borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: TextField(
          controller: _searchCtrl, onChanged: (_) => setState(() {}),
          style: TextStyle(color: context.labelColor),
          decoration: InputDecoration(
            hintText: 'Search by phone number…',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: context.hintColor),
            filled: true, fillColor: context.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ),
  );

  Widget _buildRoleFilterChips() => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _roles.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final r = _roles[i]; final active = r == _roleFilter;
        final color = r == 'All' ? EnhancedTheme.primaryTeal : _roleColor(r);
        return GestureDetector(
          onTap: () => setState(() => _roleFilter = r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? color : context.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? color : context.borderColor),
            ),
            child: Text(r, style: TextStyle(
                color: active ? Colors.white : context.subLabelColor,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      },
    ),
  );

  Widget _userCard(User user) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
            child: Icon(Icons.person_rounded, color: _roleColor(user.role), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _roleColor(user.role).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _roleColor(user.role).withValues(alpha: 0.3)),
                ),
                child: Text(user.role, style: TextStyle(
                    color: _roleColor(user.role), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: user.isActive
                      ? EnhancedTheme.successGreen.withValues(alpha: 0.12)
                      : EnhancedTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: user.isActive
                      ? EnhancedTheme.successGreen.withValues(alpha: 0.3)
                      : EnhancedTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isActive ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                  )),
                  const SizedBox(width: 4),
                  Text(user.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(color: user.isActive ? EnhancedTheme.successGreen : EnhancedTheme.errorRed,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Text(user.phoneNumber, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          Column(children: [
            _iconButton(Icons.lock_reset_rounded, EnhancedTheme.accentCyan,
                () => _showChangePasswordDialog(user)),
            const SizedBox(height: 6),
            _iconButton(Icons.delete_outline_rounded, EnhancedTheme.errorRed,
                () => _showDeleteConfirmation(user)),
          ]),
        ]),
      ),
    ),
  );

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}
