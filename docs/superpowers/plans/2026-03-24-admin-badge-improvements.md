# Admin Badge Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix admin panel badge management gaps, remove dead `dailyLogin` condition type, add per-badge earned-by stats, and insert 3 new streak badges aligned with milestone system.

**Architecture:** Changes span 3 projects (shared package, main app, admin panel) plus a DB migration. The shared enum change drives compile fixes in both apps. Admin panel gets a new helper file and UI additions. Migration handles DB constraint update and new badge data.

**Tech Stack:** Flutter/Riverpod (admin panel + main app), Dart (shared package), PostgreSQL (Supabase migration)

**Spec:** `docs/superpowers/specs/2026-03-24-admin-badge-improvements-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260325000003_admin_badge_improvements.sql` | CHECK constraint update + 3 new streak badge INSERTs |
| `owlio_admin/lib/core/utils/badge_helpers.dart` | Shared `getConditionLabel()` and `getConditionHelper()` functions |

### Modified Files
| File | Change |
|------|--------|
| `packages/owlio_shared/lib/src/enums/badge_condition_type.dart` | Remove `dailyLogin` enum value |
| `lib/data/models/badge/badge_model.dart` | Replace `parseConditionType`/`conditionTypeToString` with shared enum methods |
| `lib/data/repositories/supabase/supabase_badge_repository.dart` | Remove `dailyLogin` switch case |
| `test/fixtures/badge_fixtures.dart` | Fix `daily_login` → `xp_total` in test fixture |
| `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart` | Add `levelCompleted` to dropdown, fix categories, add earned-by section, use helper |
| `owlio_admin/lib/features/badges/screens/badge_list_screen.dart` | Use shared helper |
| `owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart` | Use shared helper |

---

## Task 1: DB Migration — CHECK Constraint + New Streak Badges

**Files:**
- Create: `supabase/migrations/20260325000003_admin_badge_improvements.sql`

- [ ] **Step 1: Verify CHECK constraint name on remote DB**

Run:
```bash
supabase db execute --sql "SELECT conname FROM pg_constraint WHERE conrelid = 'badges'::regclass AND contype = 'c';"
```
Expected: `badges_condition_type_check` (or similar). Use the actual name in the migration.

- [ ] **Step 2: Create migration file**

Create `supabase/migrations/20260325000003_admin_badge_improvements.sql`:

```sql
-- =============================================
-- Admin Badge Improvements
-- 1. Remove 'daily_login' from condition_type CHECK
-- 2. Insert 3 new streak badges (14, 60, 100 days)
-- =============================================

-- 1. Update CHECK constraint (remove daily_login)
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN (
    'xp_total', 'streak_days', 'books_completed',
    'vocabulary_learned', 'perfect_scores', 'level_completed'
  ));

-- 2. New streak badges aligned with milestones
INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, xp_reward)
VALUES
  ('Streak Warrior', 'streak-warrior', 'Maintain a 14-day reading streak', '🔥', 'streak', 'streak_days', 14, 150),
  ('Streak Hero', 'streak-hero', 'Maintain a 60-day reading streak', '🔥', 'streak', 'streak_days', 60, 750),
  ('Streak Immortal', 'streak-immortal', 'Maintain a 100-day reading streak', '🔥', 'streak', 'streak_days', 100, 1500)
ON CONFLICT (slug) DO NOTHING;
```

- [ ] **Step 3: Dry-run migration**

Run:
```bash
supabase db push --dry-run
```
Expected: Shows the new migration will be applied, no errors.

- [ ] **Step 4: Push migration**

Run:
```bash
supabase db push
```
Expected: Migration applied successfully.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260325000003_admin_badge_improvements.sql
git commit -m "feat(db): remove daily_login constraint, add 3 streak badges"
```

---

## Task 2: Remove `dailyLogin` from Shared Enum

**Files:**
- Modify: `packages/owlio_shared/lib/src/enums/badge_condition_type.dart`

- [ ] **Step 1: Remove `dailyLogin` enum value**

Edit `packages/owlio_shared/lib/src/enums/badge_condition_type.dart`. Remove line 9:

```dart
  dailyLogin('daily_login');
```

Change `levelCompleted` line to end with semicolon (it becomes the last value):

```dart
  levelCompleted('level_completed');
