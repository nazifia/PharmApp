import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Rebuilds with `visible = true` once, the first time this widget scrolls
/// into its nearest [Scrollable]'s viewport. Outside a scrollable it is
/// visible right after the first frame.
class InView extends StatefulWidget {
  const InView({super.key, required this.builder, this.delay = Duration.zero});

  final Widget Function(BuildContext context, bool visible) builder;

  /// Extra wait after the widget is first seen (for staggered lists).
  final Duration delay;

  @override
  State<InView> createState() => _InViewState();
}

class _InViewState extends State<InView> {
  bool _visible = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_check);
      _position = position;
      if (!_visible) _position?.addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_visible || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = _position;
    var seen = true;
    if (viewport != null && position != null && position.hasPixels) {
      // ponytail: nearest scrollable only; nested scrollables check their own axis.
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final extent =
          position.axis == Axis.vertical ? box.size.height : box.size.width;
      seen = top < position.pixels + position.viewportDimension &&
          top + extent > position.pixels;
    }
    if (!seen) return;
    _position?.removeListener(_check);
    if (widget.delay == Duration.zero) {
      setState(() => _visible = true);
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _visible);
}

extension AnimateInView on Widget {
  /// Like [animate], but the effects start when this widget first scrolls
  /// into view instead of on first build.
  Widget animateInView(Animate Function(Animate a) effects,
          {Duration delay = Duration.zero}) =>
      InView(
          delay: delay,
          builder: (_, v) => effects(animate(target: v ? 1 : 0)));
}

/// [Text] whose first number counts up from 0 when it scrolls into view.
/// Prefix/suffix (₦, %, K, M, " units"), commas and decimals are preserved.
class CountUpText extends StatelessWidget {
  const CountUpText(this.text,
      {super.key,
      this.style,
      this.textAlign,
      this.maxLines,
      this.overflow,
      this.softWrap});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  static final _number = RegExp(r'\d[\d,]*(?:\.\d+)?');
  // ponytail: dates, times, years, phones and ids stay static.
  static final _static = RegExp(
      r'\d[/\-:]\d|\d{7,}|\b(?:19|20)\d\d\b|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\b|\d\s?[AaPp][Mm]\b');

  Text _text(String s) => Text(s,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap);

  @override
  Widget build(BuildContext context) {
    final m = _number.firstMatch(text);
    if (m == null || _static.hasMatch(text)) return _text(text);
    final raw = m[0]!;
    final target = double.tryParse(raw.replaceAll(',', ''));
    if (target == null) return _text(text);
    final decimals = raw.contains('.') ? raw.split('.').last.length : 0;
    final format = raw.contains(',')
        ? NumberFormat.decimalPatternDigits(
            locale: 'en_US', decimalDigits: decimals)
        : null;
    return InView(
      builder: (_, visible) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? target : 0),
        duration: 900.ms,
        curve: Curves.easeOutCubic,
        builder: (_, n, __) => _text(text.replaceRange(m.start, m.end,
            format?.format(n) ?? n.toStringAsFixed(decimals))),
      ),
    );
  }
}
