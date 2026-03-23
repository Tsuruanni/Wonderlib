# SystemSettings Cleanup — Design Spec

**Date:** 2026-03-23
**Scope:** Remove 15 unused system_settings entries, trim entity/model, delete dead legacy activity code, clean up AppConfig duplicates

---

## Problem Statement

Audit revealed that 15 of 21 system_settings values are completely unused at runtime. The admin panel displays them as editable, giving the false impression they're configurable. Additionally, a legacy "end-of-chapter activity" system exists as dead code.

---

## What Stays (6 settings)

| DB Key | Entity Property | Active Consumer |
|--------|----------------|-----------------|
| `xp_chapter_complete` | `xpChapterComplete` | `book_provider.dart` |
| `xp_book_complete` | `xpBookComplete` | `book_provider.dart` |
| `xp_quiz_pass` | `xpQuizPass` | `book_quiz_provider.dart` |
| `streak_freeze_price` | `streakFreezePrice` | `top_navbar.dart` + DB `buy_streak_freeze` |
| `streak_freeze_max` | `streakFreezeMax` | `top_navbar.dart` + DB `buy_streak_freeze` |
| `debug_date_offset` | `debugDateOffset` | `system_settings_provider.dart` + DB `app_current_date()` |

---

## What Gets Removed

### A. DB rows (15 settings) — DELETE via migration

```
xp_activity_complete, xp_activity_perfect, xp_word_learned, xp_word_mastered,
xp_streak_bonus_day, xp_assignment_complete, max_streak_multiplier,
streak_bonus_increment, daily_xp_cap, default_time_limit, hint_penalty_percent,
skip_penalty_percent, maintenance_mode, min_app_version, feature_word_lists,
feature_achievements
```

### B. Entity + Model fields (15 properties)

Remove from `SystemSettings` entity: constructor params, field declarations, props list.
Remove from `SystemSettingsModel`: constructor params, field declarations, `fromMap()`, `defaults()`, `toEntity()`, `fromEntity()`.

### C. Dead legacy activity code

| File | What to remove |
|------|---------------|
| `lib/data/repositories/supabase/supabase_activity_repository.dart` | `_calculateXP()` method (if only used by dead submitActivityResult path) |
| `lib/presentation/providers/activity_provider.dart` | `ActivitySessionController` + its provider (if unreferenced) |
| `lib/presentation/screens/reader/activity_screen.dart` | Entire stub file (if unreferenced) |

**Safety check:** Before deleting, grep for all references. Only delete if truly unreachable. If the router references `activity_screen.dart`, remove the route too.

### D. AppConfig duplicate constants

Remove from `lib/core/config/app_config.dart`:
- `maxStreakMultiplier` (2.0)
- `streakBonusIncrement` (0.1)
- `dailyXPCap` (1000)

**Safety check:** Grep for usages before removing. If referenced elsewhere, leave them.

---

## Risk Mitigation

1. **Admin panel settings screen** auto-reads from DB — deleted rows disappear automatically, no admin code changes needed.
2. **`SystemSettingsModel.fromMap()`** uses defaults for missing keys — removing DB rows without updating model first won't crash (safe migration order either way).
3. **Removing entity fields causes compile-time errors** if anything references them — the compiler is our safety net.
4. **Dead code deletion** is verified by grep before removal — no blind deletes.
5. **`dart analyze`** after every change confirms no breakage.

---

## Files Changed

| File | Change |
|------|--------|
| `supabase/migrations/20260323000014_remove_unused_settings.sql` | DELETE 15 rows |
| `lib/domain/entities/system_settings.dart` | Remove 15 fields |
| `lib/data/models/settings/system_settings_model.dart` | Remove 15 fields from all methods |
| `lib/core/config/app_config.dart` | Remove 3 duplicate constants |
| `lib/data/repositories/supabase/supabase_activity_repository.dart` | Remove `_calculateXP()` (after safety check) |
| `lib/presentation/providers/activity_provider.dart` | Remove dead `ActivitySessionController` (after safety check) |
| `lib/presentation/screens/reader/activity_screen.dart` | Delete file (after safety check) |
| Router file (if referencing activity_screen) | Remove route |

---

## Verification

```bash
dart analyze lib/
grep -r "xpActivityComplete\|xpActivityPerfect\|xpWordLearned\|xpWordMastered" lib/
grep -r "xpStreakBonusDay\|xpAssignmentComplete\|maxStreakMultiplier" lib/
grep -r "dailyXpCap\|defaultTimeLimit\|hintPenaltyPercent\|skipPenaltyPercent" lib/
grep -r "maintenanceMode\|minAppVersion\|featureWordLists\|featureAchievements" lib/
grep -r "_calculateXP\|ActivitySessionController\|activity_screen" lib/
```
