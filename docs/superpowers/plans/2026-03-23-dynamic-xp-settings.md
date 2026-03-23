# Dynamic XP Settings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all XP reward values read from `system_settings` DB table instead of hardcoded `AppConfig.xpRewards`, so admin panel changes take effect at runtime.

**Architecture:** Add `xpQuizPass` to SystemSettings entity/model, migrate providers from AppConfig to SystemSettings, move quiz XP awarding from repository to controller, clean up dead AppConfig code.

**Tech Stack:** Flutter, Riverpod, Supabase, owlio_shared

**Spec:** `docs/superpowers/specs/2026-03-23-dynamic-xp-settings-design.md`

---

## Task 1: DB Migration — Add `xp_quiz_pass` to system_settings

**Files:**
- Create: `supabase/migrations/20260323000013_add_xp_quiz_pass_setting.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- Add quiz pass XP reward to system_settings
INSERT INTO system_settings (key, value, category, description)
VALUES ('xp_quiz_pass', '"20"', 'xp', 'XP awarded for passing a book quiz')
ON CONFLICT (key) DO NOTHING;
```

- [ ] **Step 2: Push migration**

Run: `supabase db push --dry-run` then `supabase db push`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260323000013_add_xp_quiz_pass_setting.sql
git commit -m "feat(db): add xp_quiz_pass to system_settings table"
```

---

## Task 2: Add `xpQuizPass` to SystemSettings Entity + Model

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add field to entity**

In `lib/domain/entities/system_settings.dart`:

Add to constructor (after line 15 `this.xpAssignmentComplete = 100,`):
```dart
    this.xpQuizPass = 20,
```

Add field declaration (after line 42 `final int xpAssignmentComplete;`):
```dart
  final int xpQuizPass;
```

Add to props list (after line 77 `xpAssignmentComplete,`):
```dart
        xpQuizPass,
```

- [ ] **Step 2: Add field to model**

In `lib/data/models/settings/system_settings_model.dart`:

Add to constructor (after line 13 `required this.xpAssignmentComplete,`):
```dart
    required this.xpQuizPass,
```

Add field declaration (after line 36 `final int xpAssignmentComplete;`):
```dart
  final int xpQuizPass;
```

Add to `fromMap()` (after line 71 `xpAssignmentComplete: _toInt(m['xp_assignment_complete'], 100),`):
```dart
      xpQuizPass: _toInt(m['xp_quiz_pass'], 20),
```

Add to `defaults()` (after line 97 `xpAssignmentComplete: 100,`):
```dart
        xpQuizPass: 20,
```

Add to `toEntity()` (after line 122 `xpAssignmentComplete: xpAssignmentComplete,`):
```dart
        xpQuizPass: xpQuizPass,
```

Add to `fromEntity()` (after line 148 `xpAssignmentComplete: e.xpAssignmentComplete,`):
```dart
        xpQuizPass: e.xpQuizPass,
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add xpQuizPass to SystemSettings entity and model"
```

---

## Task 3: Switch `book_provider.dart` from AppConfig to SystemSettings

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart`

- [ ] **Step 1: Replace AppConfig import with SystemSettings imports**

In `lib/presentation/providers/book_provider.dart`:

Replace line 24:
```dart
import '../../core/config/app_config.dart';
```
With:
```dart
import '../../domain/entities/system_settings.dart';
import 'system_settings_provider.dart';
```

- [ ] **Step 2: Replace XP values in completeChapter method**

Replace line 184:
```dart
        await _ref.read(userControllerProvider.notifier).addXP(AppConfig.xpRewards['chapter_complete']!);
```
With:
```dart
        final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
        await _ref.read(userControllerProvider.notifier).addXP(settings.xpChapterComplete);
```

Replace line 192 (line number shifted after above edit):
```dart
            await _ref.read(userControllerProvider.notifier).addXP(AppConfig.xpRewards['book_complete']!);
```
With:
```dart
            await _ref.read(userControllerProvider.notifier).addXP(settings.xpBookComplete);
```

