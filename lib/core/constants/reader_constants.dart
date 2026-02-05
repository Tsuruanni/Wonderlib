import 'package:flutter/material.dart';

/// Constants for the reader screen UI
class ReaderConstants {
  ReaderConstants._();

  // Header dimensions
  static const double expandedHeaderHeight = 400;
  static const double collapsedHeaderHeight = 100;

  // Content padding
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(24, 24, 24, 100);

  // Colors
  static const Color nextChapterButtonColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF38A169);

  // Reading timer
  static const int autoSaveIntervalSeconds = 30;

  // Border radius
  static const double cardBorderRadius = 12;

  // Spacing
  static const double sectionSpacing = 32;
  static const double buttonSpacing = 16;
}
