# Progress Bar Unification + Daily Quest Island Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every `LinearProgressIndicator` / `ProProgressBar` / custom bar with a single `AppProgressBar` matching the badges-page visual language, and redesign daily quest cards to use the same island-row layout.

**Architecture:** Extract `_ProgressBar` from `achievement_group_row.dart` into a shared `AppProgressBar` widget with optional animated width, then do a mechanical sweep across 13 files replacing inline progress bar code. Daily quest redesign touches `daily_quest_list.dart` (mobile) and `_DailyQuestsCard` inside `right_info_panel.dart` (sidebar).

**Tech Stack:** Flutter, Dart, `flutter_animate` (book quiz entry animation)

---

## Task 1: Create `AppProgressBar`

**Files:**
- Create: `lib/presentation/widgets/common/app_progress_bar.dart`

- [ ] **Step 1: Create the widget**

```dart
// lib/presentation/widgets/common/app_progress_bar.dart
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Canonical progress bar matching the badges-page design language.
/// Fully rounded, gray200 background, fill with a 3px bottom-border shadow
/// for a tactile "button" depth feel.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.progress,
    this.fillColor,
    this.fillShadow,
    this.backgroundColor,
    this.height = 12.0,
    this.duration = Duration.zero,
    this.curve = Curves.easeOutCubic,
  });

  final double progress;
  final Color? fillColor;
  final Color? fillShadow;
  final Color? backgroundColor;
  final double height;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final effectiveFill = fillColor ?? AppColors.primary;
    final effectiveShadow = fillShadow ?? AppColors.primaryDark;
    final effectiveBg = backgroundColor ?? AppColors.gray200;
    final clamped = progress.clamp(0.0, 1.0);

    final fillWidget = Container(
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(999),
        border: Border(
          bottom: BorderSide(color: effectiveShadow, width: 3),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: duration == Duration.zero
              ? FractionallySizedBox(widthFactor: clamped, child: fillWidget)
              : AnimatedFractionallySizedBox(
                  duration: duration,
                  curve: curve,
                  widthFactor: clamped,
                  child: fillWidget,
                ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
dart analyze lib/presentation/widgets/common/app_progress_bar.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/app_progress_bar.dart
git commit -m "feat(ui): add AppProgressBar — canonical badges-style progress bar"
```

---

## Task 2: Migrate `achievement_group_row.dart`; delete `ProProgressBar`; migrate `daily_review_screen.dart`

**Files:**
- Modify: `lib/presentation/widgets/badges/achievement_group_row.dart`
- Delete: `lib/presentation/widgets/common/pro_progress_bar.dart`
- Modify: `lib/presentation/screens/vocabulary/daily_review_screen.dart`

- [ ] **Step 1: Update `achievement_group_row.dart`**

Add import at top (after existing imports):
```dart
import '../common/app_progress_bar.dart';
```

Replace the entire `_ProgressBar` class (lines 203–244) with:
```dart
// _ProgressBar removed — using AppProgressBar directly
```

In `AchievementGroupRow.build`, the `_ProgressBar(...)` call at line ~176:
```dart
// OLD:
_ProgressBar(
  progress: group.progress,
  fillColor: fillColor,
  fillShadow: fillShadow,
),
// NEW:
AppProgressBar(
  progress: group.progress,
  fillColor: fillColor,
  fillShadow: fillShadow,
),
```

- [ ] **Step 2: Delete `pro_progress_bar.dart`**

```bash
rm lib/presentation/widgets/common/pro_progress_bar.dart
```

- [ ] **Step 3: Update `daily_review_screen.dart`**

Find the import:
```dart
import '../../../widgets/common/pro_progress_bar.dart';
```
Replace with:
```dart
import '../../../widgets/common/app_progress_bar.dart';
```

Find the usage (line ~472):
```dart
// OLD:
child: ProProgressBar(progress: progress, height: 20, color: AppColors.streakOrange),
// NEW:
child: AppProgressBar(
  progress: progress,
  height: 20,
  fillColor: AppColors.streakOrange,
  fillShadow: const Color(0xFFC76A00),
  duration: const Duration(milliseconds: 500),
),
```

- [ ] **Step 4: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/badges/achievement_group_row.dart
git add lib/presentation/screens/vocabulary/daily_review_screen.dart
git rm lib/presentation/widgets/common/pro_progress_bar.dart
git commit -m "refactor(ui): migrate achievement row + daily review to AppProgressBar; delete ProProgressBar"
```

---

## Task 3: Rewrite `VocabSessionProgressBar` and `BookQuizProgressBar`

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/session/vocab_session_progress_bar.dart`
- Modify: `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart`

