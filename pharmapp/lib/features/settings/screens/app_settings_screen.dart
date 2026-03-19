import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/core/services/auth_service.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';
import 'package:pharmapp/core/theme/theme_provider.dart';
import 'package:pharmapp/features/auth/providers/auth_provider.dart';
import 'package:pharmapp/shared/widgets/app_shell.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  String _language           = 'English';

  late final TextEditingController _apiUrlCtrl;

  @override
  void initState() {
    super.initState();
    final currentUrl = ref.read(baseUrlProvider);
    _apiUrlCtrl = TextEditingController(text: currentUrl);
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final isDark    = ref.watch(themeModeProvider) == ThemeMode.dark;

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
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _profileCard(user),
                      const SizedBox(height: 16),
                      _sectionCard('Preferences', [
                        _switchTile(
                          Icons.dark_mode_outlined, 'Dark Mode',
                          'Adjust the app appearance',
                          isDark,
                          (v) => ref.read(themeModeProvider.notifier)
                              .setMode(v ? ThemeMode.dark : ThemeMode.light),
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
                          trailing: Text('v1.0.0',
                              style: TextStyle(color: context.hintColor, fontSize: 12)),
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
          icon: Icon(Icons.arrow_back_rounded, color: context.labelColor),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppShell.roleFallback(ref)),
        ),
        const SizedBox(width: 4),
        Text('Settings', style: TextStyle(color: context.labelColor, fontSize: 20, fontWeight: FontWeight.w600)),
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
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
              child: Text(
                (user?.role ?? 'U').isNotEmpty ? user!.role[0].toUpperCase() : 'U',
                style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.phoneNumber ?? '—',
                  style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: EnhancedTheme.primaryTeal.withValues(alpha: 0.3)),
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
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title, style: TextStyle(
                  color: context.subLabelColor, fontSize: 11,
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
          Text(title, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(color: context.hintColor, fontSize: 12)),
        ])),
        Switch(value: val, onChanged: onChanged,
            activeThumbColor: EnhancedTheme.primaryTeal,
            trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? EnhancedTheme.primaryTeal.withValues(alpha: 0.3)
                    : context.borderColor)),
      ]),
    );
  }

  Widget _dropdownTile(IconData icon, String title, String val,
      List<String> opts, ValueChanged<String?> onChanged) {
    final dropBg = context.isDark ? const Color(0xFF1E293B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _tileIcon(icon, EnhancedTheme.accentCyan),
        const SizedBox(width: 14),
        Expanded(child: Text(title,
            style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500))),
        DropdownButton<String>(
          value: val, items: opts.map((o) => DropdownMenuItem(value: o,
              child: Text(o, style: TextStyle(color: context.labelColor, fontSize: 13)))).toList(),
          onChanged: onChanged,
          dropdownColor: dropBg,
          underline: const SizedBox(),
          iconEnabledColor: context.hintColor,
          style: TextStyle(color: context.labelColor),
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
          Text(title, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          style: TextStyle(color: context.labelColor, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
    );
  }

  Widget _tapTile(IconData icon, String title, String sub, VoidCallback onTap,
      {Color? iconColor, Color? textColor, Widget? trailing}) {
    final ic = iconColor ?? EnhancedTheme.primaryTeal;
    final tc = textColor ?? context.labelColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _tileIcon(icon, ic),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: tc, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(sub, style: TextStyle(color: context.hintColor, fontSize: 12)),
          ])),
          trailing ?? Icon(Icons.chevron_right, color: context.hintColor, size: 18),
        ]),
      ),
    );
  }

  Widget _tileIcon(IconData icon, Color color) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: color.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _divider() => Divider(
      height: 1, indent: 66, endIndent: 16, color: context.dividerColor);

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Logout', style: TextStyle(color: context.labelColor)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: EnhancedTheme.errorRed))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authServiceProvider).logout();
      if (!context.mounted) return;
      context.go('/login');
    }
  }
}
