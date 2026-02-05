import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  // Primary Action (Green)
  static const primary = Color(0xFF58CC02);
  static const primaryDark = Color(0xFF46A302); // For 3D shade
  static const primaryShadow = primaryDark;
  static const primaryBackground = Color(0xFFD7FFB8); // Very light green for backgrounds

  // Secondary Action (Blue)
  static const secondary = Color(0xFF1CB0F6);
  static const secondaryDark = Color(0xFF1899D6);
  static const secondaryBackground = Color(0xFFDDF4FF);

  // Danger / Error (Red)
  static const danger = Color(0xFFFF4B4B);
  static const dangerDark = Color(0xFFEA2B2B);
  static const dangerBackground = Color(0xFFFFDFDF);

  // Warning / Gold (Yellow)
  static const wasp = Color(0xFFFFC800);
  static const waspDark = Color(0xFFDFA600);
  static const waspBackground = Color(0xFFFFF7D1);

  // Neutral (Grey)
  static const neutral = Color(0xFFE5E5E5);
  static const neutralDark = Color(0xFFAFAFAF);
  static const neutralText = Color(0xFF777777);

  // Base
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF3C3C3C); // Soft black
  static const background = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF131F24);

  // Gamification
  static const xpGold = wasp;
  static const streakOrange = Color(0xFFFF9600);
  static const gemBlue = Color(0xFF1CB0F6);
}

abstract class AppTheme {
  // Shared border radius for the "bubbly" look
  static final borderRadius = BorderRadius.circular(16);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      
      // Typography
      textTheme: GoogleFonts.nunitoTextTheme().apply(
        bodyColor: AppColors.black,
        displayColor: AppColors.black,
      ).copyWith(
        headlineLarge: GoogleFonts.nunito(
          fontSize: 32,
          fontWeight: FontWeight.w800, // Extra Bold
          color: AppColors.black,
        ),
        headlineMedium: GoogleFonts.nunito(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.black,
        ),
        titleLarge: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700, // Bold
          color: AppColors.black,
        ),
        bodyLarge: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w500, // Medium
          color: AppColors.black,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.neutralText,
        ),
        labelLarge: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8, // Slightly spaced for button text
          color: AppColors.black, 
        ),
      ),

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.white,
        error: AppColors.danger,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.neutralText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.neutralText,
          letterSpacing: 0.5,
        ),
      ),

      // Input Decoration (Rounded, Thick Borders)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral.withValues(alpha: 0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.neutral, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.neutral, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.secondary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle: GoogleFonts.nunito(
          color: AppColors.neutralText,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Standard Buttons (Will use custom widgets mostly, but safe fallback)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Dark Theme (Quick Pass - can be refined)
  static ThemeData get darkTheme {
    const darkBg = AppColors.backgroundDark;
    const darkSurface = Color(0xFF202F36);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: darkBg,
      
      textTheme: GoogleFonts.nunitoTextTheme().apply(
        bodyColor: AppColors.white,
        displayColor: AppColors.white,
      ),
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: darkSurface,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
      ),

      cardTheme: CardThemeData(
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
    );
  }
}
