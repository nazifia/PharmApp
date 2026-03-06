import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
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
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return ScaleAnimatedWidget8(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        constraints: constraints ??
          BoxConstraints.tightFor(
            width: width,
            height: height ?? 48,
          ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor ?? colors.primaryTeal,
                border: Border.all(
                  color: borderColor ?? colors.primaryTeal,
                  width: borderWidth ?? 0,
                ),
                borderRadius: BorderRadius.circular(borderRadius ?? 16),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor!.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      color: foregroundColor ?? Colors.white,
                      size: 20,
                    ),
                  if (icon != null) const SizedBox(width: 8),
                  Text(
                    text,
                    style: textStyle ??
                      theme.textTheme.labelLarge?.copyWith(
                        color: foregroundColor ?? Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                  ),
                  if (isLoading)
                    const SizedBox(width: 8),
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foregroundColor ?? Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomOutlineButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
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
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return ScaleAnimatedWidget8(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints.tightFor(
          width: width,
          height: height ?? 48,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.transparent,
                border: Border.all(
                  color: borderColor ?? colors.primaryTeal,
                  width: borderWidth ?? 2,
                ),
                borderRadius: BorderRadius.circular(borderRadius ?? 16),
                boxShadow: [
                  if (backgroundColor != null) ...[
                    BoxShadow(
                      color: backgroundColor!.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ],
              ),
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      color: foregroundColor ?? colors.primaryTeal,
                      size: 20,
                    ),
                  if (icon != null) const SizedBox(width: 8),
                  Text(
                    text,
                    style: textStyle ??
                      theme.textTheme.labelLarge?.copyWith(
                        color: foregroundColor ?? colors.primaryTeal,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                  ),
                  if (isLoading)
                    const SizedBox(width: 8),
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foregroundColor ?? colors.primaryTeal),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return ScaleAnimatedWidget8(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Container(
            width: size ?? 40,
            height: size ?? 40,
            decoration: BoxDecoration(
              color: showBorder ? Colors.transparent : colors.surfaceGlass,
              border: showBorder
                 ? Border.all(
                      color: colors.primaryTeal.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              boxShadow: [
                if (!showBorder) ...[
                  BoxShadow(
                    color: colors.primaryTeal.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ],
            ),
            child: Icon(
              icon,
              color: color ?? colors.primaryTeal,
              size: size ?? 20,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final TextStyle? textStyle;
  final Color? textColor;
  final Color? highlightColor;
  final Color? splashColor;
  final double? horizontalPadding;
  final double? verticalPadding;

  const CustomTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.textStyle,
    this.textColor,
    this.highlightColor,
    this.splashColor,
    this.horizontalPadding,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? 8,
          vertical: verticalPadding ?? 4,
        ),
        backgroundColor: highlightColor,
        foregroundColor: textColor ?? colors.primaryTeal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        animationDuration: const Duration(milliseconds: 100),
        overlayColor: splashColor ?? colors.primaryTeal.withOpacity(0.1),
      ),
      child: Text(
        text,
        style: textStyle ??
          theme.textTheme.labelLarge?.copyWith(
            color: textColor ?? colors.primaryTeal,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
      ),
    );
  }
}