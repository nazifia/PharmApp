import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pharmapp/core/theme/enhanced_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? prefixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final EdgeInsetsGeometry? contentPadding;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? textColor;
  final Color? cursorColor;
  final Color? fillColor;
  final Color? enabledBorderColor;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final BorderRadius? borderRadius;
  final double? borderWidth;
  final bool filled;
  final bool enableInteractiveSelection;
  final bool showCursor;
  final bool readOnly;
  final TextInputAction? textInputAction;

  const CustomTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.validator,
    this.contentPadding,
    this.fontSize,
    this.fontWeight,
    this.textColor,
    this.cursorColor,
    this.fillColor,
    this.enabledBorderColor,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.borderRadius,
    this.borderWidth,
    this.filled = true,
    this.enableInteractiveSelection = true,
    this.showCursor = true,
    this.readOnly = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscureText,
        enabled: enabled,
        autofocus: autofocus,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        cursorColor: cursorColor ?? colors.primaryTeal,
        style: TextStyle(
          color: textColor ?? theme.colorScheme.onSurface,
          fontSize: fontSize ?? 16,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
        strutStyle: const StrutStyle(fontSize: 16),
        cursorWidth: 2,
        cursorRadius: const Radius.circular(1),
        cursorHeight: maxLines == 1 ? null : 20,
        enableSuggestions: keyboardType != TextInputType.multiline,
        autocorrect: keyboardType != TextInputType.multiline,
        enableInteractiveSelection: enableInteractiveSelection,
        showCursor: showCursor,
        readOnly: readOnly,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: textColor ?? theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: fontSize ?? 16,
            fontWeight: fontWeight ?? FontWeight.normal,
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            color: textColor != null
               ? textColor!.withOpacity(0.4)
                : theme.colorScheme.onSurface.withOpacity(0.4),
            fontSize: fontSize ?? 16,
            fontWeight: fontWeight ?? FontWeight.normal,
          ),
          prefixText: prefixText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          filled: filled,
          fillColor: fillColor ?? colors.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            borderSide: BorderSide(
              color: enabledBorderColor ?? theme.colorScheme.onSurface.withOpacity(0.1),
              width: borderWidth ?? 0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            borderSide: BorderSide(
              color: enabledBorderColor ?? theme.colorScheme.onSurface.withOpacity(0.1),
              width: borderWidth ?? 0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            borderSide: BorderSide(
              color: focusedBorderColor ?? colors.primaryTeal,
              width: borderWidth ?? 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            borderSide: BorderSide(
              color: errorBorderColor ?? colors.errorRed,
              width: borderWidth ?? 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            borderSide: BorderSide(
              color: errorBorderColor ?? colors.errorRed,
              width: borderWidth ?? 2,
            ),
          ),
          counterText: '',
          counterStyle: TextStyle(
            color: textColor ?? theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class CustomSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool showClearButton;
  final bool enabled;

  const CustomSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.showClearButton = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primaryTeal.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            color: colors.primaryTeal.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: colors.primaryTeal.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
              onChanged: onChanged,
              enabled: enabled,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (showClearButton && controller?.text.isNotEmpty == true)
            IconButton(
              onPressed: onClear,
              icon: Icon(
                Icons.clear,
                color: colors.primaryTeal.withOpacity(0.6),
                size: 20,
              ),
              splashRadius: 20,
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class CustomPasswordInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool? obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onToggleVisibility;

  const CustomPasswordInput({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.obscureText,
    this.onChanged,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EnhancedTheme();

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(
          Icons.lock,
          color: Colors.white54,
        ),
        suffixIcon: InkWell(
          onTap: onToggleVisibility,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              obscureText == true ? Icons.visibility : Icons.visibility_off,
              color: colors.primaryTeal,
              size: 20,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        filled: true,
        fillColor: colors.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
      ),
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
      ),
      obscureText: obscureText ?? true,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
    );
  }
}