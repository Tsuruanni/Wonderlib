# System Settings

## Audit

### Findings
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `SystemSettingsModel.fromEntity` factory had no callers (read-only from app) | Low | Fixed |
| 2 | UX | Admin info banner said "main app integration not yet done" — stale copy, integration is fully implemented | Low | Fixed |
| 3 | Cross-System | `complete_daily_review` RPC hard-codes `v_session_bonus = 10`, `v_perfect_bonus = 20`; `complete_vocabulary_session` reads from `system_settings`. Changing these values in admin has partial effect | Medium | Fixed |
| 4 | Code Quality | Admin `_updateSetting` stores raw String to JSONB column; DB has inconsistent formats (`50` vs `"50"`) from migrations. Model's `_parseJsonbValue` handles both, but admin writes always produce JSON-string format | Low | Fixed |
| 5 | Dead Code | `'game'` category in admin router has zero live DB rows after migration `20260323000014`; renders empty section | Low | Fixed |
| 6 | Edge Case | If user triggers XP-awarding action before `systemSettingsProvider` resolves on first launch, defaults are used silently | Low | Accepted |

### Checklist Result
- Architecture Compliance: PASS
- Code Quality: PASS (tripled defaults consolidated)
- Dead Code: PASS (all resolved)
- Database & Security: PASS (RLS correct, RPC consumers have auth checks)
- Edge Cases & UX: PASS (stale banner fixed, cold-start race accepted)
- Performance: PASS (single bulk fetch, no N+1, no unnecessary rebuilds)
- Cross-System Integrity: PASS (`complete_daily_review` now reads from settings)

---

## Overview

System Settings is a global key-value configuration store that controls XP rewards, notification toggles, streak parameters, and debug features across the entire Owlio platform. Admins manage settings through a categorized editor in the admin panel. The main app fetches all settings once at startup and uses them throughout the session for XP calculations, notification gating, and streak mechanics.

## Data Model

### `system_settings` table
| Column | Type | Description |
|--------|------|-------------|
| `key` | VARCHAR(100) PK | Unique setting identifier (e.g., `xp_chapter_complete`) |
| `value` | JSONB | Setting value (int, bool, or JSON object) |
| `category` | VARCHAR(50) | Grouping for admin UI (`xp_reading`, `xp_vocab`, `progression`, `notification`, `app`) |
| `description` | TEXT | Human-readable description shown in admin editor |
| `group_label` | VARCHAR(100) | Sub-group header within a category (e.g., "Inline Activity XP") |
| `sort_order` | INTEGER | Display order within category |

No foreign keys. Standalone table. ~35 rows total.

### RLS Policies
- **SELECT**: `USING (true)` — all users can read (needed for app runtime)
- **INSERT/UPDATE/DELETE**: `USING (profiles.role = 'admin')` — admin-only writes

## Surfaces

### Admin
- **Route**: `/settings` — displays categories `xp_reading`, `xp_vocab`, `progression`, `game`, `app`
- **Route**: `/notifications` — displays category `notification` (separate screen)
- **Editor UI**: Grouped by category with sub-group headers (`group_label`). Auto-detects input type: Switch for booleans, number field for integers, text field for strings
- **Save flow**: Inline auto-save on field submit → `UPDATE system_settings SET value = $1 WHERE key = $2` → snackbar confirmation → provider invalidation
- **States**: Loading spinner, error with retry button, empty state with migration reminder

### Student
- **No direct UI**. Settings are consumed transparently at runtime:
  - XP values determine rewards for chapters, books, quizzes, inline activities, vocab questions
  - Notification toggles gate in-app notification dialogs (streak, level-up, league change, badge, assignment)
  - Streak freeze price/max control the freeze purchase flow
  - `debug_date_offset` shifts the app clock for testing (via `AppClock.setOffset`)

### Teacher
N/A

## Business Rules

