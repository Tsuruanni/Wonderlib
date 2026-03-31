# Configurable Settings Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move 11 hardcoded business-logic values (card pack cost, activity XP tiers, daily review XP, activity thresholds, star rating thresholds) to admin-configurable `system_settings`, and fix a pity threshold mismatch bug.

**Architecture:** New system_settings rows consumed via existing `SystemSettings` entity → `SystemSettingsModel` pipeline. SQL RPCs updated to read from settings with COALESCE fallbacks. Admin panel auto-renders new settings via existing dynamic `SettingsScreen`.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL RPCs), owlio_admin

**Spec:** `docs/superpowers/specs/2026-03-28-configurable-settings-migration-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `supabase/migrations/20260329000001_configurable_settings.sql` | CREATE | Insert 11 keys + update `complete_daily_review` RPC |
| `lib/domain/entities/system_settings.dart` | EDIT | Add 11 fields with defaults |
| `lib/data/models/settings/system_settings_model.dart` | EDIT | Add 11 field parsing, constructor, toEntity |
| `lib/core/constants/app_constants.dart` | EDIT | Remove 3 constants, fix pityThreshold |
| `lib/domain/usecases/card/buy_pack_usecase.dart` | EDIT | Make cost required |
| `lib/presentation/providers/card_provider.dart` | EDIT | Read packCost from settings |
| `lib/presentation/screens/cards/pack_opening_screen.dart` | EDIT | Replace hardcoded 100 with settings |
| `lib/data/repositories/supabase/supabase_activity_repository.dart` | EDIT | Accept settings, use XP tiers |
| `lib/presentation/providers/repository_providers.dart` | EDIT | Pass settings to activity repo |
| `lib/domain/entities/activity.dart` | EDIT | Remove isPassing/isExcellent getters |
| `lib/domain/entities/word_list.dart` | EDIT | Add starCountWith() method |
| `lib/presentation/providers/vocabulary_provider.dart` | EDIT | Use starCountWith with settings |
| `lib/presentation/widgets/vocabulary/path_node.dart` | EDIT | Use starCountWith with settings |
| `lib/presentation/screens/vocabulary/word_list_detail_screen.dart` | EDIT | Use starCountWith with settings |
| `lib/presentation/screens/teacher/student_detail_screen.dart` | EDIT | Use starCountWith with settings |
| `owlio_admin/lib/core/router.dart` | EDIT | Add 'game' to categories |
| `owlio_admin/lib/features/settings/screens/settings_screen.dart` | EDIT | Add game category label/icon/color |

---

### Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/20260329000001_configurable_settings.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Add configurable settings for: pack cost, activity XP tiers,
-- daily review XP, activity thresholds, star rating thresholds.
-- Defaults match current hardcoded values for zero-change deployment.

-- Category: game
INSERT INTO system_settings (key, value, category, description, sort_order) VALUES
  ('pack_cost', '"100"', 'game', 'Card pack price in coins', 1)
ON CONFLICT (key) DO NOTHING;

-- Category: xp_reading — Activity Result XP tiers
INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  ('xp_activity_result_perfect', '"10"', 'xp_reading', 'XP for 100% score on inline activity', 'Activity Result XP', 20),
  ('xp_activity_result_good', '"7"', 'xp_reading', 'XP for ≥80% score on inline activity', 'Activity Result XP', 21),
  ('xp_activity_result_pass', '"5"', 'xp_reading', 'XP for ≥60% score on inline activity', 'Activity Result XP', 22),
  ('xp_activity_result_participation', '"2"', 'xp_reading', 'XP for <60% score on inline activity', 'Activity Result XP', 23)
ON CONFLICT (key) DO NOTHING;

-- Category: xp_vocab — Daily Review
INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  ('xp_daily_review_correct', '"5"', 'xp_vocab', 'XP per correct answer in daily review', 'Daily Review', 20)
ON CONFLICT (key) DO NOTHING;

-- Category: progression — Activity Thresholds + Star Rating
INSERT INTO system_settings (key, value, category, description, group_label, sort_order) VALUES
  ('activity_pass_threshold', '"60"', 'progression', 'Minimum % to pass an inline activity', 'Activity Thresholds', 10),
  ('activity_excellence_threshold', '"90"', 'progression', 'Minimum % for excellent on inline activity', 'Activity Thresholds', 11),
  ('star_rating_3', '"90"', 'progression', 'Minimum accuracy % for 3 stars on word list', 'Star Rating', 20),
  ('star_rating_2', '"70"', 'progression', 'Minimum accuracy % for 2 stars on word list', 'Star Rating', 21),
  ('star_rating_1', '"50"', 'progression', 'Minimum accuracy % for 1 star on word list', 'Star Rating', 22)
ON CONFLICT (key) DO NOTHING;

-- Update complete_daily_review RPC to read xp_daily_review_correct from settings
CREATE OR REPLACE FUNCTION complete_daily_review(
    p_user_id UUID,
    p_words_reviewed INTEGER,
    p_correct_count INTEGER,
    p_incorrect_count INTEGER
)
RETURNS TABLE(
    session_id UUID,
    total_xp INTEGER,
    is_new_session BOOLEAN,
    is_perfect BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_session daily_review_sessions%ROWTYPE;
    v_xp_per_correct INTEGER;
    v_base_xp INTEGER;
    v_session_bonus INTEGER;
    v_perfect_bonus INTEGER;
    v_total_xp INTEGER;
    v_is_perfect BOOLEAN;
    v_session_id UUID;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Read XP values from system_settings (with fallback defaults)
    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_daily_review_correct'),
      5
    ) INTO v_xp_per_correct;

    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_session_bonus'),
      10
    ) INTO v_session_bonus;

    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_perfect_bonus'),
      20
    ) INTO v_perfect_bonus;

    -- Prevent duplicate session on same day
    SELECT * INTO v_existing_session
    FROM daily_review_sessions
    WHERE user_id = p_user_id AND session_date = app_current_date();

    IF v_existing_session.id IS NOT NULL THEN
        RETURN QUERY SELECT
            v_existing_session.id,
            0::INTEGER,
            FALSE,
            v_existing_session.is_perfect;
        RETURN;
    END IF;

    -- Calculate XP using configurable per-correct value
    v_base_xp := p_correct_count * v_xp_per_correct;
    v_is_perfect := (p_correct_count = p_words_reviewed AND p_incorrect_count = 0 AND p_words_reviewed > 0);

    v_total_xp := v_base_xp + v_session_bonus;
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    INSERT INTO daily_review_sessions (
        user_id, session_date, words_reviewed, correct_count,
        incorrect_count, xp_earned, is_perfect
    ) VALUES (
        p_user_id, app_current_date(), p_words_reviewed, p_correct_count,
        p_incorrect_count, v_total_xp, v_is_perfect
    ) RETURNING id INTO v_session_id;

    PERFORM award_xp_transaction(
        p_user_id, v_total_xp, 'daily_review',
        v_session_id, 'Daily vocabulary review completed'
    );

    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_total_xp, TRUE, v_is_perfect;
END;
$$;
```

