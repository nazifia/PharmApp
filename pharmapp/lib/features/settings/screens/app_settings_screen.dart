import 'dart:async';
import 'dart:ui';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/network/api_client.dart';
import 'package:pharmapp/core/rbac/rbac.dart';
import 'package:pharmapp/core/rbac/rbac_provider.dart';
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
  bool _logoUploading        = false;
  bool _discovering          = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final isDark    = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isAdmin   = ref.watch(canProvider(AppPermission.manageSettings));

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
                      if (isAdmin) ...[
                        const SizedBox(height: 16),
                        _orgLogoCard(user),
                      ],
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
                      if (isAdmin) ...[
                        const SizedBox(height: 16),
                        _serverUrlCard(),
                      ],
                      const SizedBox(height: 16),
                      _sectionCard('System', [
                        _tapTile(
                          Icons.cleaning_services_outlined, 'Clear Cache',
                          'Free up local storage',
                          () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            content: const Row(children: [
                              Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                              SizedBox(width: 10),
                              Expanded(child: Text('Cache cleared', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
                            ]),
                          )),
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
              Text((user?.username.isNotEmpty == true ? user!.username : user?.phoneNumber) ?? '—',
                  style: TextStyle(color: context.labelColor, fontSize: 16, fontWeight: FontWeight.w600)),
              if ((user?.username ?? '').isEmpty && (user?.phoneNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(user!.phoneNumber,
                    style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ],
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

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    if (picked == null || !mounted) return;

    setState(() => _logoUploading = true);
    try {
      await ref.read(authFlowProvider.notifier).uploadOrgLogo(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Text('Logo updated', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        ]),
      ));
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
          Expanded(child: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ]),
      ));
    } finally {
      if (mounted) setState(() => _logoUploading = false);
    }
  }

  Widget _orgLogoCard(user) {
    final logoUrl = user?.organizationLogo as String?;
    final orgName = user?.organizationName as String? ?? '';
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

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
            // Logo preview
            GestureDetector(
              onTap: _logoUploading ? null : _pickAndUploadLogo,
              child: Stack(
                children: [
                  ClipOval(
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
                        border: Border.all(
                            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4), width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: hasLogo
                          ? Image.network(logoUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _logoFallback(orgName))
                          : _logoFallback(orgName),
                    ),
                  ),
                  if (_logoUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: EnhancedTheme.primaryTeal),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          color: EnhancedTheme.primaryTeal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, size: 13, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Organisation Logo',
                  style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(hasLogo ? 'Tap logo to change' : 'No logo set — tap to upload',
                  style: TextStyle(color: context.hintColor, fontSize: 12)),
              if (orgName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(orgName,
                    style: TextStyle(color: context.subLabelColor, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ])),
            TextButton.icon(
              onPressed: _logoUploading ? null : _pickAndUploadLogo,
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Upload'),
              style: TextButton.styleFrom(
                foregroundColor: EnhancedTheme.primaryTeal,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _logoFallback(String orgName) {
    final initial = orgName.isNotEmpty ? orgName[0].toUpperCase() : 'O';
    return Center(
      child: Text(initial,
          style: const TextStyle(color: EnhancedTheme.primaryTeal, fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _discoverLanServer() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.warningAmber.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Auto-discover not supported on web',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
        ]),
      ));
      return;
    }

    setState(() => _discovering = true);

    final discovery = BonsoirDiscovery(type: '_pharmapp._tcp');
    String? foundUrl;

    try {
      await discovery.ready;
      await discovery.start();

      final completer = Completer<String?>();
      late StreamSubscription<BonsoirDiscoveryEvent> sub;

      sub = discovery.eventStream!.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          event.service!.resolve(discovery.serviceResolver);
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final svc = event.service as ResolvedBonsoirService;
          final host = svc.host ?? '';
          final port = svc.port;
          final path = svc.attributes['path'] ?? '/api';
          if (host.isNotEmpty && !completer.isCompleted) {
            completer.complete('http://$host:$port$path');
          }
        }
      });

      foundUrl = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      await sub.cancel();
      await discovery.stop();

      if (!mounted) return;

      if (foundUrl != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_base_url', foundUrl);
        ref.read(baseUrlProvider.notifier).state = foundUrl;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Found: $foundUrl',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
            ]),
          ));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: const Row(children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('No PharmApp server found on LAN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } catch (e) {
      await discovery.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: EnhancedTheme.errorRed.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Discovery error: $e',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ]),
        ));
      }
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Widget _serverUrlCard() {
    final currentUrl = ref.watch(baseUrlProvider);
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
              child: Text('Network', style: TextStyle(
                  color: context.subLabelColor, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            InkWell(
              onTap: () => _showServerUrlDialog(currentUrl),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _tileIcon(Icons.dns_outlined, EnhancedTheme.accentPurple),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Server URL',
                        style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(currentUrl,
                        style: TextStyle(color: context.hintColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ])),
                  Icon(Icons.edit_outlined, color: context.hintColor, size: 18),
                ]),
              ),
            ),
            _divider(),
            InkWell(
              onTap: _discovering ? null : _discoverLanServer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _tileIcon(Icons.wifi_find_outlined, EnhancedTheme.accentCyan),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Auto-discover',
                        style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('Find LAN server automatically',
                        style: TextStyle(color: context.hintColor, fontSize: 12)),
                  ])),
                  if (_discovering)
                    SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: EnhancedTheme.accentCyan),
                    )
                  else
                    Icon(Icons.search_rounded, color: context.hintColor, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Future<void> _showServerUrlDialog(String current) async {
    final controller = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Server URL', style: TextStyle(color: context.labelColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the IP address of your local Django server.',
              style: TextStyle(color: context.subLabelColor, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: context.labelColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.10:8000/api',
              hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
              filled: true,
              fillColor: context.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.borderColor)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: EnhancedTheme.primaryTeal)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save', style: TextStyle(color: EnhancedTheme.primaryTeal))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
    ref.read(baseUrlProvider.notifier).state = url;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text('Server URL saved', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600))),
      ]),
    ));
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

  Widget _switchTile(IconData icon, String title, String sub, bool val,
      ValueChanged<bool> onChanged, {Color? activeColor}) {
    final color = activeColor ?? EnhancedTheme.primaryTeal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _tileIcon(icon, color),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(color: context.hintColor, fontSize: 12)),
        ])),
        Switch(value: val, onChanged: onChanged,
            activeThumbColor: color,
            trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? color.withValues(alpha: 0.3)
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