1. **Settings are read-only from the main app** — only the admin panel writes to `system_settings`
2. **Fallback to defaults** — if the DB fetch fails or returns empty rows, `SystemSettings.defaults()` provides hardcoded fallback values (all defaults match the initial migration seed)
3. **No live reload** — settings are fetched once per app session. Admin changes take effect only when users restart the app
4. **JSONB value parsing** — the model layer handles mixed formats: bare integers (`50`), quoted strings (`"50"`), booleans (`true`/`"true"`), and JSON objects (`{"7":50,"14":100}` for milestone maps). The `_parseJsonbValue` helper normalizes all formats
5. **Server-side RPCs also read settings** — `complete_vocabulary_session`, `buy_streak_freeze`, and `update_user_streak` RPCs read their config values directly from `system_settings` at execution time (not from the client)
6. **Default values are tripled** — entity constructor defaults, `SystemSettings.defaults()` factory, and `SystemSettingsModel.fromMap` fallback parameters all express the same defaults. When adding a new setting, all three must be updated

## Settings Reference

### Category: `xp_reading`
| Key | Default | Description |
|-----|---------|-------------|
| `xp_chapter_complete` | 50 | XP awarded per completed chapter |
| `xp_book_complete` | 200 | XP awarded when all chapters + quiz done |
| `xp_quiz_pass` | 20 | XP awarded when book quiz passed (>=70%) |
| `xp_inline_true_false` | 25 | XP per true/false inline activity |
| `xp_inline_word_translation` | 25 | XP per word translation inline activity |
| `xp_inline_find_words` | 25 | XP per find words inline activity |
| `xp_inline_matching` | 25 | XP per matching inline activity |

### Category: `xp_vocab`
| Key | Default | Description |
|-----|---------|-------------|
| `xp_vocab_multiple_choice` | 10 | XP per correct multiple choice answer |
| `xp_vocab_matching` | 15 | XP per correct matching answer |
| `xp_vocab_scrambled_letters` | 20 | XP per correct scrambled letters answer |
| `xp_vocab_spelling` | 25 | XP per correct spelling answer |
| `xp_vocab_sentence_gap` | 30 | XP per correct sentence gap answer |
| `combo_bonus_xp` | 5 | XP per combo streak unit |
| `xp_vocab_session_bonus` | 10 | Flat bonus XP for completing a vocab session |
| `xp_vocab_perfect_bonus` | 20 | Extra bonus XP for 100% accuracy session |

### Category: `progression`
| Key | Default | Description |
|-----|---------|-------------|
| `streak_freeze_price` | 50 | Coin cost to buy a streak freeze |
| `streak_freeze_max` | 2 | Maximum freeze count a student can hold |
| `streak_milestones` | `{7:50, 14:100, 30:200, 60:400, 100:1000}` | Day→XP map for streak milestone bonuses |
| `streak_milestone_repeat_interval` | 100 | After last defined milestone, bonus repeats every N days |
| `streak_milestone_repeat_xp` | 1000 | XP awarded for each repeating milestone |

### Category: `notification`
| Key | Default | Description |
|-----|---------|-------------|
| `notif_streak_extended` | true | Show "streak extended" dialog |
| `notif_streak_broken` | true | Show "streak broken" dialog |
| `notif_streak_broken_min` | 3 | Minimum streak before showing "broken" notification |
| `notif_milestone` | true | Show streak milestone dialog |
| `notif_level_up` | true | Show level-up celebration |
| `notif_league_change` | true | Show league promotion/demotion dialog |
| `notif_freeze_saved` | true | Show "freeze saved your streak" dialog |
| `notif_badge_earned` | true | Show badge earned dialog |
| `notif_assignment` | true | Show new assignment notification |

### Category: `app`
| Key | Default | Description |
|-----|---------|-------------|
| `debug_date_offset` | 0 | Shift app clock by N days (testing only). Also affects SQL `app_current_date()` / `app_now()` functions |

### Category: `game`
(Empty — all rows removed in migration `20260323000014`. Category entry in admin router is vestigial.)

## Cross-System Interactions

### Settings → XP Awards
```
Admin changes xp_chapter_complete = 100
  → User restarts app → systemSettingsProvider loads new value
  → book_provider.markComplete() reads settings.xpChapterComplete
  → addXP(100) instead of default 50
```

