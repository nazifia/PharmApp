import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey    = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _fullnameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
    _fullnameCtrl = TextEditingController(text: user?.fullname ?? '');
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullnameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authFlowProvider.notifier).updateProfile(
            username: _usernameCtrl.text.trim(),
            fullname: _fullnameCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Expanded(
              child: Text('Profile updated',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600))),
        ]),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          Container(decoration: context.bgGradient),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _avatarSection(user?.role ?? 'U'),
                          const SizedBox(height: 24),
                          _formCard(context),
                          const SizedBox(height: 8),
                          _phoneReadOnly(user?.phoneNumber ?? '—'),
                          const SizedBox(height: 32),
                          _saveButton(),
                          const SizedBox(height: 32),
                        ],
                      ),
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/settings'),
        ),
        const SizedBox(width: 4),
        Text('Edit Profile',
            style: TextStyle(
                color: context.labelColor,
                fontSize: 20,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _avatarSection(String role) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
        child: Text(
          role.isNotEmpty ? role[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: EnhancedTheme.primaryTeal,
              fontSize: 32,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: [
            _field(
              controller: _usernameCtrl,
              label: 'Username',
              icon: Icons.person_outline_rounded,
              hint: 'Your display name',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Username required';
                if (v.trim().length < 3) return 'At least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _field(
              controller: _fullnameCtrl,
              label: 'Full Name',
              icon: Icons.badge_outlined,
              hint: 'Your full name',
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: context.labelColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: EnhancedTheme.primaryTeal, size: 20),
        labelStyle: TextStyle(color: context.subLabelColor, fontSize: 13),
        hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
        filled: true,
        fillColor: context.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: EnhancedTheme.errorRed)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _phoneReadOnly(String phone) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: context.hintColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.phone_outlined,
                  color: context.hintColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Phone Number',
                      style: TextStyle(
                          color: context.subLabelColor, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(phone,
                      style: TextStyle(
                          color: context.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ])),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.hintColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Cannot change',
                  style: TextStyle(
                      color: context.hintColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: EnhancedTheme.primaryTeal,
          foregroundColor: Colors.black,
          disabledBackgroundColor:
              EnhancedTheme.primaryTeal.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.black),
              )
            : const Text('Save Changes',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
