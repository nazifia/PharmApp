import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Deep Teal Palette
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primaryTeal = Color(0xFF0D9488); // Teal 600
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color surfaceColor = Color(0xFF1E293B);
  static const Color backgroundLight = Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        surface: backgroundLight,
        surfaceTint: Colors.transparent, // Prevents muddy Material 3 surfaces
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primaryDark),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: primaryDark),
        bodyLarge: GoogleFonts.inter(color: Colors.black87),
        bodyMedium: GoogleFonts.inter(color: Colors.black54),
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
    );
  }
}
