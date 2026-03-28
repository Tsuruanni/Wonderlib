# Configurable Settings Migration — Design Spec

## Problem

Several business-logic values are hardcoded in Dart code and SQL RPCs instead of being read from the admin-configurable `system_settings` table. This prevents admins from tuning game balance without code changes.

**Additionally:** A data inconsistency exists — the card pack pity threshold is `14` in the SQL RPC but `15` in the Dart client (`AppConstants.pityThreshold`).

## Scope

### In Scope (CRITICAL + HIGH)

| # | Value | Current | Location(s) | Type |
|---|-------|---------|-------------|------|
| 1 | Card pack cost | 100 coins | `BuyPackParams.cost`, `AppConstants.packCost`, `pack_opening_screen.dart`, SQL default | Dart + SQL |
| 2 | Star rating 3★ threshold | 90% | `word_list.dart:88` | Dart |
| 3 | Star rating 2★ threshold | 70% | `word_list.dart:89` | Dart |
| 4 | Star rating 1★ threshold | 50% | `word_list.dart:90` | Dart |
| 5 | Daily review base XP per correct | 5 | `complete_daily_review()` SQL line 58 | SQL |
| 6 | Activity pass threshold | 60% | `activity.dart:239`, `AppConstants.minimumPassScore` | Dart |
| 7 | Activity excellence threshold | 90% | `activity.dart:240`, `AppConstants.excellentScore` | Dart |
| 8 | Activity XP — perfect (100%) | 10 | `supabase_activity_repository.dart:249` | Dart |
| 9 | Activity XP — good (≥80%) | 7 | `supabase_activity_repository.dart:250` | Dart |
| 10 | Activity XP — pass (≥60%) | 5 | `supabase_activity_repository.dart:251` | Dart |
| 11 | Activity XP — participation (<60%) | 2 | `supabase_activity_repository.dart:252` | Dart |

### Bugfix

| # | Issue | Fix |
|---|-------|-----|
| 12 | Pity threshold mismatch: SQL=14, Dart=15 | Sync `AppConstants.pityThreshold` to 14 (SQL is authoritative) |

### Out of Scope
- Card rarity probabilities (server-only, game-designer level)
- Pity threshold (not important per user)
- SM-2 algorithm parameters (changing would corrupt existing learning data)
- Level XP formula (system invariant, must match server)
- League zone sizes (complex dual-location dependency)

---

## New system_settings Keys

All new keys will be inserted via a single migration. Defaults match current hardcoded values for zero-change deployment.

### Category: `game`

| Key | Default | Type | Description | sort_order |
|-----|---------|------|-------------|------------|
| `pack_cost` | 100 | int | Card pack price in coins | 1 |

### Category: `xp_reading`

These go under the existing `xp_reading` category alongside `xp_chapter_complete`, `xp_book_complete`, `xp_quiz_pass`.

| Key | Default | Type | Description | group_label | sort_order |
|-----|---------|------|-------------|-------------|------------|
| `xp_activity_result_perfect` | 10 | int | XP for 100% score on inline activity | Activity Result XP | 20 |
| `xp_activity_result_good` | 7 | int | XP for ≥80% score on inline activity | Activity Result XP | 21 |
| `xp_activity_result_pass` | 5 | int | XP for ≥60% score on inline activity | Activity Result XP | 22 |
| `xp_activity_result_participation` | 2 | int | XP for <60% score on inline activity | Activity Result XP | 23 |

### Category: `xp_vocab`

Goes under existing `xp_vocab` category alongside `xp_vocab_multiple_choice`, `xp_vocab_session_bonus`, etc.

| Key | Default | Type | Description | group_label | sort_order |
|-----|---------|------|-------------|-------------|------------|
| `xp_daily_review_correct` | 5 | int | XP per correct answer in daily review | Daily Review | 20 |

### Category: `progression`

Goes under existing `progression` category.

| Key | Default | Type | Description | group_label | sort_order |
|-----|---------|------|-------------|-------------|------------|
| `activity_pass_threshold` | 60 | int | Minimum % to pass an inline activity | Activity Thresholds | 10 |
| `activity_excellence_threshold` | 90 | int | Minimum % for excellent on inline activity | Activity Thresholds | 11 |
| `star_rating_3` | 90 | int | Minimum accuracy % for 3 stars on word list | Star Rating | 20 |
| `star_rating_2` | 70 | int | Minimum accuracy % for 2 stars on word list | Star Rating | 21 |
| `star_rating_1` | 50 | int | Minimum accuracy % for 1 star on word list | Star Rating | 22 |

**Total: 11 new keys** across 4 categories.

---

## Changes Per Layer

### 1. Database Migration

**Single migration** inserts all 11 new system_settings keys with `ON CONFLICT DO NOTHING`.

**Additionally:** Updates `complete_daily_review()` RPC to read `xp_daily_review_correct` from system_settings (same pattern as existing `xp_vocab_session_bonus` reads in the same function).

