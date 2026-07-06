import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

/// Intercepts USB/Bluetooth HID barcode scanner input.
/// Hardware scanners emulate a keyboard, sending chars in rapid succession
/// (avg < 40 ms/char) followed by Enter. Human typing is much slower.
class HardwareScannerListener extends StatefulWidget {
  final Widget child;
  final void Function(String code) onBarcodeScanned;
  final bool showIndicator;

  const HardwareScannerListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.showIndicator = true,
  });

  @override
  State<HardwareScannerListener> createState() =>
      _HardwareScannerListenerState();
}

class _HardwareScannerListenerState extends State<HardwareScannerListener> {
  final _buffer = StringBuffer();
  DateTime? _firstKeyTime;
  Timer? _resetTimer;
  Timer? _scannedFlashTimer;
  bool _justScanned = false;

  // Scanners: < 40 ms per char. Humans: > 80 ms per char.
  static const int _maxAvgMsPerChar = 40;
  static const int _minBarcodeLen = 4;
  static const int _bufferTimeoutMs = 150;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _resetTimer?.cancel();
    _scannedFlashTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Only the foreground route consumes scanner input. Without this, a
    // background screen (under a pushed cart/payment route or an open scanner
    // sheet) still fires its callback — adding items to the wrong screen or
    // swallowing manual keystrokes typed into a sheet.
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _tryFlush();
      return false;
    }

    // Non-printable non-modifier keys abort the buffer
    final char = event.character;
    if (char == null || char.isEmpty) {
      final isModifier = key == LogicalKeyboardKey.shift ||
          key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight ||
          key == LogicalKeyboardKey.capsLock ||
          key == LogicalKeyboardKey.alt ||
          key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight ||
          key == LogicalKeyboardKey.control ||
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight;
      if (!isModifier) {
        _buffer.clear();
        _firstKeyTime = null;
        _resetTimer?.cancel();
      }
      return false;
    }

    _firstKeyTime ??= DateTime.now();
    _buffer.write(char);

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: _bufferTimeoutMs), () {
      _buffer.clear();
      _firstKeyTime = null;
    });

    return false;
  }

  void _tryFlush() {
    final len = _buffer.length;
    if (len >= _minBarcodeLen && _firstKeyTime != null) {
      final elapsed = DateTime.now().difference(_firstKeyTime!).inMilliseconds;
      // elapsed == 0 means same millisecond — definitely a scanner
      if (elapsed == 0 || elapsed / len < _maxAvgMsPerChar) {
        final code = _buffer.toString();
        _buffer.clear();
        _firstKeyTime = null;
        _resetTimer?.cancel();
        // Confirm the scan registered without the operator watching the screen:
        // a buzz + click, and a 1s green "Scanned" flash on the indicator.
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        if (widget.showIndicator && mounted) {
          setState(() => _justScanned = true);
          _scannedFlashTimer?.cancel();
          _scannedFlashTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) setState(() => _justScanned = false);
          });
        }
        widget.onBarcodeScanned(code);
        return;
      }
    }
    _buffer.clear();
    _firstKeyTime = null;
    _resetTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showIndicator) return widget.child;
    final color =
        _justScanned ? EnhancedTheme.successGreen : EnhancedTheme.primaryTeal;
    return Stack(children: [
      widget.child,
      Positioned(
        top: 0,
        right: 12,
        child: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _justScanned
                  ? Icon(Icons.check_rounded, size: 10, color: color)
                  : Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
              const SizedBox(width: 5),
              Text(
                _justScanned ? 'Scanned' : 'Scanner ready',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
