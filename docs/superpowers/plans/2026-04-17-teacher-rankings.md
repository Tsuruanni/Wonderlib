# Teacher Rankings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three ranking features to the teacher Reports section: league tier badges in Student Leaderboard, teacher-selectable class ranking + podium badges in Class Overview, and an own-school summary with platform-wide benchmark comparison.

**Architecture:** Surgical additions to existing `LeaderboardReportScreen` and `ClassOverviewReportScreen`. Three independent pieces — feature A needs one RPC extension + entity update; feature B is pure client-side sort on existing data; feature C needs two new RPCs plus a new widget. No new screens, no new routes, no changes to student-facing code.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres RPC), `owlio_shared` (LeagueTier enum, RPC name constants).

**Spec reference:** `docs/superpowers/specs/2026-04-17-teacher-rankings-design.md`

---

## Preliminary Context for the Engineer

Read these before starting (5 min each):
- `CLAUDE.md` at repo root — architecture rules: Screen → Provider → UseCase, Model owns JSON, use `DbTables.x` / `RpcFunctions.x`, UTC timestamps.
- `docs/superpowers/specs/2026-04-17-teacher-rankings-design.md` — the spec this plan implements.
- `supabase/migrations/20260327000003_enrich_class_overview_stats.sql` — the aggregation SQL pattern Feature C reuses.
- `supabase/migrations/20260328500001_teacher_school_students_rpc.sql` — the RPC you'll extend in Task 1 (and the school-scope security pattern).
- `lib/domain/entities/teacher.dart` — where `StudentSummary` and the new `SchoolSummary`/`GlobalAverages` live.
- `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart` and `leaderboard_report_screen.dart` — the two screens you modify.
- `lib/presentation/widgets/common/student_profile_dialog.dart:451-469` — tier-color and tier-asset mapping to extract into Task 3's `LeagueTierBadge` widget.

**Key enums/constants already available:**
- `LeagueTier` enum at `packages/owlio_shared/lib/src/enums/league_tier.dart` with `.fromDbValue(String)`, `.dbValue`, `.label` — do not recreate.
- `profiles.league_tier` column already exists in DB (`VARCHAR(20) NOT NULL DEFAULT 'bronze'`) — migration 20260217000001.

**Test users (all password `Test1234`, school code `DEMO123`):**
- Teacher: `teacher@demo.com`
- Students: `fresh@demo.com`, `active@demo.com`, `advanced@demo.com`

---

## File Structure

### New files (8)

- `supabase/migrations/YYYYMMDDHHMMSS_teacher_rankings.sql` — one migration file containing three RPC changes (A1, C1, C2).
- `lib/domain/usecases/teacher/get_school_summary_usecase.dart`
- `lib/domain/usecases/teacher/get_global_averages_usecase.dart`
- `lib/data/models/teacher/school_summary_model.dart`
- `lib/data/models/teacher/global_averages_model.dart`
- `lib/presentation/utils/class_ranking_metric.dart`
- `lib/presentation/widgets/common/league_tier_badge.dart`
- `test/unit/presentation/utils/class_ranking_metric_test.dart`

### Modified files (11)

- `packages/owlio_shared/lib/src/constants/rpc_functions.dart` — +2 constants
- `lib/domain/entities/teacher.dart` — `StudentSummary.leagueTier` + `SchoolSummary` + `GlobalAverages`
- `lib/data/models/teacher/student_summary_model.dart` — +1 field
- `lib/domain/repositories/teacher_repository.dart` — +2 methods
- `lib/data/repositories/supabase/supabase_teacher_repository.dart` — +2 method impls
- `lib/presentation/providers/repository_providers.dart` — no change likely (repo already wired)
- `lib/presentation/providers/usecase_providers.dart` — +2 use case providers
- `lib/presentation/providers/teacher_provider.dart` — +2 Riverpod providers
- `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart` — badge in card
- `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart` — convert to ConsumerStatefulWidget + school summary card + sort dropdown + podium badges
- `lib/presentation/widgets/common/student_profile_dialog.dart` — reuse new `LeagueTierBadge` widget

---

## Task 1: Migration — extend `get_school_students_for_teacher` to return `league_tier`

**Files:**
- Create: `supabase/migrations/YYYYMMDDHHMMSS_teacher_rankings.sql` (fresh timestamp — pick one higher than the latest migration in `supabase/migrations/` at implementation time)

This is the database foundation for Feature A. Also includes the Feature C RPCs (Tasks 12-13) in the same migration file — consolidate to avoid multiple migration pushes.

- [ ] **Step 1: Create the migration file**

Create `supabase/migrations/YYYYMMDDHHMMSS_teacher_rankings.sql` with the following content. Use a timestamp that sorts after the latest existing migration (run `ls supabase/migrations/ | tail -3` and add 1 to the highest).

