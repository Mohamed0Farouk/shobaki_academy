import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Color Scheme
  static const Color backgroundColor = Color(0xFFFFFBF5); // Creamy white
  static const Color primaryColor = Color(0xFF00A8E8); // Updated primary
  static const Color secondaryColor = Colors.black; // Black accents
  static const Color surfaceColor = Color(0xFFF8F8F8); // White surface
  static const Color textPrimaryColor = Colors.black; // Black text
  static const Color textSecondaryColor = Colors.grey; // Grey text

  static ThemeData get mainTheme {
    final baseTheme = ThemeData.light();

    return baseTheme.copyWith(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        brightness: Brightness.light,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black12,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.almarai(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: GoogleFonts.almarai(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineMedium: GoogleFonts.almarai(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineSmall: GoogleFonts.almarai(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        bodyLarge: GoogleFonts.almarai(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimaryColor,
        ),
        bodyMedium: GoogleFonts.almarai(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimaryColor,
        ),
        bodySmall: GoogleFonts.almarai(
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: textSecondaryColor,
        ),
        labelMedium: GoogleFonts.almarai(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 2,
          shadowColor: Colors.black26,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: textSecondaryColor),
        hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
      ),

      dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 1),

      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}
