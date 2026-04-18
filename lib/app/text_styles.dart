import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/theme.dart';

/// Centralized text style system.
///
/// Hierarchy: display (w900) > headline/title (w800) > body (w500).
/// Swap the font family in one place by changing `GoogleFonts.nunito` below.
abstract class AppTextStyles {
  // Display — celebration moments (quiz score, treasure win, big metrics)
  static TextStyle display({Color? color, double size = 36}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color ?? AppColors.black,
      );

  // Hero — splash, login, onboarding main heading
  static TextStyle hero({Color? color}) => GoogleFonts.nunito(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: color ?? AppColors.black,
      );

  // Headline — large section heading (e.g. "Session Complete!")
  static TextStyle headlineLarge({Color? color}) => GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.black,
      );

  // Headline — section heading
  static TextStyle headlineMedium({Color? color}) => GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.black,
      );

  // Title — card/panel title
  static TextStyle titleLarge({Color? color}) => GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.black,
      );

  // Title — smaller title / list item header
  static TextStyle titleMedium({Color? color}) => GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.black,
      );

  // Body — primary paragraph text
  static TextStyle bodyLarge({Color? color}) => GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.black,
      );

  // Body — secondary paragraph / description
  static TextStyle bodyMedium({Color? color}) => GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.neutralText,
      );

  // Body — small supporting text
  static TextStyle bodySmall({Color? color}) => GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.neutralText,
      );

  // Button — UPPERCASE action label
  static TextStyle button({Color? color}) => GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color ?? AppColors.black,
      );

  // Caption — metadata, timestamps, chip labels
  static TextStyle caption({Color? color}) => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color ?? AppColors.neutralText,
      );
}
