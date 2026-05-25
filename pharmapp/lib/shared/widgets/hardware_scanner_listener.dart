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

  // Scanners: < 40 ms per char. Humans: > 80 ms per char.
  static const int _maxAvgMsPerChar = 40;
  static const int _minBarcodeLen = 4;
  static const int _bufferTimeoutMs = 300;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _resetTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

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
    return Stack(children: [
      widget.child,
      Positioned(
        top: 0,
        right: 12,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: EnhancedTheme.primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: EnhancedTheme.primaryTeal.withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: EnhancedTheme.primaryTeal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Scanner ready',
                style: TextStyle(
                  color: EnhancedTheme.primaryTeal,
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
