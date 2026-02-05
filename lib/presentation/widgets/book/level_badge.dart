import 'package:flutter/material.dart';

/// A badge widget displaying CEFR language proficiency level
/// Colors are assigned based on difficulty progression:
/// A1, A2 (Beginner) → Green tones
/// B1, B2 (Intermediate) → Blue tones
/// C1, C2 (Advanced) → Purple tones
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
    this.size = LevelBadgeSize.small,
  });

  final String level;
  final LevelBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(level);
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.horizontalPadding,
        vertical: dimensions.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(dimensions.borderRadius),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          color: colors.text,
          fontSize: dimensions.fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  _LevelColors _getColors(String level) {
    switch (level.toUpperCase()) {
      case 'A1':
        return const _LevelColors(
          background: Color(0xFFDCFCE7), // green-100
          text: Color(0xFF166534), // green-800
        );
      case 'A2':
        return const _LevelColors(
          background: Color(0xFFCCFBF1), // teal-100
          text: Color(0xFF115E59), // teal-800
        );
      case 'B1':
        return const _LevelColors(
          background: Color(0xFFDBEAFE), // blue-100
          text: Color(0xFF1E40AF), // blue-800
        );
      case 'B2':
        return const _LevelColors(
          background: Color(0xFFE0E7FF), // indigo-100
          text: Color(0xFF3730A3), // indigo-800
        );
      case 'C1':
        return const _LevelColors(
          background: Color(0xFFF3E8FF), // purple-100
          text: Color(0xFF6B21A8), // purple-800
        );
      case 'C2':
        return const _LevelColors(
          background: Color(0xFFFAE8FF), // fuchsia-100
          text: Color(0xFF86198F), // fuchsia-800
        );
      default:
        return const _LevelColors(
          background: Color(0xFFF1F5F9), // slate-100
          text: Color(0xFF475569), // slate-600
        );
    }
  }

  _BadgeDimensions _getDimensions(LevelBadgeSize size) {
    switch (size) {
      case LevelBadgeSize.small:
        return const _BadgeDimensions(
          horizontalPadding: 6,
          verticalPadding: 2,
          fontSize: 10,
          borderRadius: 4,
        );
      case LevelBadgeSize.medium:
        return const _BadgeDimensions(
          horizontalPadding: 8,
          verticalPadding: 4,
          fontSize: 12,
          borderRadius: 6,
        );
      case LevelBadgeSize.large:
        return const _BadgeDimensions(
          horizontalPadding: 12,
          verticalPadding: 6,
          fontSize: 14,
          borderRadius: 8,
        );
    }
  }
}

enum LevelBadgeSize { small, medium, large }

class _LevelColors {

  const _LevelColors({
    required this.background,
    required this.text,
  });
  final Color background;
  final Color text;
}

class _BadgeDimensions {

  const _BadgeDimensions({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontSize,
    required this.borderRadius,
  });
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double borderRadius;
}