Current hardcoded line:
```sql
v_base_xp := p_correct_count * 5;
```

Updated:
```sql
SELECT COALESCE(
  (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_daily_review_correct'),
  5
) INTO v_xp_per_correct;

v_base_xp := p_correct_count * v_xp_per_correct;
```

### 2. Shared Package — No Changes

No new enums or constants needed. The existing `DbTables.systemSettings` constant is already used.

### 3. Domain Layer — `SystemSettings` Entity

Add 11 new fields with defaults matching current hardcoded values:

```dart
// Card economy
final int packCost;                       // default: 100

// Activity result XP tiers
final int xpActivityResultPerfect;        // default: 10
final int xpActivityResultGood;           // default: 7
final int xpActivityResultPass;           // default: 5
final int xpActivityResultParticipation;  // default: 2

// Daily review
final int xpDailyReviewCorrect;           // default: 5

// Activity thresholds
final int activityPassThreshold;          // default: 60
final int activityExcellenceThreshold;    // default: 90

// Star rating thresholds
final int starRating3;                    // default: 90
final int starRating2;                    // default: 70
final int starRating1;                    // default: 50
```

Also add these to the `props` list for Equatable.

### 4. Data Layer — `SystemSettingsModel`

Add parsing for each new key in `fromMap()`:

```dart
packCost: _toInt(m['pack_cost'], _d.packCost),
xpActivityResultPerfect: _toInt(m['xp_activity_result_perfect'], _d.xpActivityResultPerfect),
xpActivityResultGood: _toInt(m['xp_activity_result_good'], _d.xpActivityResultGood),
xpActivityResultPass: _toInt(m['xp_activity_result_pass'], _d.xpActivityResultPass),
xpActivityResultParticipation: _toInt(m['xp_activity_result_participation'], _d.xpActivityResultParticipation),
xpDailyReviewCorrect: _toInt(m['xp_daily_review_correct'], _d.xpDailyReviewCorrect),
activityPassThreshold: _toInt(m['activity_pass_threshold'], _d.activityPassThreshold),
activityExcellenceThreshold: _toInt(m['activity_excellence_threshold'], _d.activityExcellenceThreshold),
starRating3: _toInt(m['star_rating_3'], _d.starRating3),
starRating2: _toInt(m['star_rating_2'], _d.starRating2),
starRating1: _toInt(m['star_rating_1'], _d.starRating1),
```

Also add corresponding fields, constructor params, and `toEntity()` mapping.

### 5. Presentation Layer — Replace Hardcoded References

#### 5a. Card Pack Cost

**`lib/domain/usecases/card/buy_pack_usecase.dart`**
- Remove `this.cost = 100` default from `BuyPackParams`
- Make `cost` required (callers must provide)

**`lib/presentation/providers/card_provider.dart`** (where `BuyPackParams` is constructed)
- Read `settings.packCost` from `systemSettingsProvider`
- Pass to `BuyPackParams(cost: settings.packCost)`

**`lib/presentation/screens/cards/pack_opening_screen.dart`**
- Replace hardcoded `100` with `settings.packCost` from provider
- For coin balance check and display

**`lib/core/constants/app_constants.dart`**
- Remove `packCost = 100` (now in SystemSettings)
- Fix `pityThreshold` from 15 → 14 (bugfix)

#### 5b. Activity Result XP Tiers

**`lib/data/repositories/supabase/supabase_activity_repository.dart`**

The `_calculateXP()` method is called internally by the repository before awarding XP via RPC. To give it access to settings, add `SystemSettings` as a constructor parameter to `SupabaseActivityRepository`. The repository provider in `repository_providers.dart` already creates the instance — it can pass current settings.

Updated `_calculateXP`:
```dart
int _calculateXP(double score, double maxScore) {
  if (maxScore == 0) return 0;
  final percentage = (score / maxScore) * 100;
  if (percentage >= 100) return _settings.xpActivityResultPerfect;
  if (percentage >= 80) return _settings.xpActivityResultGood;
  if (percentage >= 60) return _settings.xpActivityResultPass;
  return _settings.xpActivityResultParticipation;
}
```

**`lib/presentation/providers/repository_providers.dart`**
- Pass `systemSettingsProvider` value to repository constructor

#### 5c. Activity Pass/Excellence Thresholds

**`lib/domain/entities/activity.dart`**
- Remove `isPassing` and `isExcellent` entity getters (they couple business rules to the entity)
- Find all UI call sites and replace with inline comparison against `settings.activityPassThreshold` / `settings.activityExcellenceThreshold`

**`lib/core/constants/app_constants.dart`**
- Remove `minimumPassScore` and `excellentScore` (moved to SystemSettings)

#### 5d. Star Rating Thresholds

**`lib/domain/entities/word_list.dart`**