- [ ] **Step 1: Rewrite `vocab_session_progress_bar.dart`**

Replace the entire file:
```dart
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../common/app_progress_bar.dart';

class VocabSessionProgressBar extends StatelessWidget {
  const VocabSessionProgressBar({
    super.key,
    required this.progress,
    this.comboActive = false,
  });

  final double progress;
  final bool comboActive;

  @override
  Widget build(BuildContext context) {
    return AppProgressBar(
      progress: progress,
      height: 12,
      fillColor: comboActive ? AppColors.streakOrange : AppColors.primary,
      fillShadow: comboActive ? const Color(0xFFC76A00) : AppColors.primaryDark,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }
}
```

- [ ] **Step 2: Rewrite `book_quiz_progress_bar.dart`**

Replace the entire file:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme.dart';
import '../../common/app_progress_bar.dart';

class BookQuizProgressBar extends StatelessWidget {
  const BookQuizProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalQuestions,
  });

  final int currentIndex;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final double progress =
        totalQuestions > 0 ? (currentIndex + 1) / totalQuestions : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: AppProgressBar(
        progress: progress,
        height: 12,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}
```

- [ ] **Step 3: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/vocabulary/session/vocab_session_progress_bar.dart
git add lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart
git commit -m "refactor(ui): rewrite VocabSessionProgressBar + BookQuizProgressBar using AppProgressBar"
```

---

## Task 4: Migrate card collection progress bars

**Files:**
- Modify: `lib/presentation/widgets/cards/collection_progress_widget.dart`
- Modify: `lib/presentation/widgets/cards/collection_progress_card.dart`

- [ ] **Step 1: Update `collection_progress_widget.dart`**

Add import (after existing imports):
```dart
import '../common/app_progress_bar.dart';
```

Remove the `flutter/material.dart` dependency on `LinearProgressIndicator` — the `ClipRRect` + `LinearProgressIndicator` block (lines ~44–54):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: LinearProgressIndicator(
    value: progress,
    minHeight: 10,
    backgroundColor: AppColors.neutral,
    valueColor: AlwaysStoppedAnimation<Color>(
      _getProgressColor(progress),
    ),
  ),
),
// NEW:
AppProgressBar(
  progress: progress,
  height: 10,
  fillColor: _getProgressColor(progress),
  fillShadow: _getProgressShadow(progress),
),
```

Add the `_getProgressShadow` helper method alongside `_getProgressColor`:
```dart
Color _getProgressShadow(double progress) {
  if (progress >= 1.0) return AppColors.cardLegendaryDark;
  if (progress >= 0.75) return AppColors.cardEpicDark;
  if (progress >= 0.5) return AppColors.cardRareDark;
  return AppColors.primaryDark;
}
```

- [ ] **Step 2: Update `collection_progress_card.dart`**

Add import (after existing imports):
```dart
import '../common/app_progress_bar.dart';
```

Replace the main collection bar (lines ~78–86):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: LinearProgressIndicator(
    value: progress,
    minHeight: 8,
    backgroundColor: AppColors.neutral,
    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
  ),
),
// NEW:
AppProgressBar(
  progress: progress,
  height: 8,
),
```

In `_buildRarityRow`, replace the rarity bar (lines ~145–155):
```dart
// OLD:
Expanded(
  child: ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: progress,
      minHeight: 6,
      backgroundColor: AppColors.neutral,
      valueColor: AlwaysStoppedAnimation<Color>(color),
    ),
  ),
),
// NEW:
Expanded(
  child: AppProgressBar(
    progress: progress,
    height: 6,
    fillColor: color,
    fillShadow: _rarityDarkColors[rarity]!,
  ),
),
```

Add `_rarityDarkColors` map alongside `_rarityColors`:
```dart
static const _rarityDarkColors = {
  CardRarity.common: AppColors.cardCommonDark,
  CardRarity.rare: AppColors.cardRareDark,
  CardRarity.epic: AppColors.cardEpicDark,
  CardRarity.legendary: AppColors.cardLegendaryDark,
};
```

- [ ] **Step 3: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/cards/collection_progress_widget.dart
git add lib/presentation/widgets/cards/collection_progress_card.dart
git commit -m "refactor(ui): migrate collection progress bars to AppProgressBar"
```

---

## Task 5: Migrate vocabulary hub, library, and word list screens

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`
- Modify: `lib/presentation/screens/library/library_screen.dart`
- Modify: `lib/presentation/screens/vocabulary/word_list_detail_screen.dart`