```sql
-- =============================================
-- Teacher Rankings feature
-- 1. Extend get_school_students_for_teacher with league_tier
-- 2. New get_school_summary(p_school_id)
-- 3. New get_global_student_averages()
-- =============================================

-- 1. Extend get_school_students_for_teacher to return league_tier
DROP FUNCTION IF EXISTS get_school_students_for_teacher(UUID);
CREATE OR REPLACE FUNCTION get_school_students_for_teacher(p_school_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  username TEXT,
  email TEXT,
  avatar_url TEXT,
  password_plain TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC,
  league_tier TEXT
) AS $$
DECLARE
  v_caller_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  IF v_caller_school_id IS DISTINCT FROM p_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access students from another school';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
    p.username::TEXT,
    u.email::TEXT,
    p.avatar_url::TEXT,
    p.password_plain::TEXT,
    p.xp,
    p.level,
    p.current_streak,
    COALESCE((
      SELECT COUNT(DISTINCT rp.book_id)::INT
      FROM reading_progress rp
      WHERE rp.user_id = p.id AND rp.is_completed = true
    ), 0) as books_read,
    COALESCE((
      SELECT AVG(rp2.completion_percentage)
      FROM reading_progress rp2
      WHERE rp2.user_id = p.id
    ), 0) as avg_progress,
    p.league_tier::TEXT
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.school_id = p_school_id AND p.role = 'student'
  ORDER BY p.xp DESC, p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. get_school_summary — aggregates for teacher's own school
CREATE OR REPLACE FUNCTION get_school_summary(p_school_id UUID)
RETURNS TABLE (
  total_students INT,
  active_last_30d INT,
  total_xp BIGINT,
  avg_xp NUMERIC,
  avg_streak NUMERIC,
  avg_progress NUMERIC,
  total_reading_time BIGINT,
  total_books_read INT,
  total_vocab_words INT
) AS $$
DECLARE
  v_caller_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  IF v_caller_school_id IS DISTINCT FROM p_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access another school';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(DISTINCT p.id)::INT as total_students,
    COUNT(DISTINCT CASE
      WHEN p.last_login_at >= NOW() - INTERVAL '30 days' THEN p.id
    END)::INT as active_last_30d,
    COALESCE(SUM(p.xp), 0)::BIGINT as total_xp,
    COALESCE(AVG(p.xp), 0) as avg_xp,
    COALESCE(AVG(p.current_streak), 0) as avg_streak,
    COALESCE(AVG(rp_avg.avg_completion), 0) as avg_progress,
    COALESCE(SUM(rp_time.total_time), 0)::BIGINT as total_reading_time,
    COALESCE(SUM(rp_complete.book_count), 0)::INT as total_books_read,
    COALESCE(SUM(vocab_ct.word_count), 0)::INT as total_vocab_words
  FROM profiles p
  -- Avg reading progress per student
  LEFT JOIN LATERAL (
    SELECT AVG(rp.completion_percentage) as avg_completion
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_avg ON true
  -- Total reading time per student
  LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(rp.total_reading_time), 0) as total_time
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_time ON true
  -- Completed books per student
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::BIGINT as book_count
    FROM reading_progress rp WHERE rp.user_id = p.id AND rp.is_completed = true
  ) rp_complete ON true
  -- Vocabulary words mastered per student
  LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT vp.word_id)::BIGINT as word_count
    FROM vocabulary_progress vp WHERE vp.user_id = p.id AND vp.mastery_level >= 3
  ) vocab_ct ON true
  WHERE p.school_id = p_school_id AND p.role = 'student';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. get_global_student_averages — platform-wide averages across all schools
CREATE OR REPLACE FUNCTION get_global_student_averages()
RETURNS TABLE (
  avg_xp NUMERIC,
  avg_streak NUMERIC,
  avg_progress NUMERIC,
  avg_reading_time NUMERIC,
  avg_books_read NUMERIC
) AS $$
BEGIN
  -- Any authenticated user can read aggregated averages (no identifiable data).
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: authentication required';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(AVG(p.xp), 0) as avg_xp,
    COALESCE(AVG(p.current_streak), 0) as avg_streak,
    COALESCE(AVG(rp_avg.avg_completion), 0) as avg_progress,
    COALESCE(AVG(rp_time.total_time), 0) as avg_reading_time,
    COALESCE(AVG(rp_complete.book_count), 0) as avg_books_read
  FROM profiles p
  LEFT JOIN LATERAL (
    SELECT AVG(rp.completion_percentage) as avg_completion
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_avg ON true
  LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(rp.total_reading_time), 0) as total_time
    FROM reading_progress rp WHERE rp.user_id = p.id
  ) rp_time ON true
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::BIGINT as book_count
    FROM reading_progress rp WHERE rp.user_id = p.id AND rp.is_completed = true
  ) rp_complete ON true
  WHERE p.role = 'student';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Note on demo-account exclusion:** Before writing, check for demo/test flags:

```bash
grep -n "is_demo\|is_test\|demo_account" supabase/migrations/ | head
```

If any matches exist on the `profiles` table, add `AND COALESCE(p.is_demo, false) = false` to the WHERE of BOTH `get_school_summary` and `get_global_student_averages`. If no flag exists, skip — demo rows are part of the averages for v1.

- [ ] **Step 2: Dry-run**

Run: `supabase db push --dry-run`
Expected: Diff shows 3 function drops + 3 function creates. No other schema changes.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: `Finished supabase db push`.

- [ ] **Step 4: Smoke test in Supabase SQL editor**

Run (authenticated as a teacher session — or via service role for local test):
```sql
select * from get_global_student_averages() limit 1;
```
Expected: one row with 5 numeric columns.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/YYYYMMDDHHMMSS_teacher_rankings.sql
git commit -m "feat(teacher-rankings): migration — league_tier in RPC + school_summary + global_averages"
```

---

## Task 2: Add RPC name constants

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Add two constants**

Open `packages/owlio_shared/lib/src/constants/rpc_functions.dart`. Find the existing `getSchoolStudentsForTeacher = 'get_school_students_for_teacher';` constant (around line 72). Add the following two constants near it (alphabetical order preferred):

```dart
  static const getSchoolSummary = 'get_school_summary';
  static const getGlobalStudentAverages = 'get_global_student_averages';
```

- [ ] **Step 2: Analyze**

Run: `dart analyze packages/owlio_shared/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(teacher-rankings): add RPC name constants for school summary + global averages"
```

---

## Task 3: Extend `StudentSummary` entity with `leagueTier`

**Files:**
- Modify: `lib/domain/entities/teacher.dart:64-99`

Required field on the entity. Default fallback for safety is handled in the model (Task 4), not here — the domain should be strict.

- [ ] **Step 1: Add `LeagueTier` import**

At the top of `lib/domain/entities/teacher.dart`, add:

```dart
import 'package:owlio_shared/owlio_shared.dart';
```

If that import already exists, skip. Check with `grep -n "owlio_shared" lib/domain/entities/teacher.dart`.

- [ ] **Step 2: Add field to `StudentSummary`**

Replace the existing `StudentSummary` class (currently at lines ~64-99) with:

```dart
/// Student summary for class view
class StudentSummary extends Equatable {

  const StudentSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.studentNumber,
    this.username,
    this.email,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.booksRead,
    required this.avgProgress,
    required this.leagueTier,
    this.passwordPlain,
  });
  final String id;
  final String firstName;
  final String lastName;
  final String? studentNumber;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int currentStreak;
  final int booksRead;
  final double avgProgress;
  final LeagueTier leagueTier;
  final String? passwordPlain;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, firstName, lastName, studentNumber, username, email, avatarUrl, xp, level, currentStreak, booksRead, avgProgress, leagueTier, passwordPlain];
}
```

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/domain/entities/teacher.dart`
Expected: `No issues found!` (Model file will break — fixed in Task 4.)

- [ ] **Step 4: Don't commit yet** — commit together with Task 4 since both are required for compilation.

---

## Task 4: Extend `StudentSummaryModel` to parse `league_tier`

**Files:**
- Modify: `lib/data/models/teacher/student_summary_model.dart`

- [ ] **Step 1: Update the model**

Replace the entire file contents of `lib/data/models/teacher/student_summary_model.dart` with:

```dart
import 'package:owlio_shared/owlio_shared.dart';
import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentSummary - handles JSON serialization
class StudentSummaryModel {

