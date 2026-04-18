import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/text_styles.dart';

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

  // Status Aliases
  static const success = primary;
  static const successDark = primaryDark;
  static const successBackground = primaryBackground;

  // Neutral (Grey - legacy)
  static const neutral = Color(0xFFE5E5E5);
  static const neutralDark = Color(0xFFAFAFAF);
  static const neutralText = Color(0xFF777777);

  // Tailwind Gray Palette (used across quiz/reader/vocab widgets)
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);

  // Base
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF3C3C3C); // Soft black
  static const background = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF131F24);

  // Gamification
  static const xpGold = wasp;
  static const streakOrange = Color(0xFFFF9600);
  static const gemBlue = Color(0xFF1CB0F6);

  // Card Rarities
  static const cardCommon = Color(0xFFAFAFAF);
  static const cardCommonDark = Color(0xFF8A8A8A);
  static const cardRare = Color(0xFF1CB0F6);
  static const cardRareDark = Color(0xFF1899D6);
  static const cardEpic = Color(0xFF9B59B6);
  static const cardEpicDark = Color(0xFF7D3C98);
  static const cardLegendary = Color(0xFFFFC800);
  static const cardLegendaryDark = Color(0xFFDFA600);

  // Gamification (Path & Terrain)
  static const terrain = Color(0xFF5D4037); // Dark Brown
  static const terrainLight = Color(0xFF8D6E63); // Lighter Brown
  static const path = Color(0xFFFFF8E7); // Cream (Vanilla)
  static const pathBorder = Color(0xFFC1A17A); // Earthy Sand Border
}

/// Semantic border radius hierarchy (Duolingo-style).
///
/// Different components use different radii to create visual hierarchy:
/// pills are most rounded, tags tightest, buttons somewhere in between.
abstract class AppRadius {
  static const double tag = 8;      // Small inline tags
  static const double button = 12;  // Buttons (slightly tighter than cards)
  static const double input = 16;   // Form inputs (match cards)
  static const double card = 16;    // Cards / panels / sheets
  static const double pill = 20;    // Full pill-shaped chips / large pills
  static const double sheet = 24;   // Bottom sheets, large rounded tops
}

/// Semantic opacity levels for visual states.
///
/// Use instead of raw numbers to keep disabled/muted states consistent across
/// the app. Duolingo spec pins disabled at 0.45.
abstract class AppOpacity {
  static const double disabled = 0.45;  // Non-interactive / not available
  static const double muted = 0.6;      // De-emphasized, still readable
  static const double subtle = 0.8;     // Lightly backgrounded
}

/// Fluent helpers for applying semantic opacity to any widget.
///
/// Usage:
///   MyCard().disabled(!canInteract)
///   MyIcon().muted(true)
extension AppOpacityWidget on Widget {
  /// Dims this widget to [AppOpacity.disabled] when [isDisabled] is true.
  /// Does not block pointer events — wrap in [IgnorePointer] if needed.
  Widget disabled([bool isDisabled = true]) => isDisabled
      ? Opacity(opacity: AppOpacity.disabled, child: this)
      : this;

  /// Dims this widget to [AppOpacity.muted] when [isMuted] is true.
  Widget muted([bool isMuted = true]) => isMuted
      ? Opacity(opacity: AppOpacity.muted, child: this)
      : this;
}

abstract class AppTheme {
  // Input/card radius (kept for backwards compat with existing usages).
  // Prefer AppRadius.xxx for new code.
  static final borderRadius = BorderRadius.circular(AppRadius.card);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      
      // Typography — all styles sourced from AppTextStyles (single source of truth)
      textTheme: GoogleFonts.nunitoTextTheme().apply(
        bodyColor: AppColors.black,
        displayColor: AppColors.black,
      ).copyWith(
        headlineLarge: AppTextStyles.hero(),
        headlineMedium: AppTextStyles.headlineMedium(),
        titleLarge: AppTextStyles.titleLarge(),
        titleMedium: AppTextStyles.titleMedium(),
        bodyLarge: AppTextStyles.bodyLarge(),
        bodyMedium: AppTextStyles.bodyMedium(),
        bodySmall: AppTextStyles.bodySmall(),
        labelLarge: AppTextStyles.button(),
        labelSmall: AppTextStyles.caption(),
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

      // Page transitions — fade on all platforms
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.neutralText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.titleMedium(color: AppColors.neutralText)
            .copyWith(fontSize: 18, letterSpacing: 0.5),
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
        hintStyle: AppTextStyles.bodyMedium(),
      ),

      // Standard Buttons (Will use custom widgets mostly, but safe fallback)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.button().copyWith(fontSize: 16, letterSpacing: 0.5),
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
