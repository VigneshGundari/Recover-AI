import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Dark Mode Palette
  static const Color primaryColor = Color(0xFF00E6B8);      // Neon Teal
  static const Color secondaryColor = Color(0xFF3B82F6);    // Electric Blue
  static const Color backgroundColor = Color(0xFF0A0F1A);   // Deep Space
  static const Color surfaceColor = Color(0xFF141D2C);      // Glassmorphic Surface
  static const Color textPrimary = Color(0xFFF8FAFC);       // Ice White
  static const Color textSecondary = Color(0xFF94A3B8);     // Muted Slate
  static const Color dangerColor = Color(0xFFEF4444);       // Warning Red

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: dangerColor,
    ),
    textTheme: GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
      headlineMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 24),
      titleLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 20),
      bodyLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w400, fontSize: 16),
      bodyMedium: GoogleFonts.outfit(color: textSecondary, fontWeight: FontWeight.w400, fontSize: 14),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        elevation: 10,
        shadowColor: primaryColor.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
  );
  
  static final ThemeData lightTheme = darkTheme; // Enforce dark theme
}