  const StudentSummaryModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.studentNumber,
    this.username,
    this.email,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.booksRead,
    required this.avgProgress,
    required this.leagueTier,
    this.passwordPlain,
  });

  factory StudentSummaryModel.fromJson(Map<String, dynamic> json) {
    return StudentSummaryModel(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      studentNumber: json['student_number'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentStreak: (json['streak'] as num?)?.toInt() ?? 0,
      booksRead: (json['books_read'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      leagueTier: _parseLeagueTier(json['league_tier'] as String?),
      passwordPlain: json['password_plain'] as String?,
    );
  }

  static LeagueTier _parseLeagueTier(String? value) {
    if (value == null || value.isEmpty) return LeagueTier.bronze;
    return LeagueTier.fromDbValue(value);
  }

  final String id;
  final String firstName;
  final String lastName;
  final String? studentNumber;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int currentStreak;
  final int booksRead;
  final double avgProgress;
  final LeagueTier leagueTier;
  final String? passwordPlain;

  StudentSummary toEntity() {
    return StudentSummary(
      id: id,
      firstName: firstName,
      lastName: lastName,
      studentNumber: studentNumber,
      username: username,
      email: email,
      avatarUrl: avatarUrl,
      xp: xp,
      level: level,
      currentStreak: currentStreak,
      booksRead: booksRead,
      avgProgress: avgProgress,
      leagueTier: leagueTier,
      passwordPlain: passwordPlain,
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/data/models/teacher/student_summary_model.dart lib/domain/entities/teacher.dart`
Expected: `No issues found!`

- [ ] **Step 3: Fix any call sites that construct `StudentSummary` directly**

Run: `grep -rn "StudentSummary(" lib/ test/ | grep -v ".g.dart"`
Expected: a few call sites — most in test fixtures. For each, add `leagueTier: LeagueTier.bronze,` to the constructor. Also add `import 'package:owlio_shared/owlio_shared.dart';` where needed.

The engineer will need to iterate here; common locations:
- `test/fixtures/` builders
- Possibly `lib/data/repositories/supabase/supabase_teacher_repository.dart` if it constructs directly (it uses the model's `toEntity()` — likely safe)

Run `dart analyze lib/ test/` after each batch; stop when clean.

- [ ] **Step 4: Commit (bundled with Task 3)**

```bash
git add lib/domain/entities/teacher.dart \
        lib/data/models/teacher/student_summary_model.dart \
        test/fixtures/ lib/data/repositories/supabase/supabase_teacher_repository.dart
git commit -m "feat(teacher-rankings): expose leagueTier on StudentSummary"
```

Adjust the `git add` list based on which files Step 3 touched.

---

## Task 5: Create `LeagueTierBadge` reusable widget + refactor profile dialog

**Files:**
- Create: `lib/presentation/widgets/common/league_tier_badge.dart`
- Modify: `lib/presentation/widgets/common/student_profile_dialog.dart:451-469` (remove `_getTierColor` and `_tierAsset` — they move into the new widget)

- [ ] **Step 1: Create the badge widget**

Create `lib/presentation/widgets/common/league_tier_badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// Small circular badge showing a student's league tier (bronze → diamond).
/// Extracted from StudentProfileDialog so it can be reused in the teacher
/// Leaderboard report and any future surfaces.
class LeagueTierBadge extends StatelessWidget {
  const LeagueTierBadge({
    super.key,
    required this.tier,
    this.size = 32,
  });

  final LeagueTier tier;
  final double size;

  static Color tierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.diamond => const Color(0xFF00BFFF),
      LeagueTier.platinum => const Color(0xFFE5E4E2),
      LeagueTier.gold => const Color(0xFFFFD700),
      LeagueTier.silver => const Color(0xFFC0C0C0),
      LeagueTier.bronze => const Color(0xFFCD7F32),
    };
  }

  static String tierAsset(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => 'assets/icons/rank-bronze-1_large.png',
      LeagueTier.silver => 'assets/icons/rank-silver-2_large.png',
      LeagueTier.gold => 'assets/icons/rank-gold-3_large.png',
      LeagueTier.platinum => 'assets/icons/rank-platinum-5_large.png',
      LeagueTier.diamond => 'assets/icons/rank-diamond-7_large.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tier.label,
      child: Image.asset(
        tierAsset(tier),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
```

- [ ] **Step 2: Refactor `student_profile_dialog.dart` to use the new widget**

In `lib/presentation/widgets/common/student_profile_dialog.dart`:

1. Add import at top:
```dart
import 'league_tier_badge.dart';
```

2. Remove the static helper methods `_getTierColor` and `_tierAsset` (around lines 451-469).

3. Find where they are used in the same file (search for `_getTierColor` and `_tierAsset` — there should be 1-2 call sites above line 451). Replace:
   - `_getTierColor(tier)` → `LeagueTierBadge.tierColor(tier)`
   - `Image.asset(_tierAsset(tier), ...)` → `LeagueTierBadge(tier: tier, size: <original-size>)`

   **Important:** Preserve the original badge size in the profile dialog (likely 48 or 56 px). Grep for the original Image.asset call before the extraction to find the size used.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/widgets/common/league_tier_badge.dart lib/presentation/widgets/common/student_profile_dialog.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manual visual smoke**

Run the app. Open any student's profile dialog from the teacher panel (teacher → Classes → click student → profile dialog). The league badge should look identical to before — same colour, same size. If it looks different, the size param was wrong in Step 2.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/common/league_tier_badge.dart \
        lib/presentation/widgets/common/student_profile_dialog.dart
git commit -m "refactor(teacher-rankings): extract LeagueTierBadge widget"
```

---

## Task 6: Render league badge in `_LeaderboardCard`

**Files:**
- Modify: `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart:170-205`

- [ ] **Step 1: Add import**

At the top of `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart`, add:

```dart
import '../../../widgets/common/league_tier_badge.dart';
```

- [ ] **Step 2: Insert the badge beside the XP column**

Find the "XP and Level" Column block (roughly lines 170-205 of the current file). Replace the outer `Column(...)` with a `Row` that places a `LeagueTierBadge` immediately before the existing XP/Level column. Approximate shape:

```dart
            // Replace the existing "XP and Level" Column with:
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LeagueTierBadge(tier: student.leagueTier, size: 32),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ... existing XP Row
                    // ... existing Level Container
                  ],
                ),
              ],
            ),
```

Keep the internal structure of the XP/Level column byte-identical. Only add the `Row` wrapper + badge + gap.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke — teacher**

Log in as `teacher@demo.com`, navigate Reports → Student Leaderboard. Each student card shows a league badge (32 px) to the left of the XP/Level column. Check students across all 5 tiers if available; default fallback is bronze.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart
git commit -m "feat(teacher-rankings): show league tier badge in Student Leaderboard"
```

---

## Task 7: Create `ClassRankingMetric` enum + unit test

**Files:**
- Create: `lib/presentation/utils/class_ranking_metric.dart`
- Create: `test/unit/presentation/utils/class_ranking_metric_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/unit/presentation/utils/class_ranking_metric_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:owlio/domain/entities/teacher.dart';
import 'package:owlio/presentation/utils/class_ranking_metric.dart';

TeacherClass _mkClass({
  String id = 'c1',
  double avgXp = 0,
  double avgProgress = 0,
  double avgStreak = 0,
  int totalReadingTime = 0,
  double booksPerStudent = 0,
}) {
  return TeacherClass(
    id: id,
    name: 'Test',
    grade: 5,
    academicYear: '2025-2026',
    studentCount: 10,
    avgProgress: avgProgress,
    avgXp: avgXp,
    avgStreak: avgStreak,
    totalReadingTime: totalReadingTime,
    completedBooks: 0,
    activeLast30d: 0,
    totalVocabWords: 0,
    booksPerStudent: booksPerStudent,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('avgXp selector returns avgXp field', () {
    final c = _mkClass(avgXp: 123.45);
    expect(ClassRankingMetric.avgXp.selector(c), 123.45);
  });

  test('avgProgress selector returns avgProgress field', () {
    final c = _mkClass(avgProgress: 67.8);
    expect(ClassRankingMetric.avgProgress.selector(c), 67.8);
  });

  test('avgStreak selector returns avgStreak field', () {
    final c = _mkClass(avgStreak: 4.2);
    expect(ClassRankingMetric.avgStreak.selector(c), 4.2);
  });

  test('totalReadingTime selector returns totalReadingTime field', () {
    final c = _mkClass(totalReadingTime: 99999);
    expect(ClassRankingMetric.totalReadingTime.selector(c), 99999);
  });

  test('booksPerStudent selector returns booksPerStudent field', () {
    final c = _mkClass(booksPerStudent: 2.5);
    expect(ClassRankingMetric.booksPerStudent.selector(c), 2.5);
  });

  test('every metric has a non-empty label', () {
    for (final m in ClassRankingMetric.values) {
      expect(m.label, isNotEmpty);
    }
  });
}
```

**Note:** Verify the `TeacherClass` constructor signature matches by running `grep -n "class TeacherClass" lib/domain/entities/teacher.dart -A 30 | head -40`. Adjust `_mkClass` fields if the entity has more/fewer required params.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/presentation/utils/class_ranking_metric_test.dart`
Expected: FAIL — `class_ranking_metric.dart` does not exist.

- [ ] **Step 3: Create the enum**

Create `lib/presentation/utils/class_ranking_metric.dart`:

```dart
import '../../domain/entities/teacher.dart';

/// Metrics a teacher can sort classes by in the Class Overview report.
enum ClassRankingMetric {
  avgXp,
  avgProgress,
  avgStreak,
  totalReadingTime,
  booksPerStudent,
}

extension ClassRankingMetricX on ClassRankingMetric {
  String get label {
    switch (this) {
      case ClassRankingMetric.avgXp:
        return 'Avg XP';
      case ClassRankingMetric.avgProgress:
        return 'Avg Progress';
      case ClassRankingMetric.avgStreak:
        return 'Avg Streak';
      case ClassRankingMetric.totalReadingTime:
        return 'Total Reading Time';
      case ClassRankingMetric.booksPerStudent:
        return 'Books / Student';
    }
  }

  num Function(TeacherClass) get selector {
    switch (this) {
      case ClassRankingMetric.avgXp:
        return (c) => c.avgXp;
      case ClassRankingMetric.avgProgress:
        return (c) => c.avgProgress;
      case ClassRankingMetric.avgStreak:
        return (c) => c.avgStreak;
      case ClassRankingMetric.totalReadingTime:
        return (c) => c.totalReadingTime;
      case ClassRankingMetric.booksPerStudent:
        return (c) => c.booksPerStudent;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/presentation/utils/class_ranking_metric_test.dart`
Expected: All 6 tests pass.

- [ ] **Step 5: Analyze**

Run: `dart analyze lib/presentation/utils/class_ranking_metric.dart test/unit/presentation/utils/class_ranking_metric_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/utils/class_ranking_metric.dart \
        test/unit/presentation/utils/class_ranking_metric_test.dart
git commit -m "feat(teacher-rankings): add ClassRankingMetric enum + selector tests"
```

---

## Task 8: Sort dropdown + podium badges in `ClassOverviewReportScreen`

**Files:**
- Modify: `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`

Convert to `ConsumerStatefulWidget` to hold the selected metric. Add dropdown, sort list, render podium on top 3. School summary card is added in Task 15 — keep that space for now.

- [ ] **Step 1: Convert to `ConsumerStatefulWidget`**

Currently (line 18):
```dart
class ClassOverviewReportScreen extends ConsumerWidget {
  const ClassOverviewReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

Change to:
```dart
class ClassOverviewReportScreen extends ConsumerStatefulWidget {
  const ClassOverviewReportScreen({super.key});

  @override
  ConsumerState<ClassOverviewReportScreen> createState() =>
      _ClassOverviewReportScreenState();
}

class _ClassOverviewReportScreenState
    extends ConsumerState<ClassOverviewReportScreen> {
  ClassRankingMetric _selectedMetric = ClassRankingMetric.avgXp;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref; // ConsumerState exposes ref as a property
```

Remove the `WidgetRef ref` parameter from `build` — `ConsumerState` provides `ref` as an instance property.

- [ ] **Step 2: Add import**

At the top of the file, add:

```dart
import '../../../utils/class_ranking_metric.dart';
```

- [ ] **Step 3: Sort the class list by selected metric**

Find the block that builds `classes` (around line 40-60, inside `classesAsync.when`'s `data:` callback). Before the `return ListView(...)`, add:

```dart
            final sortedClasses = [...classes]
              ..sort((a, b) {
                final aVal = _selectedMetric.selector(a);
                final bVal = _selectedMetric.selector(b);
                return bVal.compareTo(aVal); // descending — best first
              });
```

Then replace subsequent uses of `classes` with `sortedClasses` — specifically the `ResponsiveWrap(children: classes.map(...))` call (around line 102-115).

- [ ] **Step 4: Add sort dropdown above the class list**

Find the `Text('Class Performance', ...)` block (around line 91). Replace with a Row:

```dart
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Class Performance',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                    DropdownButton<ClassRankingMetric>(
                      value: _selectedMetric,
                      underline: const SizedBox.shrink(),
                      items: ClassRankingMetric.values.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            'Sort: ${m.label}',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (m) {
                        if (m != null) {
                          setState(() => _selectedMetric = m);
                        }
                      },
                    ),
                  ],
                ),
```

- [ ] **Step 5: Pass rank to `_EnrichedClassCard`**

In the `ResponsiveWrap` map call (after Step 3), change from `sortedClasses.map((classItem) => _EnrichedClassCard(classItem: classItem, ...))` to pass an index-based rank:

```dart
                  children: sortedClasses.indexed.map(
                    (entry) {
                      final (index, classItem) = entry;
                      return _EnrichedClassCard(
                        classItem: classItem,
                        rank: sortedClasses.length >= 3 ? index + 1 : null,
                        onTap: () => context.push(
                          AppRoutes.teacherClassDetailPath(classItem.id),
                          extra: ClassDetailMode.report,
                        ),
                      );
                    },
                  ).toList(),
```

- [ ] **Step 6: Add `rank` param to `_EnrichedClassCard` and render podium icon**

Find `class _EnrichedClassCard extends StatelessWidget` (around line 172). Add a `final int? rank;` field (optional), accept it in the constructor. Then in `build`, wrap the card body with a `Stack` so a podium icon can overlay the top-right corner when `rank <= 3`:

```dart
class _EnrichedClassCard extends StatelessWidget {
  const _EnrichedClassCard({
    required this.classItem,
    required this.onTap,
    this.rank,
  });

  final TeacherClass classItem;
  final VoidCallback onTap;
  final int? rank;

  Color? _podiumColor() {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _podiumColor();
    final card = PlayfulCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        // ... existing column children UNCHANGED
      ),
    );
    if (color == null) return card;
    return Stack(
      children: [
        card,
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
```

**Important:** Keep the existing `Column(...)` children inside `card` byte-identical. Only add the `Stack` wrapper and the podium overlay; do not touch the metric chips, progress bar, or header row.

- [ ] **Step 7: Analyze**

Run: `dart analyze lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Manual smoke — teacher**

Log in as `teacher@demo.com`, navigate Reports → Class Overview.
- Dropdown visible next to "Class Performance" heading, default "Sort: Avg XP".
- With 3+ classes: top 3 cards have gold/silver/bronze emoji_events badges top-right.
- Change dropdown → classes re-order + podium badges move.
- With <3 classes: no podium badges.

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/screens/teacher/reports/class_overview_report_screen.dart
git commit -m "feat(teacher-rankings): sort dropdown + podium badges in Class Overview"
```

---

## Task 9: Create `SchoolSummary` + `GlobalAverages` entities

**Files:**
- Modify: `lib/domain/entities/teacher.dart` (append two classes at the end of the file)

- [ ] **Step 1: Append the entities**

Open `lib/domain/entities/teacher.dart`. At the END of the file (after the last existing class), append:

```dart
/// Aggregate stats for the teacher's own school.
class SchoolSummary extends Equatable {
  const SchoolSummary({
    required this.totalStudents,
    required this.activeLast30d,
    required this.totalXp,
    required this.avgXp,
    required this.avgStreak,
    required this.avgProgress,
    required this.totalReadingTime,
    required this.totalBooksRead,
    required this.totalVocabWords,
  });

  final int totalStudents;
  final int activeLast30d;
  final int totalXp;
  final double avgXp;
  final double avgStreak;
  final double avgProgress;
  final int totalReadingTime;
  final int totalBooksRead;
  final int totalVocabWords;

  @override
  List<Object?> get props => [
        totalStudents,
        activeLast30d,
        totalXp,
        avgXp,
        avgStreak,
        avgProgress,
        totalReadingTime,
        totalBooksRead,
        totalVocabWords,
      ];
}

/// Platform-wide averages across all students in all schools.
/// Used as a benchmark next to SchoolSummary values.
class GlobalAverages extends Equatable {
  const GlobalAverages({
    required this.avgXp,
    required this.avgStreak,
    required this.avgProgress,
    required this.avgReadingTime,
    required this.avgBooksRead,
  });

  final double avgXp;
  final double avgStreak;
  final double avgProgress;
  final double avgReadingTime;
  final double avgBooksRead;

  @override
  List<Object?> get props =>
      [avgXp, avgStreak, avgProgress, avgReadingTime, avgBooksRead];
}
```

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/domain/entities/teacher.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/teacher.dart
git commit -m "feat(teacher-rankings): add SchoolSummary + GlobalAverages entities"
```

---

## Task 10: Create models for `SchoolSummary` + `GlobalAverages`

**Files:**
- Create: `lib/data/models/teacher/school_summary_model.dart`
- Create: `lib/data/models/teacher/global_averages_model.dart`

- [ ] **Step 1: SchoolSummaryModel**

Create `lib/data/models/teacher/school_summary_model.dart`:

```dart
import '../../../domain/entities/teacher.dart';

class SchoolSummaryModel {
  const SchoolSummaryModel({
    required this.totalStudents,
    required this.activeLast30d,
    required this.totalXp,
    required this.avgXp,
    required this.avgStreak,
    required this.avgProgress,
    required this.totalReadingTime,
    required this.totalBooksRead,
    required this.totalVocabWords,
  });

  factory SchoolSummaryModel.fromJson(Map<String, dynamic> json) {
    return SchoolSummaryModel(
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeLast30d: (json['active_last_30d'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      avgXp: (json['avg_xp'] as num?)?.toDouble() ?? 0,
      avgStreak: (json['avg_streak'] as num?)?.toDouble() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      totalReadingTime: (json['total_reading_time'] as num?)?.toInt() ?? 0,
      totalBooksRead: (json['total_books_read'] as num?)?.toInt() ?? 0,
      totalVocabWords: (json['total_vocab_words'] as num?)?.toInt() ?? 0,
    );
  }

  final int totalStudents;
  final int activeLast30d;
  final int totalXp;
  final double avgXp;
  final double avgStreak;
  final double avgProgress;
  final int totalReadingTime;
  final int totalBooksRead;
  final int totalVocabWords;

  SchoolSummary toEntity() => SchoolSummary(
        totalStudents: totalStudents,
        activeLast30d: activeLast30d,
        totalXp: totalXp,
        avgXp: avgXp,
        avgStreak: avgStreak,
        avgProgress: avgProgress,
        totalReadingTime: totalReadingTime,
        totalBooksRead: totalBooksRead,
        totalVocabWords: totalVocabWords,
      );
}
```

- [ ] **Step 2: GlobalAveragesModel**

Create `lib/data/models/teacher/global_averages_model.dart`:

```dart
import '../../../domain/entities/teacher.dart';

class GlobalAveragesModel {
  const GlobalAveragesModel({
    required this.avgXp,
    required this.avgStreak,
    required this.avgProgress,
    required this.avgReadingTime,
    required this.avgBooksRead,
  });

  factory GlobalAveragesModel.fromJson(Map<String, dynamic> json) {
    return GlobalAveragesModel(
      avgXp: (json['avg_xp'] as num?)?.toDouble() ?? 0,
      avgStreak: (json['avg_streak'] as num?)?.toDouble() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      avgReadingTime: (json['avg_reading_time'] as num?)?.toDouble() ?? 0,
      avgBooksRead: (json['avg_books_read'] as num?)?.toDouble() ?? 0,
    );
  }

  final double avgXp;
  final double avgStreak;
  final double avgProgress;
  final double avgReadingTime;
  final double avgBooksRead;

  GlobalAverages toEntity() => GlobalAverages(
        avgXp: avgXp,
        avgStreak: avgStreak,
        avgProgress: avgProgress,
        avgReadingTime: avgReadingTime,
        avgBooksRead: avgBooksRead,
      );
}
```

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/data/models/teacher/school_summary_model.dart lib/data/models/teacher/global_averages_model.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/teacher/school_summary_model.dart \
        lib/data/models/teacher/global_averages_model.dart
git commit -m "feat(teacher-rankings): add models for SchoolSummary + GlobalAverages"
```

---

## Task 11: Extend `TeacherRepository` interface + Supabase implementation

**Files:**
- Modify: `lib/domain/repositories/teacher_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart`

- [ ] **Step 1: Add methods to the interface**

In `lib/domain/repositories/teacher_repository.dart`, add two abstract method signatures anywhere in the existing `abstract class TeacherRepository` block:

```dart
  Future<Either<Failure, SchoolSummary>> getSchoolSummary(String schoolId);

  Future<Either<Failure, GlobalAverages>> getGlobalAverages();
```

- [ ] **Step 2: Add implementations to the Supabase repo**

In `lib/data/repositories/supabase/supabase_teacher_repository.dart`, find the existing `getSchoolStudentsForTeacher` method (around line 245) and use it as a template. Add these two methods after it:

```dart
  @override
  Future<Either<Failure, SchoolSummary>> getSchoolSummary(String schoolId) async {
    try {
      final data = await _client.rpc(
        RpcFunctions.getSchoolSummary,
        params: {'p_school_id': schoolId},
      );
      final list = data as List;
      if (list.isEmpty) {
        return Left(ServerFailure(message: 'Empty school summary response'));
      }
      final model = SchoolSummaryModel.fromJson(list.first as Map<String, dynamic>);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, GlobalAverages>> getGlobalAverages() async {
    try {
      final data = await _client.rpc(RpcFunctions.getGlobalStudentAverages);
      final list = data as List;
      if (list.isEmpty) {
        return Left(ServerFailure(message: 'Empty global averages response'));
      }
      final model = GlobalAveragesModel.fromJson(list.first as Map<String, dynamic>);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
```

Add imports at the top of the file if not already present:

```dart
import 'package:owlio_shared/owlio_shared.dart';
import '../../../domain/entities/teacher.dart';
import '../../models/teacher/school_summary_model.dart';
import '../../models/teacher/global_averages_model.dart';
```

**Note:** The actual client variable may be `supabase.rpc(...)` or `_client.rpc(...)` — check existing methods in the same file and match. `ServerFailure` class may be named `DatabaseFailure` — again match existing methods.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/domain/repositories/teacher_repository.dart lib/data/repositories/supabase/supabase_teacher_repository.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/repositories/teacher_repository.dart \
        lib/data/repositories/supabase/supabase_teacher_repository.dart
git commit -m "feat(teacher-rankings): repository methods for school summary + global averages"
```

---

## Task 12: Create use cases

**Files:**
- Create: `lib/domain/usecases/teacher/get_school_summary_usecase.dart`
- Create: `lib/domain/usecases/teacher/get_global_averages_usecase.dart`

Follow the same pattern as existing use cases in `lib/domain/usecases/teacher/` (see `get_teacher_stats_usecase.dart` for a minimal template).

- [ ] **Step 1: GetSchoolSummaryUseCase**

Create `lib/domain/usecases/teacher/get_school_summary_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../../core/usecases/usecase.dart';
import '../../entities/teacher.dart';
import '../../repositories/teacher_repository.dart';

class GetSchoolSummaryParams {
  const GetSchoolSummaryParams({required this.schoolId});
  final String schoolId;
}

class GetSchoolSummaryUseCase
    implements UseCase<SchoolSummary, GetSchoolSummaryParams> {
  const GetSchoolSummaryUseCase(this._repository);

  final TeacherRepository _repository;

  @override
  Future<Either<Failure, SchoolSummary>> call(
    GetSchoolSummaryParams params,
  ) {
    return _repository.getSchoolSummary(params.schoolId);
  }
}
```

- [ ] **Step 2: GetGlobalAveragesUseCase**

Create `lib/domain/usecases/teacher/get_global_averages_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../../core/usecases/usecase.dart';
import '../../entities/teacher.dart';
import '../../repositories/teacher_repository.dart';

class GetGlobalAveragesUseCase implements UseCase<GlobalAverages, NoParams> {
  const GetGlobalAveragesUseCase(this._repository);

  final TeacherRepository _repository;

  @override
  Future<Either<Failure, GlobalAverages>> call(NoParams params) {
    return _repository.getGlobalAverages();
  }
}
```

**Note:** `NoParams` may live in `lib/core/usecases/usecase.dart` — confirm by opening that file; if the existing use cases use a different pattern (e.g. `() =>` with no params class), match that instead.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/domain/usecases/teacher/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/usecases/teacher/get_school_summary_usecase.dart \
        lib/domain/usecases/teacher/get_global_averages_usecase.dart
git commit -m "feat(teacher-rankings): add use cases for school summary + global averages"
```

---

## Task 13: Wire use cases + providers

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/teacher_provider.dart`

- [ ] **Step 1: Register use case providers**

In `lib/presentation/providers/usecase_providers.dart`, find the block where existing teacher use cases are registered (search `grep -n "TeacherUseCase\|teacher/" lib/presentation/providers/usecase_providers.dart`). Append two new providers at the end of that block (match the existing style — likely a one-liner per use case):

```dart
final getSchoolSummaryUseCaseProvider = Provider(
  (ref) => GetSchoolSummaryUseCase(ref.watch(teacherRepositoryProvider)),
);

final getGlobalAveragesUseCaseProvider = Provider(
  (ref) => GetGlobalAveragesUseCase(ref.watch(teacherRepositoryProvider)),
);
```

Add imports at the top of the file:

```dart
import '../../domain/usecases/teacher/get_school_summary_usecase.dart';
import '../../domain/usecases/teacher/get_global_averages_usecase.dart';
```

- [ ] **Step 2: Create Riverpod providers**

In `lib/presentation/providers/teacher_provider.dart`, near the bottom (after `allStudentsLeaderboardProvider`, around line 338), append:

```dart
/// Aggregates for the teacher's own school (watches authed user for schoolId).
final schoolSummaryProvider =
    FutureProvider.autoDispose<SchoolSummary?>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null || user.schoolId.isEmpty) return null;

  final useCase = ref.watch(getSchoolSummaryUseCaseProvider);
  final result = await useCase(
    GetSchoolSummaryParams(schoolId: user.schoolId),
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

/// Platform-wide student averages (same for every teacher).
final globalAveragesProvider =
    FutureProvider.autoDispose<GlobalAverages>((ref) async {
  final useCase = ref.watch(getGlobalAveragesUseCaseProvider);
  final result = await useCase(NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (averages) => averages,
  );
});
```

Add imports at the top of the file:

```dart
import '../../domain/usecases/teacher/get_school_summary_usecase.dart';
import '../../domain/usecases/teacher/get_global_averages_usecase.dart';
```

`NoParams`, `SchoolSummary`, `GlobalAverages` should already be reachable through existing imports (`entities/teacher.dart`, `core/usecases/usecase.dart`). Add if missing.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/providers/teacher_provider.dart lib/presentation/providers/usecase_providers.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/usecase_providers.dart \
        lib/presentation/providers/teacher_provider.dart
git commit -m "feat(teacher-rankings): add Riverpod providers for school summary + global averages"
```

---

## Task 14: Build `_SchoolSummaryCard` widget inside `class_overview_report_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`

Keep this widget in the same file as the screen — it's tightly coupled to this one use site. Later refactor out if reused elsewhere.

- [ ] **Step 1: Add the widget class**

At the bottom of `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart` (after `_MetricChip`), add:

```dart
class _SchoolSummaryCard extends ConsumerWidget {
  const _SchoolSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(schoolSummaryProvider);
    final globalAsync = ref.watch(globalAveragesProvider);

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();
        final global = globalAsync.valueOrNull;
        return PlayfulCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school_rounded, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'My School',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryRow(
                label: 'Avg XP',
                mine: summary.avgXp.toStringAsFixed(0),
                benchmark: global?.avgXp.toStringAsFixed(0),
                mineVal: summary.avgXp,
                benchmarkVal: global?.avgXp,
              ),
              _SummaryRow(
                label: 'Avg Streak',
                mine: summary.avgStreak.toStringAsFixed(1),
                benchmark: global?.avgStreak.toStringAsFixed(1),
                mineVal: summary.avgStreak,
                benchmarkVal: global?.avgStreak,
              ),
              _SummaryRow(
                label: 'Avg Progress',
                mine: '${summary.avgProgress.toStringAsFixed(0)}%',
                benchmark: global != null
                    ? '${global.avgProgress.toStringAsFixed(0)}%'
                    : null,
                mineVal: summary.avgProgress,
                benchmarkVal: global?.avgProgress,
              ),
              _SummaryRow(
                label: 'Books Read / Student',
                mine: summary.totalStudents > 0
                    ? (summary.totalBooksRead / summary.totalStudents)
                        .toStringAsFixed(1)
                    : '0.0',
                benchmark: global?.avgBooksRead.toStringAsFixed(1),
                mineVal: summary.totalStudents > 0
                    ? summary.totalBooksRead / summary.totalStudents
                    : 0.0,
                benchmarkVal: global?.avgBooksRead,
              ),
              _SummaryRow(
                label: 'Active (30d)',
                mine: '${summary.activeLast30d}/${summary.totalStudents}',
                benchmark: null,
                mineVal: null,
                benchmarkVal: null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.mine,
    required this.benchmark,
    required this.mineVal,
    required this.benchmarkVal,
  });

  final String label;
  final String mine;
  final String? benchmark;
  final double? mineVal;
  final double? benchmarkVal;

  Color _compareColor() {
    if (mineVal == null || benchmarkVal == null) return AppColors.neutralText;
    if (mineVal! > benchmarkVal!) return Colors.green.shade600;
    if (mineVal! < benchmarkVal!) return AppColors.neutralText;
    return AppColors.neutralText;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              mine,
              textAlign: TextAlign.right,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _compareColor(),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              benchmark == null ? '' : 'global: $benchmark',
              textAlign: TextAlign.right,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add imports**

At the top of `class_overview_report_screen.dart`, if not already present, add:

```dart
// SchoolSummary + schoolSummaryProvider + globalAveragesProvider + GlobalAverages
// come from existing imports of teacher.dart and teacher_provider.dart.
```

Verify: the file should already import `../../../providers/teacher_provider.dart` (it uses `currentTeacherClassesProvider`). The new providers live there, so no new imports needed.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Don't commit yet** — wire-up in Task 15 adds the widget to the layout and the commit will capture both.

---

## Task 15: Wire `_SchoolSummaryCard` into the Class Overview ListView

**Files:**
- Modify: `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`

- [ ] **Step 1: Insert the card at the top of the ListView**

Find the main `ListView(padding: const EdgeInsets.all(16), children: [...])` (around line 70). The current first child is the Summary stats PlayfulCard (`ResponsiveConstraint(maxWidth: 900, child: PlayfulCard(...))`).

Insert `_SchoolSummaryCard` BEFORE the existing summary card:

```dart
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // New: own school summary with global benchmark
                const ResponsiveConstraint(
                  maxWidth: 900,
                  child: _SchoolSummaryCard(),
                ),

                // Existing Summary stats
                ResponsiveConstraint(
                  maxWidth: 900,
                  child: PlayfulCard(
                    // ... unchanged ...
                  ),
                ),
                // ... rest unchanged ...
```

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Manual smoke — teacher**

Log in as `teacher@demo.com`. Open Reports → Class Overview.
- Topmost card is "My School" with rows for Avg XP, Avg Streak, Avg Progress, Books/Student, Active(30d).
- Each numeric row shows the teacher's school value on the right and `global: X` comparison beside it.
- If the school value is above global, the school number is green; otherwise muted grey.
- If global fails to load, only school values show (no error banner).

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/teacher/reports/class_overview_report_screen.dart
git commit -m "feat(teacher-rankings): add My School summary card with global benchmark"
```

---

## Task 16: End-to-end verification + Supabase security tests

**Files:** no code unless regressions surface.

- [ ] **Step 1: Teacher smoke path**

Log in as `teacher@demo.com` and walk:
1. Reports tab opens — all 4 cards visible.
2. **Student Leaderboard** — every card has a league tier badge (32 px) beside the XP/Level column.
3. **Class Overview** — "My School" card at the top with 5 metric rows + global comparisons. Scroll down: sort dropdown next to "Class Performance". Change dropdown to "Avg Streak" → classes reorder + podium moves. With ≥3 classes, gold/silver/bronze badges on top 3.
4. Open a student profile dialog from a class — the league badge inside the dialog looks IDENTICAL to before Task 5's refactor (size + colour + asset unchanged).

- [ ] **Step 2: Supabase security audit**

In the Supabase SQL editor (or via `supabase db remote`), run:

```sql
-- Own-school access should succeed
select * from get_school_summary(<caller_school_id>::uuid) limit 1;

-- Other-school access should raise 'Unauthorized: cannot access another school'
select * from get_school_summary('00000000-0000-0000-0000-000000000000'::uuid);

-- Global averages should work for any authenticated teacher
select * from get_global_student_averages();
```

Confirm:
- Own school query returns 1 row with non-null values (assuming there are students).
- Cross-school query raises the `Unauthorized` exception.
- Global averages succeeds and returns 1 row.

- [ ] **Step 3: Student regression**

Log in as `active@demo.com`:
- Student leaderboard (student-facing, not teacher) still works.
- League tier visible for self is unchanged.
- No performance regression on app open.

- [ ] **Step 4: Static checks**

Run: `dart analyze lib/`
Expected: zero new issues vs. baseline.

Run: `flutter test`
Expected: all existing tests pass + new `class_ranking_metric_test.dart` passes.

- [ ] **Step 5: Final commit if any fixes**

If any fixes were needed in Steps 1-4, commit them with a `fix(teacher-rankings): ...` message. If not, skip.

---

## Self-Review Summary

**Spec coverage:**
- §5 Architecture → Tasks 1-15 implement it.
- §6.1 RPC extension → Task 1.
- §6.2 `get_school_summary` → Task 1 (same migration file).
- §6.3 `get_global_student_averages` → Task 1 (same migration file).
- §7.1 `StudentSummary.leagueTier` → Task 3.
- §7.2 `SchoolSummary` → Task 9.
- §7.3 `GlobalAverages` → Task 9.
- §7.4 Use cases → Task 12.
- §7.5 Repository interface → Task 11.
- §8.1 StudentSummaryModel → Task 4.
- §8.2 New models → Task 10.
- §8.3 Repository impl + RPC constants → Task 11 + Task 2.
- §9.1 Providers → Task 13.
- §9.2 ClassRankingMetric enum → Task 7.
- §9.3 Leaderboard badge → Tasks 5-6.
- §9.4 Class Overview changes → Tasks 8, 14, 15.
- §11 Testing → Tasks 7 (unit), 16 (manual + security).

**Placeholders:** none — every step shows either concrete code or a concrete grep command. A few spots (Task 11 field name `_client` vs `supabase`, Task 12 `NoParams` import path) explicitly tell the engineer to match existing patterns, which is verification guidance, not a placeholder.

**Type consistency:**
- `LeagueTier` used throughout from `package:owlio_shared/owlio_shared.dart`.
- `SchoolSummary` / `GlobalAverages` entity field names consistent across Tasks 9, 10, 14 (totalStudents/activeLast30d/totalXp/avgXp/avgStreak/avgProgress/totalReadingTime/totalBooksRead/totalVocabWords).
- `ClassRankingMetric` enum values (avgXp/avgProgress/avgStreak/totalReadingTime/booksPerStudent) match `TeacherClass` field names exactly — no renaming risk.

**Scope reminder for executor:** This plan produces three features in one deployable unit. If any one task (e.g. migration) blocks the others, Features A and B are independent and can merge without C — deliberate design. Don't split unless forced.