```

- [ ] **Step 2: Verify shared package compiles**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio/packages/owlio_shared && dart analyze lib/
```
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/lib/src/enums/badge_condition_type.dart
git commit -m "refactor(shared): remove unused dailyLogin badge condition type"
```

---

## Task 3: Main App `dailyLogin` Cleanup

**Files:**
- Modify: `lib/data/models/badge/badge_model.dart:95-133`
- Modify: `lib/data/repositories/supabase/supabase_badge_repository.dart:205-207`
- Modify: `test/fixtures/badge_fixtures.dart:85`

- [ ] **Step 1: Replace `parseConditionType` and `conditionTypeToString` in BadgeModel**

In `lib/data/models/badge/badge_model.dart`, replace the two static methods (lines 95-133) with calls to the shared enum:

```dart
  static BadgeConditionType parseConditionType(String type) {
    return BadgeConditionType.fromDbValue(type);
  }

  static String conditionTypeToString(BadgeConditionType type) {
    return type.dbValue;
  }
```

- [ ] **Step 2: Remove `dailyLogin` case from badge repository**

In `lib/data/repositories/supabase/supabase_badge_repository.dart`, remove lines 205-207:

```dart
          case BadgeConditionType.dailyLogin:
            // Daily login tracked via streak - user is active now
            canEarn = currentStreak >= badge.conditionValue;
```

- [ ] **Step 3: Fix test fixture**

In `test/fixtures/badge_fixtures.dart`, change line 85 from:

```dart
        'condition_type': 'daily_login',
```

to:

```dart
        'condition_type': 'xp_total',
```

- [ ] **Step 4: Verify main app compiles**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```
Expected: No issues.

- [ ] **Step 5: Run tests**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio && flutter test test/unit/data/models/badge/
```
Expected: All pass.

- [ ] **Step 6: Verify no dailyLogin references remain**

Run:
```bash
grep -r "dailyLogin\|daily_login" packages/owlio_shared/lib/ owlio_admin/lib/ lib/ test/
```
Expected: Zero matches.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models/badge/badge_model.dart lib/data/repositories/supabase/supabase_badge_repository.dart test/fixtures/badge_fixtures.dart
git commit -m "refactor: remove dailyLogin references from main app"
```

---

## Task 4: Create Shared Badge Helper (Admin Panel)

**Files:**
- Create: `owlio_admin/lib/core/utils/badge_helpers.dart`

- [ ] **Step 1: Create utils directory and helper file**

Create `owlio_admin/lib/core/utils/badge_helpers.dart`:

```dart
/// Shared badge condition helpers for admin panel.
/// Covers all 6 condition types: xp_total, streak_days, books_completed,
/// vocabulary_learned, perfect_scores, level_completed.

/// Short label for badge cards (e.g., "7 gün", "500 XP").
String getConditionLabel(String type, int value) {
  return switch (type) {
    'xp_total' => '$value XP',
    'streak_days' => '$value gün',
    'books_completed' => '$value kitap',
    'vocabulary_learned' => '$value kelime',
    'perfect_scores' => '$value tam puan',
    'level_completed' => '$value seviye',
    _ => '$type: $value',
  };
}

/// Descriptive helper text for the edit form (e.g., "Ardışık aktif gün sayısı").
String getConditionHelper(String type) {
  return switch (type) {
    'xp_total' => 'Kullanıcının kazanması gereken toplam XP',
    'streak_days' => 'Ardışık aktif gün sayısı',
    'books_completed' => 'Tamamlanması gereken kitap sayısı',
    'vocabulary_learned' => 'Öğrenilmesi gereken kelime sayısı',
    'perfect_scores' => 'Etkinliklerde tam puan sayısı',
    'level_completed' => 'Ulaşılması gereken seviye',
    _ => '',
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add owlio_admin/lib/core/utils/badge_helpers.dart
git commit -m "feat(admin): add shared badge condition helpers"
```

---

## Task 5: Wire Shared Helper into Admin Panel Screens

**Files:**
- Modify: `owlio_admin/lib/features/badges/screens/badge_list_screen.dart:203-217`
- Modify: `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart:41-49,522-537`
- Modify: `owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart:199-208`

- [ ] **Step 1: Update `badge_list_screen.dart`**

Add import at top:
```dart
import '../../../core/utils/badge_helpers.dart';
```

Replace the `_getConditionLabel` method in `_BadgeCard` (lines 203-217). Change the call site at line 187 from:
```dart
label: _getConditionLabel(conditionType, conditionValue),
```
to:
```dart
label: getConditionLabel(conditionType, conditionValue),
```

Remove the entire `_getConditionLabel` method (lines 203-217).

- [ ] **Step 2: Update `badge_edit_screen.dart`**

Add import at top:
```dart
import '../../../core/utils/badge_helpers.dart';
```

**Update `_conditionTypes` list** (lines 41-47) — add `levelCompleted`:
```dart
  static final _conditionTypes = [
    (BadgeConditionType.xpTotal.dbValue, 'Toplam Kazanılan XP'),
    (BadgeConditionType.streakDays.dbValue, 'Ardışık Aktif Gün'),
    (BadgeConditionType.booksCompleted.dbValue, 'Tamamlanan Kitaplar'),
    (BadgeConditionType.vocabularyLearned.dbValue, 'Öğrenilen Kelimeler'),
    (BadgeConditionType.perfectScores.dbValue, 'Tam Puan Etkinlik Skorları'),
    (BadgeConditionType.levelCompleted.dbValue, 'Ulaşılan Seviye'),
  ];
```