- [ ] **Step 2: Dry-run migration**

Run: `supabase db push --dry-run`
Expected: Shows the INSERT and CREATE OR REPLACE statements, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`

- [ ] **Step 4: Commit**

```
git add supabase/migrations/20260329000001_configurable_settings.sql
git commit -m "feat: add 11 configurable settings + update daily review RPC"
```

---

### Task 2: SystemSettings Entity + Model

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add 11 fields to SystemSettings entity**

In `lib/domain/entities/system_settings.dart`, add to the constructor (after the `// Debug` section):

```dart
    // Card economy
    this.packCost = 100,
    // Activity result XP tiers
    this.xpActivityResultPerfect = 10,
    this.xpActivityResultGood = 7,
    this.xpActivityResultPass = 5,
    this.xpActivityResultParticipation = 2,
    // Daily review
    this.xpDailyReviewCorrect = 5,
    // Activity thresholds
    this.activityPassThreshold = 60,
    this.activityExcellenceThreshold = 90,
    // Star rating thresholds
    this.starRating3 = 90,
    this.starRating2 = 70,
    this.starRating1 = 50,
```

Add the corresponding field declarations (after `final int debugDateOffset;`):

```dart
  // Card economy
  final int packCost;

  // Activity result XP tiers
  final int xpActivityResultPerfect;
  final int xpActivityResultGood;
  final int xpActivityResultPass;
  final int xpActivityResultParticipation;

  // Daily review
  final int xpDailyReviewCorrect;

  // Activity thresholds
  final int activityPassThreshold;
  final int activityExcellenceThreshold;

  // Star rating thresholds
  final int starRating3;
  final int starRating2;
  final int starRating1;
```

