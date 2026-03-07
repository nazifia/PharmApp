import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode             = true;
  String _language           = 'English';

  final _apiUrlCtrl = TextEditingController(text: 'https://api.pharmapp.com');

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: EnhancedTheme.primaryDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0F1E), Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _profileCard(user),
                      const SizedBox(height: 16),
                      _sectionCard('Preferences', [
                        _switchTile(
                          Icons.dark_mode_outlined, 'Dark Mode',
                          'Adjust the app appearance',
                          _darkMode,
                          (v) => setState(() => _darkMode = v),
                        ),
                        _divider(),
                        _switchTile(
                          Icons.notifications_outlined, 'Notifications',
                          'Low stock, expiry and payment alerts',
                          _notificationsEnabled,
                          (v) => setState(() => _notificationsEnabled = v),
                        ),
                        _divider(),
                        _dropdownTile(
                          Icons.language_outlined, 'Language',
                          _language, ['English', 'Hausa', 'Yoruba', 'Igbo'],
                          (v) { if (v != null) setState(() => _language = v); },
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _sectionCard('System', [
                        _inputTile(
                          Icons.cloud_outlined, 'API Server URL',
                          _apiUrlCtrl,
                        ),
                        _divider(),
                        _tapTile(
                          Icons.cleaning_services_outlined, 'Clear Cache',
                          'Free up local storage',
                          () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cache cleared'))),
                        ),
                        _divider(),
                        _tapTile(
                          Icons.info_outline, 'About PharmApp',
                          'Version 1.0.0  ·  Build 1',
                          () {},
                          trailing: const Text('v1.0.0',
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _sectionCard('Account', [
                        _tapTile(
                          Icons.logout_rounded, 'Logout',
                          'Sign out from this device',
                          () => _confirmLogout(context),
                          iconColor: EnhancedTheme.errorRed,
                          textColor: EnhancedTheme.errorRed,
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ],
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
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 4),
        const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _profileCard(user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: EnhancedTheme.primaryTeal.withOpacity(0.2),
              child: Text(
                (user?.role ?? 'U').isNotEmpty ? user!.role[0].toUpperCase() : 'U',
                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.phoneNumber ?? '—',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withOpacity(0.3)),
                ),
                child: Text(user?.role ?? 'Unknown',
                    style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title, style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            ...children,
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, String sub, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _tileIcon(icon, EnhancedTheme.primaryTeal),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        ])),
        Switch(value: val, onChanged: onChanged,
            activeColor: EnhancedTheme.primaryTeal,
            trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? EnhancedTheme.primaryTeal.withOpacity(0.3)
                    : Colors.white.withOpacity(0.12))),
      ]),
    );
  }

  Widget _dropdownTile(IconData icon, String title, String val,
      List<String> opts, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _tileIcon(icon, EnhancedTheme.accentCyan),
        const SizedBox(width: 14),
        Expanded(child: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        DropdownButton<String>(
          value: val, items: opts.map((o) => DropdownMenuItem(value: o,
              child: Text(o, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1E293B),
          underline: const SizedBox(),
          iconEnabledColor: Colors.white38,
          style: const TextStyle(color: Colors.white),
        ),
      ]),
    );
  }

  Widget _inputTile(IconData icon, String title, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _tileIcon(icon, EnhancedTheme.infoBlue),
          const SizedBox(width: 14),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
    );
  }

  Widget _tapTile(IconData icon, String title, String sub, VoidCallback onTap,
      {Color iconColor = EnhancedTheme.primaryTeal, Color textColor = Colors.white, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _tileIcon(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ])),
          trailing ?? Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.25), size: 18),
        ]),
      ),
    );
  }

  Widget _tileIcon(IconData icon, Color color) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _divider() => Divider(
      height: 1, indent: 66, endIndent: 16, color: Colors.white.withOpacity(0.07));

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: EnhancedTheme.errorRed))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authServiceProvider).logout();
      if (mounted) context.go('/login');
    }
  }
}