**Update `_categories` list** (line 49):
```dart
  static const _categories = [
    'achievement', 'streak', 'reading', 'vocabulary',
    'activities', 'xp', 'level', 'special',
  ];
```

**Replace `_getConditionHelper`** call at line 383 from:
```dart
helperText: _getConditionHelper(_conditionType),
```
to:
```dart
helperText: getConditionHelper(_conditionType),
```

**Remove** the entire `_getConditionHelper` method (lines 522-537).

- [ ] **Step 3: Update `collectibles_screen.dart`**

Add import at top:
```dart
import '../../../core/utils/badge_helpers.dart';
```

Replace the `_conditionLabel` call in `_CompactBadgeCard` (line 186) from:
```dart
label: _conditionLabel(conditionType, conditionValue),
```
to:
```dart
label: getConditionLabel(conditionType, conditionValue),
```

Remove the entire `_conditionLabel` static method (lines 199-208).

- [ ] **Step 4: Verify admin panel compiles**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/
```
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add owlio_admin/lib/features/badges/screens/badge_list_screen.dart owlio_admin/lib/features/badges/screens/badge_edit_screen.dart owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart
git commit -m "refactor(admin): use shared badge helpers, add missing condition types and categories"
```

---

## Task 6: Per-Badge Earned-By Statistics

**Files:**
- Modify: `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart`

- [ ] **Step 1: Add `badgeEarnedByProvider`**

In `badge_edit_screen.dart`, add below the existing `badgeDetailProvider` (after line 21):

```dart
/// Provider for loading students who earned a specific badge
final badgeEarnedByProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, badgeId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.userBadges)
      .select('earned_at, profiles(id, first_name, last_name)')
      .eq('badge_id', badgeId)
      .order('earned_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});
```

- [ ] **Step 2: Add earned-by section to preview panel**

In the `build` method's preview `Column` (inside the `Expanded(flex: 1, ...)` widget, after the existing preview `Card` at ~line 512), add:

```dart
if (!isNewBadge) ...[
  const SizedBox(height: 24),
  const Divider(),
  const SizedBox(height: 16),
  _EarnedBySection(badgeId: widget.badgeId!),
],
```

- [ ] **Step 3: Create `_EarnedBySection` widget**

Add at the bottom of the file (before the closing of the file):

```dart
class _EarnedBySection extends ConsumerWidget {
  const _EarnedBySection({required this.badgeId});

  final String badgeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedByAsync = ref.watch(badgeEarnedByProvider(badgeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        earnedByAsync.when(
          data: (students) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kazanan Öğrenciler (${students.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (students.isEmpty)
                  Text(
                    'Henüz kimse kazanmadı',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ...students.map((entry) {
                    final profile =
                        entry['profiles'] as Map<String, dynamic>? ?? {};
                    final firstName = profile['first_name'] as String? ?? '';
                    final lastName = profile['last_name'] as String? ?? '';
                    final name = '$firstName $lastName'.trim();
                    final earnedAt = entry['earned_at'] as String? ?? '';
                    final date = earnedAt.isNotEmpty
                        ? DateTime.tryParse(earnedAt)
                        : null;
                    final dateStr = date != null
                        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
                        : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade50,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'Bilinmeyen',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, _) => Text(
            'Hata: $error',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify admin panel compiles**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/
```
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add owlio_admin/lib/features/badges/screens/badge_edit_screen.dart
git commit -m "feat(admin): add per-badge earned-by statistics section"
```

---

## Task 7: Final Verification

- [ ] **Step 1: Verify main app compiles**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```
Expected: No issues.

- [ ] **Step 2: Verify admin panel compiles**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/
```
Expected: No issues.

- [ ] **Step 3: Run main app tests**

Run:
```bash
cd /Users/wonderelt/Desktop/Owlio && flutter test
```
Expected: All pass.

- [ ] **Step 4: Verify no dailyLogin references remain**

Run:
```bash
grep -r "dailyLogin\|daily_login" packages/owlio_shared/lib/ owlio_admin/lib/ lib/ test/
```
Expected: Zero matches.

- [ ] **Step 5: Verify new badges exist in remote DB**

Run:
```bash
supabase db execute --sql "SELECT name, slug, condition_value, xp_reward FROM badges WHERE slug LIKE 'streak-%' ORDER BY condition_value;"
```
Expected: 6 streak badges (3, 7, 14, 30, 60, 100 days).