Note: `settings` was already declared above in the same `if (!wasAlreadyCompleted)` block, so both usages share the same variable.

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/book_provider.dart
git commit -m "refactor: book_provider reads XP from SystemSettings instead of AppConfig"
```

---

## Task 4: Move Quiz XP/Badge from Repository to Controller

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_book_quiz_repository.dart`
- Modify: `lib/presentation/providers/book_quiz_provider.dart`

- [ ] **Step 1: Remove XP/badge logic from repository's _handleQuizPassed**

In `lib/data/repositories/supabase/supabase_book_quiz_repository.dart`, remove the XP/badge block from `_handleQuizPassed` (lines 133-144):

**Remove these lines:**
```dart
      // Award XP for first-time quiz passing
      try {
        await _supabase.rpc(RpcFunctions.awardXpTransaction, params: {
          'p_user_id': userId,
          'p_amount': AppConfig.xpRewards['quiz_pass']!, // Quiz pass XP
        });
        await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
          'p_user_id': userId,
        });
      } catch (e) {
        debugPrint('BookQuiz: XP/badge award failed (non-critical): $e');
      }
```

Also remove the now-unused `AppConfig` import (line 6):
```dart
import '../../../core/config/app_config.dart';
```

- [ ] **Step 2: Add XP awarding to BookQuizController**

In `lib/presentation/providers/book_quiz_provider.dart`:

Add imports at the top (after line 2):
```dart
import '../../domain/entities/system_settings.dart';
import 'system_settings_provider.dart';
import 'user_provider.dart';
```

In the `submitQuiz` method's success branch (after line 126 `_ref.invalidate(isQuizReadyProvider(bookId));`), add:

```dart

        // Award XP for passing quiz (addXP also triggers badge check)
        if (savedResult.isPassing) {
          final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
          await _ref.read(userControllerProvider.notifier).addXP(settings.xpQuizPass);
        }
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/supabase/supabase_book_quiz_repository.dart lib/presentation/providers/book_quiz_provider.dart
git commit -m "refactor: move quiz XP awarding from repository to controller

Repository now only handles reading_progress updates. XP and badge
checks happen in BookQuizController which has access to dynamic
SystemSettings via provider. addXP UseCase already calls
checkAndAwardBadges internally."
```

---

## Task 5: Clean Up AppConfig.xpRewards

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Remove xpRewards map from AppConfig**

In `lib/core/config/app_config.dart`, remove lines 64-75:

```dart
  /// XP rewards for different actions
  static const Map<String, int> xpRewards = {
    'chapter_complete': 50,
    'activity_complete': 20,
    'activity_perfect': 30,
    'word_learned': 5,
    'word_mastered': 15,
    'book_complete': 200,
    'streak_bonus_day': 10,
    'assignment_complete': 100,
    'quiz_pass': 20,
  };
```

- [ ] **Step 2: Remove XP comment from AppConstants**

In `lib/core/constants/app_constants.dart`, remove lines 21-22:
```dart
  // XP values → use AppConfig.xpRewards (single source of truth)
  // See: lib/core/config/app_config.dart
```

- [ ] **Step 3: Remove unused AppConfig import from router.dart**

In `lib/app/router.dart`, remove line 6:
```dart
import '../core/config/app_config.dart';
```

- [ ] **Step 4: Run analyze**

Run: `dart analyze lib/`
Expected: No errors. If AppConfig is now unused elsewhere and the class is empty, consider removing the entire file — but check first.

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_config.dart lib/core/constants/app_constants.dart lib/app/router.dart
git commit -m "chore: remove dead AppConfig.xpRewards map

All XP values now read from SystemSettings (database). The hardcoded
xpRewards map and its references are no longer needed."
```

---

## Task 6: Final Verification

- [ ] **Step 1: Analyze**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 2: Verify migration**

Run: `supabase migration list`
Expected: `20260323000013` shows as applied.

- [ ] **Step 3: Grep for any remaining AppConfig.xpRewards references**

Run: `grep -r "AppConfig.xpRewards" lib/`
Expected: No matches.