- [ ] **Step 1: Update `vocabulary_hub_screen.dart`**

Add import (after existing imports):
```dart
import '../../widgets/common/app_progress_bar.dart';
```

Replace the category bar (lines ~171–179):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: completedUnits / totalUnits,
    backgroundColor: AppColors.neutral,
    color: AppColors.primary,
    minHeight: 6,
  ),
),
// NEW:
AppProgressBar(
  progress: completedUnits / totalUnits,
  height: 6,
),
```

- [ ] **Step 2: Update `library_screen.dart`**

Add import (after existing imports):
```dart
import '../../widgets/common/app_progress_bar.dart';
```

Replace the **level progress bar** (lines ~427–438):
```dart
// OLD:
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: progress,
      backgroundColor: AppColors.neutral.withOpacity(0.3),
      color: color,
      minHeight: 4,
    ),
  ),
),
// NEW:
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: AppProgressBar(
    progress: progress,
    height: 4,
    fillColor: color,
    fillShadow: AppColors.primaryDark,
    backgroundColor: AppColors.gray200,
  ),
),
```

Replace the **book card reading progress bar** (lines ~669–677):
```dart
// OLD:
if (percentage > 0 && percentage < 100)
  ClipRRect(
    child: LinearProgressIndicator(
      value: percentage / 100,
      backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
      color: AppColors.secondary,
      minHeight: 3,
    ),
  ),
// NEW:
if (percentage > 0 && percentage < 100)
  AppProgressBar(
    progress: percentage / 100,
    height: 4,
    fillColor: AppColors.secondary,
    fillShadow: AppColors.secondaryDark,
    backgroundColor: AppColors.gray200,
  ),
```

Replace the **continue reading progress bar** (lines ~976–983):
```dart
// OLD:
ClipRRect(
  child: LinearProgressIndicator(
    value: percentage / 100,
    backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
    color: AppColors.secondary,
    minHeight: 4,
  ),
),
// NEW:
AppProgressBar(
  progress: percentage / 100,
  height: 4,
  fillColor: AppColors.secondary,
  fillShadow: AppColors.secondaryDark,
  backgroundColor: AppColors.gray200,
),
```

- [ ] **Step 3: Update `word_list_detail_screen.dart`**

Add import (after existing imports):
```dart
import '../../widgets/common/app_progress_bar.dart';
```

Replace the accuracy bar (lines ~254–262):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: LinearProgressIndicator(
    value: (progress!.bestAccuracy ?? 0) / 100.0,
    minHeight: 12,
    backgroundColor: Colors.white.withValues(alpha: 0.3),
    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
  ),
),
// NEW:
AppProgressBar(
  progress: (progress!.bestAccuracy ?? 0) / 100.0,
  height: 12,
  fillColor: Colors.white,
  fillShadow: Colors.white.withValues(alpha: 0.5),
  backgroundColor: Colors.white.withValues(alpha: 0.3),
),
```

- [ ] **Step 4: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
git add lib/presentation/screens/library/library_screen.dart
git add lib/presentation/screens/vocabulary/word_list_detail_screen.dart
git commit -m "refactor(ui): migrate vocab hub, library, word list bars to AppProgressBar"
```

---

## Task 6: Migrate reader bars

**Files:**
- Modify: `lib/presentation/widgets/reader/reader_collapsible_header.dart`
- Modify: `lib/presentation/widgets/reader/reader_sidebar.dart`

- [ ] **Step 1: Update `reader_collapsible_header.dart`**

Add import (after existing imports):
```dart
import '../common/app_progress_bar.dart';
```

Replace the scroll progress bar (lines ~325–333):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(2),
  child: LinearProgressIndicator(
    value: scrollProgress,
    minHeight: 3,
    backgroundColor: textColor.withValues(alpha: 0.1),
    valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
  ),
),
// NEW:
AppProgressBar(
  progress: scrollProgress,
  height: 4,
  fillColor: const Color(0xFF6366F1),
  fillShadow: const Color(0xFF4F46E5),
  backgroundColor: textColor.withValues(alpha: 0.15),
),
```

- [ ] **Step 2: Update `reader_sidebar.dart`**

Add import (after existing imports):
```dart
import '../common/app_progress_bar.dart';
```

