import 'package:flutter/material.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

// ── Press-animation wrapper ───────────────────────────────────────────────────

class _PressableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableWidget({required this.child, this.onTap});

  @override
  State<_PressableWidget> createState() => _PressableWidgetState();
}

class _PressableWidgetState extends State<_PressableWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// ── CustomButton ──────────────────────────────────────────────────────────────

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Widget? icon;          // accepts any Widget (Icon, SvgPicture, etc.)
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final bool isLoading;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.textStyle,
    this.isLoading = false,
    this.width,
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final bgColor = backgroundColor ?? EnhancedTheme.primaryTeal;

    return _PressableWidget(
      onTap: (isLoading || onPressed == null) ? null : onPressed,
      child: Container(
        constraints: constraints ??
            BoxConstraints.tightFor(width: width, height: height ?? 48),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor ?? bgColor,
            width: borderWidth ?? 0,
          ),
          borderRadius: BorderRadius.circular(borderRadius ?? 16),
          boxShadow: [
            BoxShadow(
              color:  bgColor.withValues(alpha:0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) icon!,
            if (icon != null) const SizedBox(width: 8),
            Text(
              text,
              style: textStyle ??
                  theme.textTheme.labelLarge?.copyWith(
                    color: foregroundColor ?? Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
            ),
            if (isLoading) const SizedBox(width: 8),
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      foregroundColor ?? Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── CustomOutlineButton ───────────────────────────────────────────────────────

class CustomOutlineButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final bool isLoading;
  final double? width;
  final double? height;

  const CustomOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.textStyle,
    this.isLoading = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final fgColor = foregroundColor ?? EnhancedTheme.primaryTeal;

    return _PressableWidget(
      onTap: isLoading ? null : onPressed,
      child: Container(
        constraints: BoxConstraints.tightFor(width: width, height: height ?? 48),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          border: Border.all(
            color: borderColor ?? EnhancedTheme.primaryTeal,
            width: borderWidth ?? 2,
          ),
          borderRadius: BorderRadius.circular(borderRadius ?? 16),
          boxShadow: backgroundColor != null
              ? [
                  BoxShadow(
                    color:  backgroundColor!.withValues(alpha:0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) icon!,
            if (icon != null) const SizedBox(width: 8),
            Text(
              text,
              style: textStyle ??
                  theme.textTheme.labelLarge?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
            ),
            if (isLoading) const SizedBox(width: 8),
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── CustomIconButton ──────────────────────────────────────────────────────────

class CustomIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;
  final double? size;
  final BorderRadius? borderRadius;
  final bool showBorder;

  const CustomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size,
    this.borderRadius,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final sz = size ?? 40.0;
    return _PressableWidget(
      onTap: onPressed,
      child: Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          color: showBorder ? Colors.transparent : EnhancedTheme.surfaceGlass,
          border: showBorder
              ? Border.all(
                  color: EnhancedTheme.primaryTeal.withValues(alpha:0.3),
                  width: 1,
                )
              : null,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color ?? EnhancedTheme.primaryTeal,
          size: sz * 0.5,
        ),
      ),
    );
  }
}

// ── CustomTextButton ──────────────────────────────────────────────────────────

class CustomTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final TextStyle? textStyle;
  final Color? textColor;
  final double? horizontalPadding;
  final double? verticalPadding;

  const CustomTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.textStyle,
    this.textColor,
    this.horizontalPadding,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final fgColor = textColor ?? EnhancedTheme.primaryTeal;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? 8,
          vertical:   verticalPadding   ?? 4,
        ),
        foregroundColor: fgColor,
        overlayColor: fgColor.withValues(alpha:0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: textStyle ??
            theme.textTheme.labelLarge?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
      ),
    );
  }
}
