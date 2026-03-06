import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EnhancedTheme {
  // Enhanced Premium Teal Palette
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primaryTeal = Color(0xFF0D9488); // Teal 600
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceGlass = Color(0x33FFFFFF);

  // Glassmorphic variants
  static const Color glassLight = Color(0x33FFFFFF);
  static const Color glassMedium = Color(0x66FFFFFF);
  static const Color glassDark = Color(0x99FFFFFF);

  // Success/Failure colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  static ThemeData get enhancedLightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        surface: backgroundLight,
        surfaceTint: Colors.transparent,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: primaryDark,
        ),
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: primaryDark,
        ),
        bodyLarge: GoogleFonts.inter(color: Colors.black87),
        bodyMedium: GoogleFonts.inter(color: Colors.black54),
        labelLarge: GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black.withOpacity(0.8),
        actionTextColor: accentCyan,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      ),
    );
  }

  // Glassmorphic widget builders
  static Widget glassContainer(
    BuildContext context, {
    required Widget child,
    double blur = 20,
    double? opacity,
    Color? color,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    BoxConstraints? constraints,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: GlassmorphicContainer(
          blur: blur,
          opacity: opacity ?? 0.15,
          color: color ?? surfaceGlass,
          border: 2,
          borderColor: Colors.white.withOpacity(0.1),
          child: Container(
            constraints: constraints,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  static Widget shimmerCard(
    BuildContext context, {
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    Curve curve = Curves.linear,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      child: Shimmer.fromColors(
        baseColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.3),
        child: child,
      ),
    );
  }

  static Widget animatedCard(
    BuildContext context, {
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    VoidCallback? onTap,
  }) {
    return ScaleAnimatedWidget8(
      duration: duration,
      curve: curve,
      child: child,
      scale: 0.95,
      onTap: onTap,
    );
  }

  static Widget floatingActionButton(
    BuildContext context, {
    required Widget child,
    VoidCallback? onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return ScaleAnimatedWidget8(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: FloatingActionButton(
        onPressed: onPressed,
        child: child,
        backgroundColor: backgroundColor ?? primaryTeal,
        foregroundColor: foregroundColor ?? Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static Widget successBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: successGreen.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: successGreen,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color: successGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget errorBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorRed.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error,
            color: errorRed,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color: errorRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget loadingShimmer() {
    return shimmerCard(
      null,
      child: Container(
        width: double.infinity,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Widget successAnimation() {
    return ScaleAnimatedWidget8(
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: successGreen.withOpacity(0.3), width: 2),
        ),
        child: Icon(
          Icons.check_circle,
          color: successGreen,
          size: 48,
        ),
      ),
    );
  }

  static Widget errorAnimation() {
    return ShakeAnimatedWidget8(
      duration: const Duration(milliseconds: 500),
      shakeAngle: Rotation.deg(z: 20),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: errorRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: errorRed.withOpacity(0.3), width: 2),
        ),
        child: Icon(
          Icons.error,
          color: errorRed,
          size: 48,
        ),
      ),
    );
  }
}