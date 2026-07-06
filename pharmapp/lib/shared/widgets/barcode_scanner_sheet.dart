import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

const _kScannerFacingKey = 'scanner_camera_facing';

class BarcodeScannerSheet extends StatefulWidget {
  final void Function(String code) onBarcodeScanned;

  const BarcodeScannerSheet({super.key, required this.onBarcodeScanned});

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  late final MobileScannerController _controller;
  final TextEditingController _manualCtrl = TextEditingController();
  bool _scanned = false;
  bool _cameraFailed = false;
  CameraFacing _facing = kIsWeb ? CameraFacing.front : CameraFacing.back;

  @override
  void initState() {
    super.initState();
    // Web desktops have no back camera — front maps to the webcam.
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _facing,
      autoStart: true,
    );
    _restoreFacing();
  }

  Future<void> _restoreFacing() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kScannerFacingKey);
    if (saved == null || !mounted) return;
    final wanted =
        saved == 'front' ? CameraFacing.front : CameraFacing.back;
    if (wanted != _facing) {
      _controller.switchCamera();
      setState(() => _facing = wanted);
    }
  }

  Future<void> _flipCamera() async {
    _controller.switchCamera();
    final next = _facing == CameraFacing.back
        ? CameraFacing.front
        : CameraFacing.back;
    setState(() => _facing = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kScannerFacingKey, next == CameraFacing.front ? 'front' : 'back');
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    _scanned = true;
    widget.onBarcodeScanned(raw);
    Navigator.of(context).pop();
  }

  void _submitManual() {
    final code = _manualCtrl.text.trim();
    if (code.isEmpty) return;
    widget.onBarcodeScanned(code);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.97)
                : Colors.black.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: EnhancedTheme.primaryTeal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded,
                      color: EnhancedTheme.primaryTeal, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Scan Barcode / QR Code',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (!_cameraFailed)
                  IconButton(
                    tooltip: _facing == CameraFacing.back
                        ? 'Switch to front camera'
                        : 'Switch to rear camera',
                    icon: const Icon(Icons.cameraswitch_rounded,
                        color: Colors.white70, size: 22),
                    onPressed: _flipCamera,
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            const Text(
              kIsWeb
                  ? 'Camera scan (Chrome/Edge) · or enter barcode below'
                  : 'Point camera at barcode or QR code',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _cameraFailed
                  ? _manualEntryView()
                  : Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder: (ctx, error, child) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _cameraFailed = true);
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      _ScanOverlay(),
                    ]),
            ),
            // Always-visible manual entry on web when camera is alive
            if (kIsWeb && !_cameraFailed) _manualEntryBar(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  // Full manual entry view — shown when camera fails (any platform)
  Widget _manualEntryView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.keyboard_rounded,
                  color: EnhancedTheme.primaryTeal, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Barcode Manually',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              kIsWeb
                  ? 'Camera scan requires Chrome or Edge.\nType the barcode/code below:'
                  : 'Camera unavailable. Type the barcode below:',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _manualCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _submitManual(),
              decoration: InputDecoration(
                hintText: 'e.g. 6223001543218',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.qr_code_rounded,
                    color: Colors.white38, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide:
                      BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    EnhancedTheme.primaryTeal,
                    EnhancedTheme.accentCyan,
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: _submitManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Look up Item',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      );

  // Compact manual entry bar shown below camera on web
  Widget _manualEntryBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _manualCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onSubmitted: (_) => _submitManual(),
              decoration: InputDecoration(
                hintText: 'Or type barcode…',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.keyboard_rounded,
                    color: Colors.white38, size: 18),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide:
                      BorderSide(color: EnhancedTheme.primaryTeal, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                EnhancedTheme.primaryTeal,
                EnhancedTheme.accentCyan,
              ]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _submitManual,
              icon: const Icon(Icons.search_rounded,
                  color: Colors.black, size: 20),
              padding: const EdgeInsets.all(11),
              constraints: const BoxConstraints(),
            ),
          ),
        ]),
      );
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border:
                Border.all(color: EnhancedTheme.primaryTeal, width: 2.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2),
            ],
          ),
          child: Stack(children: [
            _corner(Alignment.topLeft),
            _corner(Alignment.topRight),
            _corner(Alignment.bottomLeft),
            _corner(Alignment.bottomRight),
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: EnhancedTheme.primaryTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: EnhancedTheme.primaryTeal.withValues(alpha: 0.4)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.center_focus_strong_rounded,
                color: EnhancedTheme.primaryTeal, size: 14),
            SizedBox(width: 6),
            Text('Align barcode within frame',
                style: TextStyle(
                    color: EnhancedTheme.primaryTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _corner(Alignment alignment) {
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: EnhancedTheme.accentCyan, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: EnhancedTheme.accentCyan, width: 3)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: EnhancedTheme.accentCyan, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: EnhancedTheme.accentCyan, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

void showBarcodeScannerSheet(
    BuildContext context, void Function(String code) onBarcodeScanned) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BarcodeScannerSheet(onBarcodeScanned: onBarcodeScanned),
  );
}