Add all 11 to the `props` list:

```dart
        packCost,
        xpActivityResultPerfect,
        xpActivityResultGood,
        xpActivityResultPass,
        xpActivityResultParticipation,
        xpDailyReviewCorrect,
        activityPassThreshold,
        activityExcellenceThreshold,
        starRating3,
        starRating2,
        starRating1,
```

- [ ] **Step 2: Add 11 fields to SystemSettingsModel**

In `lib/data/models/settings/system_settings_model.dart`:

Add to the constructor params (after `required this.debugDateOffset`):

```dart
    required this.packCost,
    required this.xpActivityResultPerfect,
    required this.xpActivityResultGood,
    required this.xpActivityResultPass,
    required this.xpActivityResultParticipation,
    required this.xpDailyReviewCorrect,
    required this.activityPassThreshold,
    required this.activityExcellenceThreshold,
    required this.starRating3,
    required this.starRating2,
    required this.starRating1,
```

Add field declarations (after `final int debugDateOffset;`):

```dart
  final int packCost;
  final int xpActivityResultPerfect;
  final int xpActivityResultGood;
  final int xpActivityResultPass;
  final int xpActivityResultParticipation;
  final int xpDailyReviewCorrect;
  final int activityPassThreshold;
  final int activityExcellenceThreshold;
  final int starRating3;
  final int starRating2;
  final int starRating1;
```

Add parsing in `fromMap()` (after the `debugDateOffset` line):

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

Add to `toEntity()` (after `debugDateOffset: debugDateOffset`):

```dart
        packCost: packCost,
        xpActivityResultPerfect: xpActivityResultPerfect,
        xpActivityResultGood: xpActivityResultGood,
        xpActivityResultPass: xpActivityResultPass,
        xpActivityResultParticipation: xpActivityResultParticipation,
        xpDailyReviewCorrect: xpDailyReviewCorrect,
        activityPassThreshold: activityPassThreshold,
        activityExcellenceThreshold: activityExcellenceThreshold,
        starRating3: starRating3,
        starRating2: starRating2,
        starRating1: starRating1,
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add 11 configurable settings fields to SystemSettings entity + model"
```

---

### Task 3: Card Pack Cost — Replace Hardcoded 100

**Files:**
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/domain/usecases/card/buy_pack_usecase.dart`
- Modify: `lib/presentation/providers/card_provider.dart`
- Modify: `lib/presentation/screens/cards/pack_opening_screen.dart`

- [ ] **Step 1: Clean up AppConstants**

In `lib/core/constants/app_constants.dart`:

Remove these 3 lines:
```dart
  static const packCost = 100;
```
```dart
  static const minimumPassScore = 60.0;
  static const excellentScore = 90.0;
```

Fix pity threshold bug (line 38):
```dart
  // Before:
  static const pityThreshold = 15;
  // After:
  static const pityThreshold = 14;
```

- [ ] **Step 2: Make BuyPackParams.cost required**

In `lib/domain/usecases/card/buy_pack_usecase.dart`, change:
```dart
  // Before:
  const BuyPackParams({required this.userId, this.cost = 100, this.idempotencyKey});
  // After:
  const BuyPackParams({required this.userId, required this.cost, this.idempotencyKey});