### Settings → Vocab Session (server-side)
```
Admin changes xp_vocab_session_bonus = 15
  → complete_vocabulary_session RPC reads system_settings at execution time
  → New sessions get 15 XP bonus immediately (no app restart needed)
```

### Settings → Streak Mechanics (server-side)
```
Admin changes streak_freeze_price = 75
  → buy_streak_freeze RPC reads from system_settings
  → Takes effect immediately for next purchase
```

### Settings → Notification Gating
```
Admin toggles notif_level_up = false
  → User restarts app → settings load
  → user_provider._showNotificationIfEnabled checks notifLevelUp
  → Level-up celebration dialog suppressed
```

### Settings → Daily Review (server-side)
```
Admin changes xp_vocab_session_bonus = 15
  → complete_daily_review RPC reads system_settings at execution time
  → New daily reviews get 15 XP bonus immediately (same pattern as vocab sessions)
```

## Edge Cases

- **DB unavailable at startup**: App uses `SystemSettings.defaults()` — all features work with hardcoded fallbacks
- **Empty settings table**: Repository returns `SystemSettingsModel.defaults().toEntity()` (explicit empty-row handling)
- **Race condition on cold start**: If XP is awarded before `systemSettingsProvider` resolves, `ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults()` returns defaults silently
- **Admin saves non-numeric string to numeric field**: The admin UI allows any string submission. `_toInt` parsing in model will fall back to default on next app load. DB stores whatever was sent
- **Mid-session admin change**: Running app instances don't see new values until restart. Server-side RPCs (`complete_vocabulary_session`, `buy_streak_freeze`, `update_user_streak`) pick up changes immediately

## Test Scenarios

- [ ] Happy path: Admin changes `xp_chapter_complete` to 100, student completes chapter → 100 XP awarded (after app restart)
- [ ] Happy path: Admin toggles `notif_level_up` to false → level-up celebration does not appear
- [ ] Happy path: Admin changes `streak_freeze_price` to 75 → next freeze purchase costs 75 coins
- [ ] Empty state: Fresh database with no `system_settings` rows → app runs with defaults, admin shows "Ayar bulunamadı"
- [ ] Error state: Network failure on settings fetch → app falls back to defaults with `debugPrint` warning
- [ ] Boundary: Admin enters 0 for XP value → 0 XP awarded (valid)
- [ ] Boundary: Admin enters negative number → stored as-is, `_toInt` parses it, negative XP would be awarded
- [ ] Cross-system: Change `xp_vocab_session_bonus` → verify both `complete_vocabulary_session` and `complete_daily_review` RPCs use new value
- [ ] Server-side immediacy: Change `streak_freeze_price` → buy freeze without app restart → new price applies

## Key Files

**Main App:**
- `lib/domain/entities/system_settings.dart` — Entity with 31 typed fields + defaults
- `lib/data/models/settings/system_settings_model.dart` — JSONB parsing, type coercion, row-to-entity mapping
- `lib/presentation/providers/system_settings_provider.dart` — `FutureProvider<SystemSettings>`, single fetch with fallback

**Admin Panel:**
- `owlio_admin/lib/features/settings/screens/settings_screen.dart` — Generic category-based editor with inline save
- `owlio_admin/lib/core/router.dart:322` — Route config with category list

**Database:**
- `supabase/migrations/20260202000007_create_system_settings.sql` — Table creation + initial seed
- `supabase/migrations/20260324000004_merge_xp_categories_with_groups.sql` — Final category/group structure

## Known Issues & Tech Debt

1. **No live reload** — Settings are fetched once per app session. A Supabase realtime subscription or periodic refresh would improve admin responsiveness, but current behavior is acceptable for low-frequency config changes.
2. **Cold-start race (accepted)** — If XP is awarded before `systemSettingsProvider` resolves on first launch, entity defaults are used. Risk is near-zero: settings load is <100ms and defaults match DB seeds.
3. **Legacy JSONB format in DB** — Migration seeds have mixed formats (bare int vs quoted string). Admin writes now send proper typed values, but existing rows retain their original format until edited. `_parseJsonbValue` handles both transparently.
