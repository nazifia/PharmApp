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
import 'package:pharmapp/features/networks/providers/network_provider.dart';
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
                        const SizedBox(height: 16),
                        _networkCard(),
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
              if ((user?.fullname ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(user!.fullname,
                    style: TextStyle(color: context.subLabelColor, fontSize: 12)),
              ] else if ((user?.username ?? '').isEmpty && (user?.phoneNumber ?? '').isNotEmpty) ...[
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
            IconButton(
              tooltip: 'Edit profile',
              icon: Icon(Icons.edit_outlined, color: context.hintColor, size: 20),
              onPressed: () => context.push('/dashboard/settings/edit-profile'),
            ),
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
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Organisation',
                  style: TextStyle(
                      color: context.subLabelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            // ── Logo row ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: _logoUploading ? null : _pickAndUploadLogo,
                  child: Stack(
                    children: [
                      ClipOval(
                        child: Container(
                          width: 56, height: 56,
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
                                width: 20, height: 20,
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
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: EnhancedTheme.primaryTeal,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded, size: 11, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Logo',
                      style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(hasLogo ? 'Tap to change' : 'No logo — tap to upload',
                      style: TextStyle(color: context.hintColor, fontSize: 12)),
                ])),
                TextButton.icon(
                  onPressed: _logoUploading ? null : _pickAndUploadLogo,
                  icon: const Icon(Icons.upload_rounded, size: 15),
                  label: const Text('Upload'),
                  style: TextButton.styleFrom(
                    foregroundColor: EnhancedTheme.primaryTeal,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: context.dividerColor),
            // ── Org name row ─────────────────────────────────────────────────
            InkWell(
              onTap: () => _showOrgNameDialog(orgName),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _tileIcon(Icons.business_rounded, EnhancedTheme.accentOrange),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Organisation Name',
                        style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(orgName.isNotEmpty ? orgName : 'Not set',
                        style: TextStyle(color: context.hintColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ])),
                  Icon(Icons.edit_outlined, color: context.hintColor, size: 18),
                ]),
              ),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: context.dividerColor),
            // ── Org address row ───────────────────────────────────────────────
            Builder(builder: (context) {
              final orgAddress = user?.organizationAddress as String? ?? '';
              return InkWell(
                onTap: () => _showOrgAddressDialog(orgAddress),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    _tileIcon(Icons.location_on_outlined, EnhancedTheme.accentCyan),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Address',
                          style: TextStyle(color: context.labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(orgAddress.isNotEmpty ? orgAddress : 'Not set',
                          style: TextStyle(color: context.hintColor, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ])),
                    Icon(Icons.edit_outlined, color: context.hintColor, size: 18),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Future<void> _showOrgNameDialog(String current) async {
    final ctrl = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Organisation Name', style: TextStyle(color: context.labelColor)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter organisation name',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
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
                borderSide: const BorderSide(color: EnhancedTheme.accentOrange)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(color: EnhancedTheme.accentOrange))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty || name == current) return;
    try {
      await ref.read(authFlowProvider.notifier).updateOrgName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Text('Organisation name updated',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
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
    }
  }

  Future<void> _showOrgAddressDialog(String current) async {
    final ctrl = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Organisation Address', style: TextStyle(color: context.labelColor)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: context.labelColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter organisation address',
            hintStyle: TextStyle(color: context.hintColor, fontSize: 13),
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
                borderSide: const BorderSide(color: EnhancedTheme.accentCyan)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(color: EnhancedTheme.accentCyan))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final address = ctrl.text.trim();
    if (address == current) return;
    try {
      await ref.read(authFlowProvider.notifier).updateOrgAddress(address);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: EnhancedTheme.successGreen.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Text('Address updated',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
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
    }
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
                    const SizedBox(
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

  Widget _divider() => Divider(height: 1, indent: 66, endIndent: 16, color: context.dividerColor);

  Widget _networkCard() {
    final networksAsync = ref.watch(myNetworksProvider);
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
              child: Text('Pharmacy Network',
                  style: TextStyle(
                      color: context.subLabelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            InkWell(
              onTap: () => _NetworkSheet.show(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _tileIcon(Icons.hub_rounded, EnhancedTheme.accentPurple),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Manage Networks',
                          style: TextStyle(
                              color: context.labelColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      networksAsync.when(
                        data: (list) {
                          final active  = list.where((m) => m.isActive).length;
                          final pending = list.where((m) => m.isPending).length;
                          return Text(
                            active == 0
                                ? 'Not in any network yet'
                                : '$active active network${active == 1 ? '' : 's'}'
                                  '${pending > 0 ? '  ·  $pending pending' : ''}',
                            style: TextStyle(color: context.hintColor, fontSize: 12),
                          );
                        },
                        loading: () => Text('Loading…',
                            style: TextStyle(color: context.hintColor, fontSize: 12)),
                        error: (_, __) => Text('Tap to manage',
                            style: TextStyle(color: context.hintColor, fontSize: 12)),
                      ),
                    ]),
                  ),
                  networksAsync.maybeWhen(
                    data: (list) {
                      final pending = list.where((m) => m.isPending).length;
                      if (pending == 0) return Icon(Icons.chevron_right, color: context.hintColor, size: 18);
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.warningAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: EnhancedTheme.warningAmber.withValues(alpha: 0.4)),
                          ),
                          child: Text('$pending',
                              style: const TextStyle(
                                  color: EnhancedTheme.warningAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, color: context.hintColor, size: 18),
                      ]);
                    },
                    orElse: () => Icon(Icons.chevron_right, color: context.hintColor, size: 18),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

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

// ── Network management bottom sheet ──────────────────────────────────────────

class _NetworkSheet extends ConsumerStatefulWidget {
  const _NetworkSheet();

  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NetworkSheet(),
    );
  }

  @override
  ConsumerState<_NetworkSheet> createState() => _NetworkSheetState();
}

class _NetworkSheetState extends ConsumerState<_NetworkSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberships  = ref.watch(myNetworksProvider);
    final notifier     = ref.watch(networkNotifierProvider);
    final isLoading    = notifier is AsyncLoading;
    final isDark       = context.isDark;
    final sheetBg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg       = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor  = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(children: [
              const Icon(Icons.hub_rounded, color: EnhancedTheme.accentPurple, size: 22),
              const SizedBox(width: 10),
              Text('Pharmacy Network',
                  style: TextStyle(
                      color: context.labelColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: EnhancedTheme.accentPurple)),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isLoading ? null : () => _showCreateDialog(),
                style: FilledButton.styleFrom(
                  backgroundColor: EnhancedTheme.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New'),
              ),
            ]),
          ),
          // Tabs
          TabBar(
            controller: _tabs,
            labelColor: EnhancedTheme.accentPurple,
            unselectedLabelColor: context.hintColor,
            indicatorColor: EnhancedTheme.accentPurple,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              const Tab(text: 'My Networks'),
              Tab(
                child: memberships.maybeWhen(
                  data: (list) {
                    final p = list.where((m) => m.isPending).length;
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Invitations'),
                      if (p > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: EnhancedTheme.warningAmber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$p',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]);
                  },
                  orElse: () => const Text('Invitations'),
                ),
              ),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // ── Active networks ──────────────────────────────────────────
                memberships.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: EnhancedTheme.accentPurple)),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: TextStyle(color: context.hintColor))),
                  data: (list) {
                    final active = list.where((m) => m.isActive).toList();
                    if (active.isEmpty) {
                      return Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.hub_outlined, size: 52,
                              color: context.hintColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text('No active networks',
                              style: TextStyle(color: context.hintColor, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('Create one or accept an invitation.',
                              style: TextStyle(
                                  color: context.hintColor.withValues(alpha: 0.7),
                                  fontSize: 13)),
                        ]),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: active.length,
                      itemBuilder: (_, i) => _NetworkCard(
                        membership: active[i],
                        cardBg: cardBg,
                        borderColor: borderColor,
                        onManage: () => _showNetworkDetail(active[i]),
                        onLeave: () => _leave(active[i]),
                      ),
                    );
                  },
                ),
                // ── Pending invitations ──────────────────────────────────────
                memberships.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: EnhancedTheme.accentPurple)),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: TextStyle(color: context.hintColor))),
                  data: (list) {
                    final pending = list.where((m) => m.isPending).toList();
                    if (pending.isEmpty) {
                      return Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.mail_outline_rounded, size: 52,
                              color: context.hintColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text('No pending invitations',
                              style: TextStyle(color: context.hintColor, fontSize: 15)),
                        ]),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: pending.length,
                      itemBuilder: (_, i) => _InviteCard(
                        membership: pending[i],
                        cardBg: cardBg,
                        borderColor: borderColor,
                        onAccept: () => _accept(pending[i]),
                        onDecline: () => _decline(pending[i]),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Create Network', style: TextStyle(color: context.labelColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: TextStyle(color: context.labelColor),
            decoration: InputDecoration(
              labelText: 'Network name',
              labelStyle: TextStyle(color: context.hintColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: EnhancedTheme.accentPurple)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            style: TextStyle(color: context.labelColor),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: TextStyle(color: context.hintColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: EnhancedTheme.accentPurple)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create',
                  style: TextStyle(color: EnhancedTheme.accentPurple))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final result = await ref
        .read(networkNotifierProvider.notifier)
        .createNetwork(name, description: descCtrl.text.trim());
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(myNetworksProvider);
      _snack('Network "${result.name}" created', success: true);
    } else {
      final err = ref.read(networkNotifierProvider);
      _snack(err is AsyncError ? err.error.toString() : 'Failed to create network');
    }
  }

  Future<void> _showNetworkDetail(NetworkMembership m) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NetworkDetailSheet(networkId: m.networkId, isOwner: m.isOwner),
    );
    ref.invalidate(myNetworksProvider);
  }

  Future<void> _accept(NetworkMembership m) async {
    final ok = await ref.read(networkNotifierProvider.notifier).acceptInvitation(m.networkId);
    if (!mounted) return;
    if (ok) {
      _snack('Joined "${m.networkName}"', success: true);
      _tabs.animateTo(0);
    } else {
      _snack('Failed to accept invitation');
    }
  }

  Future<void> _decline(NetworkMembership m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Decline Invitation', style: TextStyle(color: context.labelColor)),
        content: Text('Decline invitation to "${m.networkName}"?',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Decline', style: TextStyle(color: EnhancedTheme.errorRed))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(networkNotifierProvider.notifier).declineInvitation(m.networkId);
    if (mounted) _snack('Invitation declined');
  }

  Future<void> _leave(NetworkMembership m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Leave Network', style: TextStyle(color: context.labelColor)),
        content: Text(
            m.isOwner
                ? 'You are the owner. Leaving will disband "${m.networkName}" for all members.'
                : 'Leave "${m.networkName}"?',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(m.isOwner ? 'Disband' : 'Leave',
                  style: const TextStyle(color: EnhancedTheme.errorRed))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(networkNotifierProvider.notifier).leaveNetwork(m.networkId);
    if (mounted && ok) _snack('Left "${m.networkName}"', success: true);
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: (success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
          .withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: success ? Colors.black : Colors.white,
            size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: TextStyle(
                color: success ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600))),
      ]),
    ));
  }
}