Add a parameterized method alongside the existing getter:
```dart
int starCountWith({int star3 = 90, int star2 = 70, int star1 = 50}) {
  if (bestAccuracy == null) return 0;
  if (bestAccuracy! >= star3) return 3;
  if (bestAccuracy! >= star2) return 2;
  if (bestAccuracy! >= star1) return 1;
  return 0;
}
```

The existing `starCount` getter delegates to `starCountWith()` with defaults. UI code that has settings access calls `starCountWith(star3: settings.starRating3, ...)` instead.

### 6. Admin Panel — Settings Screen

The existing `SettingsScreen` already renders all keys from the given categories automatically (it reads from DB and builds UI dynamically). The new keys will appear automatically because:

1. They're inserted into `system_settings` with the right `category` values
2. The `settingsProvider` fetches all rows and groups by category
3. The `_buildSettingRow` method auto-detects type (boolean → switch, number → text field, string → text field)
4. The `sort_order` and `group_label` columns control ordering and grouping

**What we need to add:**

The router passes `categories: ['xp_reading', 'xp_vocab', 'progression', 'app']` to `SettingsScreen`. The new `game` category is NOT in this list, so `pack_cost` won't show up.

**Fix:** Add `'game'` to the categories list in `router.dart:324`, and add the corresponding label/icon/color in `settings_screen.dart`:

```dart
static const categoryLabels = {
  'xp_reading': 'Reading XP',
  'xp_vocab': 'Vocab Session XP',
  'progression': 'Seviye ve İlerleme',
  'game': 'Oyun Ekonomisi',
  'app': 'Uygulama Yapılandırması',
};

static const categoryIcons = {
  ...
  'game': Icons.casino,
};

static const categoryColors = {
  ...
  'game': Color(0xFFEC4899),  // pink
};
```

All 11 settings will then be visible and editable in the admin panel:
- **Reading XP** section: 4 activity result XP tiers (under "Activity Result XP" sub-group)
- **Vocab Session XP** section: 1 daily review XP per correct (under "Daily Review" sub-group)
- **Seviye ve İlerleme** section: 2 activity thresholds + 3 star rating thresholds (under separate sub-groups)
- **Oyun Ekonomisi** section: pack cost

### 7. Bugfix — Pity Threshold Mismatch

**`lib/core/constants/app_constants.dart:38`**
```dart
// Before
static const pityThreshold = 15;

// After
static const pityThreshold = 14;
```

SQL RPC uses `>= 14`, so the client display should also say 14. This only affects client-side display/tooltip if any — the actual pity logic runs server-side.

---

## File Change Summary

| File | Action | What Changes |
|------|--------|-------------|
| `supabase/migrations/20260329000001_configurable_settings.sql` | CREATE | Insert 11 new keys + update `complete_daily_review` RPC |
| `lib/domain/entities/system_settings.dart` | EDIT | Add 11 fields with defaults |
| `lib/data/models/settings/system_settings_model.dart` | EDIT | Add 11 field parsing + toEntity mapping |
| `lib/core/constants/app_constants.dart` | EDIT | Remove `packCost`, `minimumPassScore`, `excellentScore`; fix `pityThreshold` to 14 |
| `lib/domain/usecases/card/buy_pack_usecase.dart` | EDIT | Remove default `cost = 100` |
| `lib/presentation/providers/card_provider.dart` | EDIT | Read `settings.packCost` and pass to `BuyPackParams` |
| `lib/presentation/screens/cards/pack_opening_screen.dart` | EDIT | Replace hardcoded 100 with settings |
| `lib/data/repositories/supabase/supabase_activity_repository.dart` | EDIT | `_calculateXP` reads settings-based XP tiers |
| `lib/presentation/providers/repository_providers.dart` | EDIT | Pass settings to activity repository |
| `lib/domain/entities/activity.dart` | EDIT | Remove `isPassing`/`isExcellent` getters (move to UI with settings) |
| `lib/domain/entities/word_list.dart` | EDIT | Add `starCountWith()` parameterized method |
| `owlio_admin/lib/core/router.dart` | EDIT | Add `'game'` to categories list |
| `owlio_admin/lib/features/settings/screens/settings_screen.dart` | EDIT | Add `game` category label/icon/color |
| UI files using `isPassing`/`isExcellent`/`starCount` | EDIT | Pass settings thresholds |

**Estimated: ~14 files, 1 migration**

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Changing activity XP calculation breaks balance | Defaults match current values exactly — zero-change deployment |
| Entity getters removed break callers | Search all `isPassing`/`isExcellent`/`starCount` usages before removing |
| SQL migration fails | `ON CONFLICT DO NOTHING` for inserts; RPC uses COALESCE with fallback default |
| Settings not loaded yet when needed | `SystemSettings.defaults()` fallback already exists throughout codebase |
| Admin changes wrong value (e.g., star_rating_1 > star_rating_2) | No validation needed for MVP — admin is trusted; can add validation later |
