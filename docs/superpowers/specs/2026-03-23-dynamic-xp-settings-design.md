# Dynamic XP Settings — Design Spec

**Date:** 2026-03-23
**Scope:** Make all XP reward values read from `system_settings` DB table (admin panel configurable) instead of hardcoded `AppConfig.xpRewards`

---

## Problem Statement

Admin panel has a Settings screen that lets admins edit XP values in the `system_settings` table. The main app has `SystemSettings` entity/model/provider infrastructure that fetches these values. However, **no code actually reads XP from SystemSettings at runtime** — all 3 usage points read from `AppConfig.xpRewards` (hardcoded static map).

### Current XP Usage Points

| Location | Value | Has `ref` access? |
|----------|-------|-------------------|
| `book_provider.dart:184` | `chapter_complete` (50) | Yes — it's a StateNotifier |
| `book_provider.dart:192` | `book_complete` (200) | Yes |
| `supabase_book_quiz_repository.dart:137` | `quiz_pass` (20) | No — it's a repository |

---

## Design

### A. Add `xp_quiz_pass` to DB and SystemSettings

1. **Migration**: INSERT `xp_quiz_pass` = `"20"` into `system_settings` with category `xp`
2. **Entity**: Add `xpQuizPass` field to `SystemSettings` (default: 20)
3. **Model**: Add `xpQuizPass` to `fromMap()`, `fromEntity()`, `toEntity()`, `defaults()`, constructor

### B. Provider XP: `book_provider.dart` → SystemSettings

Replace `AppConfig.xpRewards['chapter_complete']!` and `AppConfig.xpRewards['book_complete']!` with values from `systemSettingsProvider`. The `BookController` is a `StateNotifier` created with `ref`, so it can read `systemSettingsProvider`.

**Before:**
```dart
await _ref.read(userControllerProvider.notifier).addXP(AppConfig.xpRewards['chapter_complete']!);
```

**After:**
```dart
final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
await _ref.read(userControllerProvider.notifier).addXP(settings.xpChapterComplete);
```

### C. Repository XP: Move quiz XP awarding from repository to controller

The repository (`supabase_book_quiz_repository.dart`) has `_handleQuizPassed` which does:
1. Updates `reading_progress` (quiz_passed, is_completed) — **keep in repo**
2. Awards XP via `awardXpTransaction` RPC — **move to controller**
3. Calls `checkAndAwardBadges` RPC — **move to controller**

**Why move?** Repositories don't have access to `ref`/providers. Rather than injecting SystemSettings into the repository constructor (ripple effect on cache layer, tests), we move the side-effect (XP/badge) to `BookQuizController` which already has `ref` access and already runs invalidation after quiz submission.

The controller (`book_quiz_provider.dart`) already handles the "after submission" flow. We add XP/badge calls there, reading the amount from `systemSettingsProvider`.

### D. Clean up AppConfig.xpRewards

Remove `AppConfig.xpRewards` map entirely and the comment in `app_constants.dart` that references it. It's now dead code — all values come from `SystemSettings`.

---

## Files Changed

| File | Change |
|------|--------|
| `supabase/migrations/20260323000013_add_xp_quiz_pass_setting.sql` | INSERT xp_quiz_pass |
| `lib/domain/entities/system_settings.dart` | Add `xpQuizPass` field |
| `lib/data/models/settings/system_settings_model.dart` | Add `xpQuizPass` to all methods |
| `lib/presentation/providers/book_provider.dart` | `AppConfig` → `systemSettingsProvider` |
| `lib/presentation/providers/book_quiz_provider.dart` | Add XP/badge calls after passing quiz |
| `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` | Remove XP/badge from `_handleQuizPassed` + remove `AppConfig` import |
| `lib/core/config/app_config.dart` | Remove `xpRewards` map |
| `lib/core/constants/app_constants.dart` | Remove XP reference comment |

---

## Out of Scope

- Other XP sources (reader_provider `addXP` calls with dynamic amounts from activity scoring)
- Vocabulary XP (word_learned, word_mastered) — these are awarded by edge functions, not Flutter code
- SystemSettings caching/refresh strategy