Replace the audio/reading progress bar (lines ~310–318):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(3),
  child: LinearProgressIndicator(
    value: progress,
    backgroundColor: AppColors.neutral,
    color: AppColors.secondary,
    minHeight: 6,
  ),
),
// NEW:
AppProgressBar(
  progress: progress,
  height: 6,
  fillColor: AppColors.secondary,
  fillShadow: AppColors.secondaryDark,
),
```

- [ ] **Step 3: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/reader/reader_collapsible_header.dart
git add lib/presentation/widgets/reader/reader_sidebar.dart
git commit -m "refactor(ui): migrate reader header + sidebar bars to AppProgressBar"
```

---

## Task 7: Redesign sidebar `_DailyQuestsCard` + migrate `_MonthlyQuestSidebarCard`

**Files:**
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart`

- [ ] **Step 1: Add import**

In `right_info_panel.dart`, add after existing imports:
```dart
import '../common/app_progress_bar.dart';
```

- [ ] **Step 2: Replace `_DailyQuestsCard`**

Find the `_DailyQuestsCard` class (line ~630) and replace the entire class plus the `_QuestRow` class that follows it (lines ~697–792) with:

```dart
// ─── Daily Quests Card ───

class _DailyQuestsCard extends ConsumerWidget {
  const _DailyQuestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(dailyQuestProgressProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Quests',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 12),
        questsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => Text(
            'Could not load quests',
            style: GoogleFonts.nunito(color: AppColors.neutralText),
          ),
          data: (quests) {
            if (quests.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No quests available today',
                  style: GoogleFonts.nunito(color: AppColors.neutralText),
                ),
              );
            }
            final allDone = quests.every((q) => q.isCompleted);
            return Column(
              children: [
                if (allDone) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        AppIcons.check(size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'All quests complete!',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                for (int i = 0; i < quests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SidebarQuestRow(progress: quests[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SidebarQuestRow extends StatelessWidget {
  const _SidebarQuestRow({required this.progress});

  final DailyQuestProgress progress;

  ({Color base, Color shadow}) _colors(String questType) {
    return switch (questType) {
      'earn_xp' => (base: AppColors.primary, shadow: AppColors.primaryDark),
      'earn_combo_xp' => (base: AppColors.cardLegendary, shadow: AppColors.cardLegendaryDark),
      'spend_time' => (base: AppColors.secondary, shadow: AppColors.secondaryDark),
      'complete_chapters' || 'read_chapters' => (
          base: AppColors.secondary,
          shadow: AppColors.secondaryDark
        ),
      'review_words' || 'vocab_session' => (
          base: AppColors.cardEpic,
          shadow: AppColors.cardEpicDark
        ),
      _ => (base: AppColors.gray500, shadow: AppColors.gray600),
    };
  }

  Widget _rewardBadge(DailyQuest quest) {
    final (text, color) = switch (quest.rewardType) {
      QuestRewardType.xp => ('+${quest.rewardAmount} XP', AppColors.primary),
      QuestRewardType.coins => ('+${quest.rewardAmount} 🪙', AppColors.wasp),
      QuestRewardType.cardPack => ('+${quest.rewardAmount} 📦', AppColors.gemBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final isCompleted = progress.isCompleted;
    final ratio = quest.goalValue > 0
        ? (progress.currentValue / quest.goalValue).clamp(0.0, 1.0)
        : 0.0;
    final colors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _colors(quest.questType);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tile
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.base,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
            border: Border.all(color: colors.shadow, width: 1.5),
          ),
          child: Center(
            child: isCompleted
                ? AppIcons.check(size: 24)
                : Text(quest.icon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        // Right column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? AppColors.neutralText : AppColors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              AppProgressBar(
                progress: ratio,
                height: 10,
                fillColor: colors.base,
                fillShadow: colors.shadow,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.currentValue} / ${quest.goalValue}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray500,
                    ),
                  ),
                  _rewardBadge(quest),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Update `_MonthlyQuestSidebarCard` bar**

Find the `LinearProgressIndicator` inside `_MonthlyQuestSidebarCard` (lines ~1454–1462):
```dart
// OLD:
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: fill,
    backgroundColor: Colors.white.withValues(alpha: 0.3),
    color: Colors.white,
    minHeight: 6,
  ),
),
// NEW:
AppProgressBar(
  progress: fill,
  height: 8,
  fillColor: Colors.white,
  fillShadow: Colors.white.withValues(alpha: 0.5),
  backgroundColor: Colors.white.withValues(alpha: 0.3),
),
```

- [ ] **Step 4: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/shell/right_info_panel.dart
git commit -m "feat(ui): redesign sidebar daily quests to island-row style; migrate monthly quest bar"
```

---

## Task 8: Redesign mobile `DailyQuestList` to island style

**Files:**
- Modify: `lib/presentation/widgets/home/daily_quest_list.dart`

- [ ] **Step 1: Rewrite the entire file**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/router.dart';
import 'package:owlio/app/theme.dart';
import 'package:owlio/domain/entities/daily_quest.dart';
import '../../utils/app_icons.dart';
import '../common/app_progress_bar.dart';

/// Renders daily quest rows in badges island style — no outer card,
/// each quest is an individual row with a colored tile on the left.
class DailyQuestList extends StatelessWidget {
  const DailyQuestList({
    super.key,
    required this.progress,
  });

  final List<DailyQuestProgress> progress;

  @override
  Widget build(BuildContext context) {
    final allComplete =
        progress.isNotEmpty && progress.every((q) => q.isCompleted);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (allComplete) ...[
          _AllCompleteBanner(),
          const SizedBox(height: 12),
        ],
        for (int i = 0; i < progress.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _QuestRow(progress: progress[i]),
        ],
      ],
    );
  }
}

class _AllCompleteBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AppIcons.check(size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You've completed all quests for today!",
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.progress});

  final DailyQuestProgress progress;

  ({Color base, Color shadow}) _colors(String questType) {
    return switch (questType) {
      'earn_xp' => (base: AppColors.primary, shadow: AppColors.primaryDark),
      'earn_combo_xp' => (
          base: AppColors.cardLegendary,
          shadow: AppColors.cardLegendaryDark
        ),
      'spend_time' => (base: AppColors.secondary, shadow: AppColors.secondaryDark),
      'complete_chapters' || 'read_chapters' => (
          base: AppColors.secondary,
          shadow: AppColors.secondaryDark
        ),
      'review_words' || 'vocab_session' => (
          base: AppColors.cardEpic,
          shadow: AppColors.cardEpicDark
        ),
      _ => (base: AppColors.gray500, shadow: AppColors.gray600),
    };
  }

  String? _questRoute(String questType) {
    return switch (questType) {
      'read_chapters' => AppRoutes.library,
      'vocab_session' => AppRoutes.vocabularyDailyReview,
      _ => null,
    };
  }

  Widget _rewardBadge(DailyQuest quest) {
    final (text, color) = switch (quest.rewardType) {
      QuestRewardType.xp => ('+${quest.rewardAmount} XP', AppColors.primary),
      QuestRewardType.coins => ('+${quest.rewardAmount} 🪙', AppColors.wasp),
      QuestRewardType.cardPack => ('+${quest.rewardAmount} 📦', AppColors.gemBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final isCompleted = progress.isCompleted;
    final currentValue = progress.currentValue;
    final goalValue = quest.goalValue;
    final ratio = goalValue > 0 ? (currentValue / goalValue).clamp(0.0, 1.0) : 0.0;
    final route = _questRoute(quest.questType);
    final colors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _colors(quest.questType);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: route != null ? () => context.go(route!) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Island tile
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.base,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
              border: Border.all(color: colors.shadow, width: 1.5),
            ),
            child: Center(
              child: isCompleted
                  ? AppIcons.check(size: 28)
                  : Text(
                      quest.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Right column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? AppColors.neutralText : AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                AppProgressBar(
                  progress: ratio,
                  height: 12,
                  fillColor: colors.base,
                  fillShadow: colors.shadow,
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentValue / $goalValue',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray500,
                      ),
                    ),
                    _rewardBadge(quest),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/home/daily_quest_list.dart
git commit -m "feat(ui): redesign DailyQuestList to badges island style"
```

---

## Final verification

- [ ] **Run full analysis**

```bash
dart analyze lib/
```

Expected: no issues.

- [ ] **Visually verify these routes in the running app**

| Route | What to check |
|-------|--------------|
| `/#/badges` | Progress bars unchanged (still reference style) |
| `/#/quests` | Daily quest rows: island tiles, correct colors per type, X/Y label, reward badge |
| Wide screen quests | Sidebar `_DailyQuestsCard`: compact 52px tiles, same island style |
| Wide screen quests | `_MonthlyQuestSidebarCard`: white bar on orange bg |
| `/#/cards` | Collection progress widget + card in right panel |
| `/#/vocabulary` | Vocab hub category bars |
| `/#/vocabulary/review` | Daily review top bar (streakOrange) |
| Vocab session | Top progress bar (blue → orange on combo) |
| Book quiz | Top progress bar with entry animation |
| Reader | Sticky header scroll bar + sidebar reading bar |
| Library | Level bar + book card reading bars |
| Word list detail | Accuracy bar (white on gradient) |
