# SystemSettings Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove 15 unused system_settings from DB, entity, and model. Clean up duplicate AppConfig constants.

**Architecture:** DB migration deletes rows, entity/model trimmed to 6 active fields, AppConfig gamification section cleaned. Admin panel auto-adapts (reads from DB dynamically).

**Tech Stack:** Flutter, Supabase (PostgreSQL), Dart

**Spec:** `docs/superpowers/specs/2026-03-23-system-settings-cleanup-design.md`

---

## Task 1: DB Migration — Delete 15 Unused Settings

**Files:**
- Create: `supabase/migrations/20260323000014_remove_unused_settings.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Remove unused system_settings entries
-- These settings have no runtime consumers in the Flutter app or DB functions
DELETE FROM system_settings WHERE key IN (
  'xp_activity_complete',
  'xp_activity_perfect',
  'xp_word_learned',
  'xp_word_mastered',
  'xp_streak_bonus_day',
  'xp_assignment_complete',
  'max_streak_multiplier',
  'streak_bonus_increment',
  'daily_xp_cap',
  'default_time_limit',
  'hint_penalty_percent',
  'skip_penalty_percent',
  'maintenance_mode',
  'min_app_version',
  'feature_word_lists',
  'feature_achievements'
);
```

- [ ] **Step 2: Push migration**

Run: `supabase db push --dry-run` then `supabase db push`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260323000014_remove_unused_settings.sql
git commit -m "feat(db): remove 15 unused system_settings entries

These settings had no runtime consumers. Admin panel auto-adapts
since it reads settings dynamically from the DB."
```

---

## Task 2: Trim SystemSettings Entity to 6 Fields

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`

- [ ] **Step 1: Rewrite the entity file**

Replace the entire file content with:

```dart
import 'package:equatable/equatable.dart';

/// System-wide configuration settings entity
/// Only contains settings that are actively used at runtime
class SystemSettings extends Equatable {
  const SystemSettings({
    // XP Rewards
    this.xpChapterComplete = 50,
    this.xpBookComplete = 200,
    this.xpQuizPass = 20,
    // Streak
    this.streakFreezePrice = 50,
    this.streakFreezeMax = 2,
    // Debug
    this.debugDateOffset = 0,
  });

  // XP Rewards
  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;

  // Streak
  final int streakFreezePrice;
  final int streakFreezeMax;

  // Debug
  final int debugDateOffset;

  /// Default settings (fallback when database is unavailable)
  factory SystemSettings.defaults() => const SystemSettings();

  @override
  List<Object?> get props => [
        xpChapterComplete,
        xpBookComplete,
        xpQuizPass,
        streakFreezePrice,
        streakFreezeMax,
        debugDateOffset,
      ];
}
```

- [ ] **Step 2: Run analyze to find compile errors**

Run: `dart analyze lib/ 2>&1 | grep "error -"`
Expected: Errors in `system_settings_model.dart` (references removed fields). No errors elsewhere — if there are, it means we missed a consumer and must investigate.

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/system_settings.dart
git commit -m "refactor: trim SystemSettings entity to 6 active fields

Removed 15 unused fields. Compiler errors in model expected — fixed
in next commit."
```

---

## Task 3: Trim SystemSettingsModel to Match Entity

**Files:**
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Rewrite the model file**

Replace the entire file content with:

```dart
import '../../../domain/entities/system_settings.dart';

/// Model for system settings with JSON serialization
class SystemSettingsModel {
  const SystemSettingsModel({
    required this.xpChapterComplete,
    required this.xpBookComplete,
    required this.xpQuizPass,
    required this.streakFreezePrice,
    required this.streakFreezeMax,
    required this.debugDateOffset,
  });

  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;
  final int streakFreezePrice;
  final int streakFreezeMax;
  final int debugDateOffset;

