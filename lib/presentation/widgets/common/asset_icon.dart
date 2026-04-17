import 'package:flutter/material.dart';

/// Thin Image.asset wrapper used to replace Material [Icon] with the
/// project's illustrated PNG icons in teacher-facing surfaces.
class AssetIcon extends StatelessWidget {
  const AssetIcon(this.asset, {super.key, this.size = 24});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Centralized asset paths for icons used across teacher surfaces.
abstract class AppIcons {
  AppIcons._();

  // Reading / books
  static const book = 'assets/icons/book_active.png';
  static const bookCompleted = 'assets/icons/book_completed.png';
  static const library = 'assets/icons/library.png';

  // Vocabulary
  static const vocabulary = 'assets/icons/vocabulary.png';
  static const vocabularyActive = 'assets/icons/voc_active.png';

  // Time
  static const schedule = 'assets/icons/schedule.png';

  // Activity / streak
  static const fire = 'assets/icons/fire_256.png';

  // XP & rewards
  static const xp = 'assets/icons/xp_green_outline.png';
  static const star = 'assets/icons/star.png';
  static const trophy = 'assets/icons/trophy_256.png';

  // Assignments / tasks
  static const clipboard = 'assets/icons/clipboard_256.png';
  static const quest = 'assets/icons/quest.png';
  static const questNew = 'assets/icons/questnew.png';

  // Learning content
  static const quiz = 'assets/icons/quiz.png';
  static const unitNodes = 'assets/icons/unit_nodes.png';

  // Collections
  static const card = 'assets/icons/card.png';
  static const gem = 'assets/icons/gem_outline_256.png';
  static const treasure = 'assets/icons/treasure_active.png';

  // Status
  static const checkMark = 'assets/icons/check_mark_256.png';
  static const checkMarkYellow = 'assets/icons/check_mark_256_yellow.png';
  static const xOutline = 'assets/icons/x_outline_256.png';
  static const warning = 'assets/icons/warning_sign_outline_256.png';
}