```

- [ ] **Step 3: Read packCost from settings in card provider**

In `lib/presentation/providers/card_provider.dart`, the `buyPack` method (line 181):

```dart
  // Before:
  Future<void> buyPack({int cost = 100}) async {
  // After:
  Future<void> buyPack({required int cost}) async {
```

Then find the call site that invokes `buyPack()` in this file or screen and pass the settings value.

- [ ] **Step 4: Replace hardcoded 100 in pack_opening_screen.dart**

In `lib/presentation/screens/cards/pack_opening_screen.dart`:

The screen needs to read `systemSettingsProvider` to get `packCost`. Add a watch at the top of the build method and replace:

Line 208:
```dart
  // Before:
  final canAfford = coins >= 100;
  // After:
  final canAfford = coins >= packCost;
```

Line 384:
```dart
  // Before:
  label: 'BUY PACK  \u00a2100',
  // After:
  label: 'BUY PACK  \u00a2$packCost',
```

Where `packCost` comes from `ref.watch(systemSettingsProvider).valueOrNull?.packCost ?? 100`.

Also update the `buyPack` call to pass `cost: packCost`.

- [ ] **Step 5: Verify**

Run: `dart analyze lib/`
Expected: No errors (check for any remaining references to `AppConstants.packCost`, `AppConstants.minimumPassScore`, `AppConstants.excellentScore`).

- [ ] **Step 6: Commit**

```
git add lib/core/constants/app_constants.dart lib/domain/usecases/card/buy_pack_usecase.dart lib/presentation/providers/card_provider.dart lib/presentation/screens/cards/pack_opening_screen.dart
git commit -m "feat: make card pack cost configurable via system_settings

Also fixes pity threshold mismatch (client 15 → 14 to match SQL)"
```

---

### Task 4: Activity XP Tiers — Settings-Based Calculation

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_activity_repository.dart`
- Modify: `lib/presentation/providers/repository_providers.dart`

- [ ] **Step 1: Add SystemSettings dependency to SupabaseActivityRepository**

In `lib/data/repositories/supabase/supabase_activity_repository.dart`:

Add import:
```dart
import '../../../domain/entities/system_settings.dart';
```

Update constructor:
```dart
class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository({SupabaseClient? supabase, SystemSettings? settings})
      : _supabase = supabase ?? Supabase.instance.client,
        _settings = settings ?? const SystemSettings();

  final SupabaseClient _supabase;
  final SystemSettings _settings;
```

Update `_calculateXP`:
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

- [ ] **Step 2: Pass settings in repository_providers.dart**

In `lib/presentation/providers/repository_providers.dart`, update the activityRepositoryProvider:

```dart
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final settings = ref.watch(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
  final remoteRepo = SupabaseActivityRepository(settings: settings);
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedActivityRepository(
    remoteRepo: remoteRepo,
    cacheStore: cacheStore,
    networkInfo: networkInfo,
  );
});
```

Add the import for `systemSettingsProvider` if not already present:
```dart
import '../../domain/entities/system_settings.dart';
import '../providers/system_settings_provider.dart';
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/data/repositories/supabase/supabase_activity_repository.dart lib/presentation/providers/repository_providers.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add lib/data/repositories/supabase/supabase_activity_repository.dart lib/presentation/providers/repository_providers.dart
git commit -m "feat: activity XP tiers now read from system_settings"
```

---

### Task 5: Activity Thresholds — Remove Hardcoded Getters

**Files:**
- Modify: `lib/domain/entities/activity.dart`

- [ ] **Step 1: Remove isPassing and isExcellent getters**

In `lib/domain/entities/activity.dart`, remove these two lines (239-240):

```dart
  bool get isPassing => percentage >= 60;
  bool get isExcellent => percentage >= 90;
```

These getters are only defined on `ActivityResult` entity. Based on grep analysis:
- `isPassing` is NOT used anywhere in UI for `ActivityResult` (all UI `isPassing` references are for `BookQuizResult` — a different entity with `isPassing` as a DB field)
- `isExcellent` is NOT used anywhere in UI

So removing them should cause zero breakage. Verify with dart analyze.

- [ ] **Step 2: Verify**

Run: `dart analyze lib/`
Expected: No errors referencing `isPassing` or `isExcellent` on ActivityResult.

- [ ] **Step 3: Commit**

```
git add lib/domain/entities/activity.dart
git commit -m "fix: remove unused isPassing/isExcellent hardcoded getters from ActivityResult"
```

---

### Task 6: Star Rating — Parameterized Method

**Files:**
- Modify: `lib/domain/entities/word_list.dart`
- Modify: `lib/presentation/providers/vocabulary_provider.dart`
- Modify: `lib/presentation/widgets/vocabulary/path_node.dart`
- Modify: `lib/presentation/screens/vocabulary/word_list_detail_screen.dart`
- Modify: `lib/presentation/screens/teacher/student_detail_screen.dart`

- [ ] **Step 1: Add starCountWith() to UserWordListProgress entity**

In `lib/domain/entities/word_list.dart`, replace the `starCount` getter:

```dart
  /// Star rating with configurable thresholds
  int starCountWith({int star3 = 90, int star2 = 70, int star1 = 50}) {
    if (bestAccuracy == null) return 0;
    if (bestAccuracy! >= star3) return 3;
    if (bestAccuracy! >= star2) return 2;
    if (bestAccuracy! >= star1) return 1;
    return 0;
  }

  /// Star rating with default thresholds (convenience getter)
  int get starCount => starCountWith();
```

- [ ] **Step 2: Update vocabulary_provider.dart**

In `lib/presentation/providers/vocabulary_provider.dart` line 383, the `WordListWithProgress` class has:

```dart
  int get starCount => progress?.starCount ?? 0;
```

Add a parameterized version:

```dart
  int starCountWith({int star3 = 90, int star2 = 70, int star1 = 50}) =>
      progress?.starCountWith(star3: star3, star2: star2, star1: star1) ?? 0;
```

- [ ] **Step 3: Update path_node.dart**

In `lib/presentation/widgets/vocabulary/path_node.dart`, find all `.starCount` usages and replace with settings-aware calls. The widget needs to read `systemSettingsProvider`.

Lines 211, 216, 380, 473 reference `starCount`. These should use:
```dart
final settings = ref.watch(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
// Then use:
wlp.starCountWith(star3: settings.starRating3, star2: settings.starRating2, star1: settings.starRating1)
```

If the widget is not a ConsumerWidget, it needs to be converted, OR the settings can be passed from a parent.

- [ ] **Step 4: Update word_list_detail_screen.dart**

In `lib/presentation/screens/vocabulary/word_list_detail_screen.dart` lines 107-109, replace:
```dart
  // Before:
  if (progress != null && progress.starCount > 0) ...[
    _StarDisplay(stars: progress.starCount),
  // After:
  final stars = progress?.starCountWith(
    star3: settings.starRating3,
    star2: settings.starRating2,
    star1: settings.starRating1,
  ) ?? 0;
  if (stars > 0) ...[
    _StarDisplay(stars: stars),
```

Where `settings` comes from `ref.watch(systemSettingsProvider)`.

- [ ] **Step 5: Update student_detail_screen.dart**

In `lib/presentation/screens/teacher/student_detail_screen.dart` line 749, replace:
```dart
  // Before:
  i < progress.starCount
  // After:
  i < progress.starCountWith(star3: settings.starRating3, star2: settings.starRating2, star1: settings.starRating1)
```

- [ ] **Step 6: Verify**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 7: Commit**

```
git add lib/domain/entities/word_list.dart lib/presentation/providers/vocabulary_provider.dart lib/presentation/widgets/vocabulary/path_node.dart lib/presentation/screens/vocabulary/word_list_detail_screen.dart lib/presentation/screens/teacher/student_detail_screen.dart
git commit -m "feat: star rating thresholds now configurable via system_settings"
```

---

### Task 7: Admin Panel — Add Game Category

**Files:**
- Modify: `owlio_admin/lib/core/router.dart`
- Modify: `owlio_admin/lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Add 'game' to categories in router**

In `owlio_admin/lib/core/router.dart` line 324:

```dart
  // Before:
  categories: ['xp_reading', 'xp_vocab', 'progression', 'app'],
  // After:
  categories: ['xp_reading', 'xp_vocab', 'progression', 'game', 'app'],
```

- [ ] **Step 2: Add game category metadata in settings_screen.dart**

In `owlio_admin/lib/features/settings/screens/settings_screen.dart`:

Update `categoryLabels` (after 'progression' entry):
```dart
    'game': 'Oyun Ekonomisi',
```

Update `categoryIcons`:
```dart
    'game': Icons.casino,
```

Update `categoryColors`:
```dart
    'game': Color(0xFFEC4899),
```

- [ ] **Step 3: Verify**

Run: `dart analyze owlio_admin/lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```
git add owlio_admin/lib/core/router.dart owlio_admin/lib/features/settings/screens/settings_screen.dart
git commit -m "feat: add 'Oyun Ekonomisi' category to admin settings screen"
```

---

### Task 8: Final Verification

- [ ] **Step 1: Full dart analyze**

Run: `dart analyze lib/`
Expected: No new errors.

- [ ] **Step 2: Verify admin panel compiles**

Run: `dart analyze owlio_admin/lib/`
Expected: No new errors.

- [ ] **Step 3: Update feature spec**

Update `docs/specs/23-system-settings.md` to mention the 11 new keys and their categories. If a Known Issues section exists referencing hardcoded values, mark them as resolved.

- [ ] **Step 4: Final commit**

```
git add docs/
git commit -m "docs: update system settings spec with 11 new configurable keys"
```