  /// Parse from database rows (key-value pairs)
  factory SystemSettingsModel.fromRows(List<Map<String, dynamic>> rows) {
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      map[key] = _parseJsonbValue(row['value']);
    }
    return SystemSettingsModel.fromMap(map);
  }

  /// Parse from key-value map
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) {
    return SystemSettingsModel(
      xpChapterComplete: _toInt(m['xp_chapter_complete'], 50),
      xpBookComplete: _toInt(m['xp_book_complete'], 200),
      xpQuizPass: _toInt(m['xp_quiz_pass'], 20),
      streakFreezePrice: _toInt(m['streak_freeze_price'], 50),
      streakFreezeMax: _toInt(m['streak_freeze_max'], 2),
      debugDateOffset: _toInt(m['debug_date_offset'], 0),
    );
  }

  /// Default model (fallback)
  factory SystemSettingsModel.defaults() => const SystemSettingsModel(
        xpChapterComplete: 50,
        xpBookComplete: 200,
        xpQuizPass: 20,
        streakFreezePrice: 50,
        streakFreezeMax: 2,
        debugDateOffset: 0,
      );

  /// Convert to entity
  SystemSettings toEntity() => SystemSettings(
        xpChapterComplete: xpChapterComplete,
        xpBookComplete: xpBookComplete,
        xpQuizPass: xpQuizPass,
        streakFreezePrice: streakFreezePrice,
        streakFreezeMax: streakFreezeMax,
        debugDateOffset: debugDateOffset,
      );

  /// Create model from entity
  factory SystemSettingsModel.fromEntity(SystemSettings e) =>
      SystemSettingsModel(
        xpChapterComplete: e.xpChapterComplete,
        xpBookComplete: e.xpBookComplete,
        xpQuizPass: e.xpQuizPass,
        streakFreezePrice: e.streakFreezePrice,
        streakFreezeMax: e.streakFreezeMax,
        debugDateOffset: e.debugDateOffset,
      );

  // Helper: Parse JSONB value (removes quotes, converts types)
  static dynamic _parseJsonbValue(dynamic v) {
    if (v is! String) return v;
    final s = v.replaceAll('"', '');
    if (s == 'true') return true;
    if (s == 'false') return false;
    return int.tryParse(s) ?? double.tryParse(s) ?? s;
  }

  static int _toInt(dynamic v, int defaultValue) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }
}
```

Note: `_toDouble` and `_toBool` helpers removed since no remaining fields use them.

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/ 2>&1 | grep "error -"`
Expected: 0 errors. If there are errors referencing removed fields, a consumer was missed — investigate before proceeding.

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/settings/system_settings_model.dart
git commit -m "refactor: trim SystemSettingsModel to match 6-field entity

Removed 15 unused field mappings. Removed _toDouble and _toBool
helpers (no remaining fields use them)."
```

---

## Task 4: Clean Up AppConfig Duplicate Constants

**Files:**
- Modify: `lib/core/config/app_config.dart`

- [ ] **Step 1: Remove 3 unused gamification constants**

In `lib/core/config/app_config.dart`, remove these lines (currently around lines 55-62):

```dart
  /// Maximum streak bonus multiplier
  static const double maxStreakMultiplier = 2.0;

  /// Streak bonus increment per day
  static const double streakBonusIncrement = 0.1;

  /// Daily XP cap (prevents gaming the system)
  static const int dailyXPCap = 1000;
```

Replace with just the XP comment that's already there. The Gamification section should become:

```dart
  // ============================================
  // Gamification
  // ============================================

  // XP rewards → managed via system_settings table (admin panel configurable)
  // See: SystemSettings entity + systemSettingsProvider

  // ============================================
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/ 2>&1 | grep "error -"`
Expected: 0 errors. These constants had no consumers (verified by grep).

- [ ] **Step 3: Commit**

```bash
git add lib/core/config/app_config.dart
git commit -m "chore: remove unused gamification constants from AppConfig

maxStreakMultiplier, streakBonusIncrement, dailyXPCap had no runtime
consumers. Streak/XP settings are managed via system_settings table."
```

---

## Task 5: Final Verification

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/`
Expected: 0 errors.

- [ ] **Step 2: Grep for any remaining references to removed fields**

Run these greps — all should return no matches:
```bash
grep -r "xpActivityComplete\|xpActivityPerfect\|xpWordLearned\|xpWordMastered" lib/
grep -r "xpStreakBonusDay\|xpAssignmentComplete\|maxStreakMultiplier" lib/
grep -r "streakBonusIncrement\|dailyXpCap\|defaultTimeLimit" lib/
grep -r "hintPenaltyPercent\|skipPenaltyPercent\|maintenanceMode" lib/
grep -r "minAppVersion\|featureWordLists\|featureAchievements" lib/
```

- [ ] **Step 3: Verify migration**

Run: `supabase migration list`
Expected: `20260323000014` shows as applied.