// ── Network card (active) ─────────────────────────────────────────────────────

class _NetworkCard extends StatelessWidget {
  final NetworkMembership membership;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onManage;
  final VoidCallback onLeave;

  const _NetworkCard({
    required this.membership,
    required this.cardBg,
    required this.borderColor,
    required this.onManage,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final m = membership;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded,
                  color: EnhancedTheme.accentPurple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.networkName,
                  style: TextStyle(
                      color: context.labelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text(m.networkSlug,
                  style: TextStyle(color: context.hintColor, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (m.isOwner
                    ? EnhancedTheme.warningAmber
                    : EnhancedTheme.accentCyan).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (m.isOwner
                        ? EnhancedTheme.warningAmber
                        : EnhancedTheme.accentCyan).withValues(alpha: 0.35)),
              ),
              child: Text(m.isOwner ? 'Owner' : 'Member',
                  style: TextStyle(
                      color: m.isOwner
                          ? EnhancedTheme.warningAmber
                          : EnhancedTheme.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.settings_rounded, size: 15),
                label: const Text('Manage', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EnhancedTheme.accentPurple,
                  side: BorderSide(
                      color: EnhancedTheme.accentPurple.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onLeave,
              style: OutlinedButton.styleFrom(
                foregroundColor: EnhancedTheme.errorRed,
                side: BorderSide(
                    color: EnhancedTheme.errorRed.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              ),
              child: Text(m.isOwner ? 'Disband' : 'Leave',
                  style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Invite card (pending) ─────────────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final NetworkMembership membership;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({
    required this.membership,
    required this.cardBg,
    required this.borderColor,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final m = membership;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: EnhancedTheme.warningAmber.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EnhancedTheme.warningAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mail_outline_rounded,
                  color: EnhancedTheme.warningAmber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.networkName,
                  style: TextStyle(
                      color: context.labelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Text('Invitation pending',
                  style: TextStyle(
                      color: EnhancedTheme.warningAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_rounded, size: 15),
                label: const Text('Accept', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: EnhancedTheme.successGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDecline,
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Decline', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EnhancedTheme.errorRed,
                  side: BorderSide(
                      color: EnhancedTheme.errorRed.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Network detail sheet (members + invite) ───────────────────────────────────

class _NetworkDetailSheet extends ConsumerStatefulWidget {
  final int networkId;
  final bool isOwner;

  const _NetworkDetailSheet({required this.networkId, required this.isOwner});

  @override
  ConsumerState<_NetworkDetailSheet> createState() => _NetworkDetailSheetState();
}

class _NetworkDetailSheetState extends ConsumerState<_NetworkDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final networkAsync = ref.watch(networkDetailProvider(widget.networkId));
    final notifier     = ref.watch(networkNotifierProvider);
    final isLoading    = notifier is AsyncLoading;
    final isDark       = context.isDark;
    final sheetBg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          networkAsync.when(
            loading: () => const Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: EnhancedTheme.accentPurple))),
            error: (e, _) => Expanded(
                child: Center(
                    child: Text(e.toString(),
                        style: TextStyle(color: context.hintColor)))),
            data: (network) => Expanded(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(network.name,
                            style: TextStyle(
                                color: context.labelColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text('${network.memberCount} member${network.memberCount == 1 ? '' : 's'}',
                            style: TextStyle(color: context.hintColor, fontSize: 12)),
                      ]),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: EnhancedTheme.accentPurple)),
                    if (widget.isOwner) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: isLoading ? null : () => _showInviteDialog(network.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: EnhancedTheme.accentPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 15),
                        label: const Text('Invite'),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: network.members.length,
                    itemBuilder: (_, i) {
                      final member = network.members[i];
                      final bgColor = isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white;
                      final borderCol = isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                EnhancedTheme.accentPurple.withValues(alpha: 0.12),
                            child: Text(
                              member.organizationName.isNotEmpty
                                  ? member.organizationName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: EnhancedTheme.accentPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.organizationName,
                                    style: TextStyle(
                                        color: context.labelColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(member.organizationSlug,
                                    style: TextStyle(
                                        color: context.hintColor, fontSize: 11)),
                              ])),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            _statusChip(member.role, member.status),
                            if (widget.isOwner && member.role != 'owner') ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeMember(
                                    network.id, member.organizationId, member.organizationName),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: EnhancedTheme.errorRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.person_remove_rounded,
                                      size: 14, color: EnhancedTheme.errorRed),
                                ),
                              ),
                            ],
                          ]),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statusChip(String role, String status) {
    final isOwner = role == 'owner';
    final isPending = status == 'pending';
    final color = isOwner
        ? EnhancedTheme.warningAmber
        : isPending
            ? EnhancedTheme.accentCyan.withValues(alpha: 0.6)
            : EnhancedTheme.accentCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isOwner ? 'Owner' : isPending ? 'Pending' : 'Member',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _showInviteDialog(int networkId) async {
    final slugCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Invite Pharmacy', style: TextStyle(color: context.labelColor)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the pharmacy\'s organisation slug.',
              style: TextStyle(color: context.subLabelColor, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: slugCtrl,
            autofocus: true,
            style: TextStyle(color: context.labelColor),
            decoration: InputDecoration(
              labelText: 'Org slug',
              hintText: 'e.g. city-pharmacy',
              labelStyle: TextStyle(color: context.hintColor),
              hintStyle: TextStyle(color: context.hintColor, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: EnhancedTheme.accentPurple)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Invite',
                  style: TextStyle(color: EnhancedTheme.accentPurple))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final slug = slugCtrl.text.trim();
    if (slug.isEmpty) return;
    final result = await ref.read(networkNotifierProvider.notifier).inviteOrg(networkId, slug);
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(networkDetailProvider(networkId));
      _snack('Invitation sent to "${result.organizationName}"', success: true);
    } else {
      final err = ref.read(networkNotifierProvider);
      _snack(err is AsyncError
          ? err.error.toString().replaceFirst('Exception: ', '')
          : 'Failed to send invitation');
    }
  }

  Future<void> _removeMember(int networkId, int orgId, String orgName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Remove Member', style: TextStyle(color: context.labelColor)),
        content: Text('Remove "$orgName" from this network?',
            style: TextStyle(color: context.subLabelColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: context.hintColor))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: EnhancedTheme.errorRed))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(networkNotifierProvider.notifier).removeMember(networkId, orgId);
    if (mounted && ok) {
      ref.invalidate(networkDetailProvider(networkId));
      _snack('$orgName removed', success: true);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: (success ? EnhancedTheme.successGreen : EnhancedTheme.errorRed)
          .withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      content: Row(children: [
        Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: success ? Colors.black : Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: TextStyle(
                color: success ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600))),
      ]),
    ));
  }
}
