# Teacher Rankings — Design Spec

**Date:** 2026-04-17
**Status:** Draft (awaiting user review)
**Target:** Owlio Mobile (Flutter) — teacher role reports

---

## 1. Summary

Three ranking-related additions to the teacher Reports section:
1. **Student league tier badges** inside the existing Student Leaderboard (bronze/silver/gold/platinum/diamond next to XP).
2. **Class ranking** in the existing Class Overview — teacher picks a metric (avg XP, avg progress, avg streak, total reading time, books per student), classes are sorted client-side, podium badges (gold/silver/bronze) on the top 3.
3. **School summary card** at the top of Class Overview — the teacher's own school's aggregate stats alongside a global benchmark computed across all students in the platform.

No new screens. All three features are surgical additions to two existing reports.

---

## 2. Goals

- Make the student leaderboard useful at a glance by surfacing league tier.
- Let teachers rank their classes by whatever metric they care about that day.
- Give teachers an answer to "how is my school doing overall, and how does it compare?" without crossing into other-school data.

## 3. Non-goals

- Cross-school rankings of any kind (teachers NEVER see another school's name, students, or detailed stats).
- Grade-level or subscription-tier-specific benchmarks (Phase 2 candidate).
- Historical/temporal ranking (this-week vs last-week diff) — Phase 2.
- Composite weighted ranking score.
- Change to the student-facing league system, leaderboard, or any student UI.

---

## 4. User Stories

- As a teacher, I open the Student Leaderboard and see a league tier badge beside each student's XP so I can quickly scan which students are in top tiers.
- As a teacher, I open Class Overview, pick "avg streak" from a sort dropdown, and immediately see my classes ranked by streak with podium badges on the top three.
- As a teacher, at the top of Class Overview I see "My School" stats (total XP, avg streak, active%, reading time, etc.) and next to each metric a small "(national avg: X)" comparison so I know whether my school is above or below the platform-wide average.

---

## 5. Architecture Overview

**Approach:** Minimal-surface extension of existing reports. Three independent pieces. The common thread is teacher's `schoolId` — supplied from `User.schoolId` already on the authenticated user. Pieces (a) and (c) need new RPCs + providers; piece (b) is pure client-side sort + overlay on existing data.

### Data flow per feature

**(a) League tier badge:**
`LeaderboardReportScreen` → `allStudentsLeaderboardProvider` → `TeacherRepository.getSchoolStudents(schoolId)` → `get_school_students_for_teacher(p_school_id)` RPC (UPDATED to include `league_tier`) → `StudentSummary` (EXTENDED with `leagueTier` field) → `_LeaderboardCard` renders badge using existing `LeagueTier` enum + asset mapping from `student_profile_dialog.dart`.

**(b) Class ranking by metric:**
`ClassOverviewReportScreen` adds a local `ClassRankingMetric` state (default `avgXp`). A `DropdownButton` at the top changes this state. Classes from `currentTeacherClassesProvider` (unchanged RPC) are sorted client-side by the selected metric. The first 3 cards receive a podium icon (gold/silver/bronze) overlay. No RPC change — `TeacherClass` entity already has every sortable metric.

**(c) School summary + global benchmark:**
`ClassOverviewReportScreen` renders a new `_SchoolSummaryCard` at the top that watches two providers:
- `schoolSummaryProvider(schoolId)` → `get_school_summary(p_school_id)` RPC → `SchoolSummary` entity
- `globalAveragesProvider` (no param) → `get_global_student_averages()` RPC → `GlobalAverages` entity

Each metric row shows the school's value and below/beside it a "national avg: X" comparison in muted text. Colour-coded: above benchmark = green, below = subtle grey.

### Why three separate pieces

The three features touch different domains and could be shipped independently. Bundling them into one plan is purely delivery convenience — if one piece hits a snag, the other two can still merge.

---

## 6. Database Changes

Single migration file: `supabase/migrations/YYYYMMDDHHMMSS_teacher_rankings.sql` containing three changes.

### 6.1 Extend `get_school_students_for_teacher`

Current function (file `supabase/migrations/20260328500001_...sql`) returns student rows without `league_tier`. Redefine with `CREATE OR REPLACE FUNCTION` so the `league_tier` column is selected from `profiles` and returned in the `RETURNS TABLE` signature.

- Return-type change is **additive** — columns only grow; existing callers tolerant.
- Security, RLS, school-scope check: unchanged.

### 6.2 New `get_school_summary(p_school_id UUID)`

Returns a single row with aggregates for the teacher's own school:

```sql
RETURNS TABLE (
  total_students      INT,
  active_last_30d     INT,
  total_xp            BIGINT,
  avg_xp              NUMERIC,
  avg_streak          NUMERIC,
  avg_progress        NUMERIC,
  total_reading_time  BIGINT,
  total_books_read    INT,
  total_vocab_words   INT
)
```

`SECURITY DEFINER`. Caller's `school_id` is loaded from `profiles` via `auth.uid()` and must equal `p_school_id`, otherwise `RAISE EXCEPTION 'Unauthorized: cannot access another school'` — same pattern as `get_school_students_for_teacher`.

Implementation: **reuse the exact aggregation SQL** from `get_classes_with_stats` (migration `20260327000003_enrich_class_overview_stats.sql`) — that function already computes per-class aggregates using lateral joins to `reading_progress`, `book_quiz_attempts`, and `vocab_progress`. The school-summary implementation rolls those same computations up one level: `FROM profiles WHERE school_id = p_school_id AND role = 'student'` and aggregate over all matching rows instead of grouping by class.

`active_last_30d` uses identical logic: count students where `last_activity_date >= NOW() - INTERVAL '30 days'`. Any semantic difference between school-summary and class-stats would cause teachers to see inconsistent numbers across the same page — re-use the query, don't re-derive.

### 6.3 New `get_global_student_averages()`

Returns a single row with platform-wide averages:

```sql
RETURNS TABLE (
  avg_xp            NUMERIC,
  avg_streak        NUMERIC,
  avg_progress      NUMERIC,
  avg_reading_time  NUMERIC,
  avg_books_read    NUMERIC
)
```

`SECURITY DEFINER`. No school-scope check — this function exposes ONLY averages (no identifiable data), readable by any authenticated teacher. Excluded from the aggregate: soft-deleted users, users with `role != 'student'`, test/demo accounts if a flag exists.

Implementation: single `SELECT AVG(...) FROM profiles WHERE role = 'student'`.

**Exclusions** — run `grep -n "is_demo\|is_test\|demo_account" supabase/migrations/` in implementation; if any boolean flag exists on `profiles` marking demo/test accounts, add it to the WHERE (`AND COALESCE(is_demo, false) = false`). If no such flag exists, skip this exclusion (v1 accepts that demo accounts are in the average; they're a small fraction).

**Performance:** Demo-scale (<10k students) completes in milliseconds. Not cached. If scale becomes a concern, add a nightly materialized view refresh — not in scope for v1.

### 6.4 Rollback

Dropping these functions + removing `league_tier` from the return signature of 6.1 is safe. No new data is written — only reads.

---

## 7. Domain Changes

All in `lib/domain/entities/teacher.dart` (locality: sibling of `TeacherClass`, `StudentSummary`, etc.).

### 7.1 Extend `StudentSummary`

Add required field:
```dart
final LeagueTier leagueTier;
```

Constructor parameter required. Equatable `props` updated. Default fallback `LeagueTier.bronze` only in the model layer if `league_tier` somehow arrives null (defensive — schema has `NOT NULL DEFAULT 'bronze'` so this is belt-and-braces).

### 7.2 New `SchoolSummary` entity

```dart
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
    totalStudents, activeLast30d, totalXp, avgXp, avgStreak,
    avgProgress, totalReadingTime, totalBooksRead, totalVocabWords,
  ];
}
```

### 7.3 New `GlobalAverages` entity

```dart
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

### 7.4 New use cases

- `GetSchoolSummaryUseCase` taking `GetSchoolSummaryParams({required String schoolId})`, returning `Future<Either<Failure, SchoolSummary>>`.
- `GetGlobalAveragesUseCase` taking `NoParams`, returning `Future<Either<Failure, GlobalAverages>>`.

Both live under `lib/domain/usecases/teacher/`.

### 7.5 Repository interface

Add two methods to `TeacherRepository` (`lib/domain/repositories/teacher_repository.dart`):

```dart
Future<Either<Failure, SchoolSummary>> getSchoolSummary(String schoolId);
Future<Either<Failure, GlobalAverages>> getGlobalAverages();
```

---

## 8. Data Layer

### 8.1 Model changes

`lib/data/models/teacher/student_summary_model.dart`:
- Add `leagueTier` to `fromJson` (parse `league_tier` string → `LeagueTier` enum via existing `LeagueTier.fromString` helper).
- Add to `toEntity` and `toJson`.

### 8.2 New models

- `lib/data/models/teacher/school_summary_model.dart` — `fromJson`, `toEntity`, `toJson`.
- `lib/data/models/teacher/global_averages_model.dart` — same shape.

### 8.3 Repository implementation

`lib/data/repositories/supabase/supabase_teacher_repository.dart` (or equivalent):
- Implement `getSchoolSummary` — calls `supabase.rpc(RpcFunctions.getSchoolSummary, params: {'p_school_id': schoolId})`, parses single-row response.
- Implement `getGlobalAverages` — calls `supabase.rpc(RpcFunctions.getGlobalStudentAverages)`, parses single-row response.

Add RPC name constants to `packages/owlio_shared/lib/src/constants/rpc_functions.dart`:
```dart
static const getSchoolSummary = 'get_school_summary';
static const getGlobalStudentAverages = 'get_global_student_averages';
```

---

## 9. Presentation Layer

### 9.1 Providers

`lib/presentation/providers/teacher_provider.dart`:

```dart
final schoolSummaryProvider = FutureProvider.autoDispose
    .family<SchoolSummary, String>((ref, schoolId) async {
  final useCase = ref.watch(getSchoolSummaryUseCaseProvider);
  final result = await useCase(GetSchoolSummaryParams(schoolId: schoolId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (summary) => summary,
  );
});

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

Wire `getSchoolSummaryUseCaseProvider` and `getGlobalAveragesUseCaseProvider` in `usecase_providers.dart`, and the repository in `repository_providers.dart` (usual one-line boilerplate).

### 9.2 `ClassRankingMetric` enum

New file `lib/presentation/utils/class_ranking_metric.dart` (presentation-layer only):

```dart
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
      case ClassRankingMetric.avgXp: return 'Avg XP';
      case ClassRankingMetric.avgProgress: return 'Avg Progress';
      case ClassRankingMetric.avgStreak: return 'Avg Streak';
      case ClassRankingMetric.totalReadingTime: return 'Total Reading Time';
      case ClassRankingMetric.booksPerStudent: return 'Books / Student';
    }
  }

  Comparable<num> Function(TeacherClass) get selector {
    switch (this) {
      case ClassRankingMetric.avgXp: return (c) => c.avgXp;
      case ClassRankingMetric.avgProgress: return (c) => c.avgProgress;
      case ClassRankingMetric.avgStreak: return (c) => c.avgStreak;
      case ClassRankingMetric.totalReadingTime: return (c) => c.totalReadingTime;
      case ClassRankingMetric.booksPerStudent: return (c) => c.booksPerStudent;
    }
  }
}
```

### 9.3 `LeaderboardReportScreen` changes

`lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart`:

In `_LeaderboardCard`, after the "XP and Level" column (currently lines 171-205), inject a league tier badge. Reuse the asset/color mapping already defined in `lib/presentation/widgets/common/student_profile_dialog.dart:98-122` by extracting it into a small helper widget `LeagueTierBadge(tier)` placed under `lib/presentation/widgets/common/league_tier_badge.dart`. Both screens reference it — DRY.

Badge size in leaderboard: 32×32 (compact). In profile dialog keep existing size.

### 9.4 `ClassOverviewReportScreen` changes

`lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`:

**(a) New `_SchoolSummaryCard` widget** placed BEFORE the existing summary `_SummaryStat` row (top of ListView, above `Class Performance` heading). Watches both providers. Shows ~5 metric rows, each with: metric label, my-school value, national avg in small muted text, up/down chevron coloured green/grey.

**(b) Convert to `ConsumerStatefulWidget`** (currently `ConsumerWidget`) to hold the selected `ClassRankingMetric` state. Default `ClassRankingMetric.avgXp`.

**(c) Sort dropdown** rendered right above the `Class Performance` heading:
```
Row: "Sort by: "  [DropdownButton<ClassRankingMetric>]
```

**(d) Sort class list client-side:**
```dart
final sortedClasses = [...classes]
  ..sort((a, b) => metric.selector(b).compareTo(metric.selector(a)));
```

**(e) Podium badges on top 3 cards:** extend `_EnrichedClassCard` with optional `int? rank` param. If `rank` in {1, 2, 3}, overlay a small icon (`Icons.emoji_events_rounded`) in the top-right corner with tier-specific colour (gold #FFD700, silver #C0C0C0, bronze #CD7F32). Render only when `classes.length >= 3` — with fewer classes, ranking is meaningless so badges hidden.

---

## 10. File Manifest

### New (6)

- `supabase/migrations/YYYYMMDDHHMMSS_teacher_rankings.sql`
- `lib/domain/usecases/teacher/get_school_summary_usecase.dart`
- `lib/domain/usecases/teacher/get_global_averages_usecase.dart`
- `lib/data/models/teacher/school_summary_model.dart`
- `lib/data/models/teacher/global_averages_model.dart`
- `lib/presentation/utils/class_ranking_metric.dart`
- `lib/presentation/widgets/common/league_tier_badge.dart`

### Modified (9)

- `packages/owlio_shared/lib/src/constants/rpc_functions.dart`
- `lib/domain/entities/teacher.dart` — `StudentSummary.leagueTier` + `SchoolSummary` + `GlobalAverages`
- `lib/data/models/teacher/student_summary_model.dart`
- `lib/domain/repositories/teacher_repository.dart`
- `lib/data/repositories/supabase/supabase_teacher_repository.dart` (or current location)
- `lib/presentation/providers/repository_providers.dart` (one-line)
- `lib/presentation/providers/usecase_providers.dart` (two-lines)
- `lib/presentation/providers/teacher_provider.dart` — two new FutureProviders
- `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart` — badge in card
- `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart` — summary card + sort + podium
- `lib/presentation/widgets/common/student_profile_dialog.dart` — extracted badge logic reused from new `LeagueTierBadge` widget

### Unchanged

- All student-facing screens and widgets
- Other teacher reports (reading progress, assignment performance)
- `TeacherClass` entity — already has every sortable metric
- `currentTeacherClassesProvider` — unchanged RPC
- Any student leaderboard, league-history, or league-tier update code path

---

## 11. Testing / Verification Plan

### 11.1 Unit tests
- `GetSchoolSummaryUseCase` and `GetGlobalAveragesUseCase` — mock repo, verify plumbing.
- `ClassRankingMetric.selector` for each enum value — verify correct field is returned.
- `StudentSummaryModel.fromJson` — verify `league_tier` parsed as enum for each of 5 values + default fallback for missing/null.

### 11.2 Widget tests
- `LeagueTierBadge(LeagueTier.gold)` renders gold asset. One test per tier is sufficient.
- `_SchoolSummaryCard` with mocked providers renders all metric rows + "national avg" suffix.

### 11.3 Manual smoke (teacher flow)
- Log in as `teacher@demo.com`. Open Reports → Student Leaderboard. Each card has a league badge beside XP.
- Open Reports → Class Overview. Top section shows "My School" summary with national-avg comparisons. Sort dropdown visible. Changing selection re-orders classes and moves podium badges accordingly.
- With <3 classes, podium badges do not render.
- With 3+ classes, top 3 have gold/silver/bronze icons; 4+ have none.
- `dart analyze lib/` passes with zero new issues.

### 11.4 Security verification
- Call `get_school_summary(other_school_id)` from a teacher whose `profiles.school_id != other_school_id` — expect `Unauthorized` exception.
- Call `get_global_student_averages()` as an unauthenticated session — expect auth failure. As any authenticated teacher — expect success.
- Query `get_school_students_for_teacher` for the caller's own school — response includes `league_tier` for every row.

### 11.5 Regression
- Student-facing leaderboard (`LeaderboardScreen`) unchanged — all tiers, all sort modes, badge awards, league promotions/demotions still work.
- Admin panel's student views unchanged.
- No new rows written to the DB by teacher session (no progress/xp/league writes — these are read-only RPCs).

---

## 12. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `get_global_student_averages` slow at scale | Demo-size is fine. If >50k students, add materialized view with nightly refresh (separate migration, not in v1 scope). |
| "National average" is meaningless if platform mixes grade levels (e.g. high school + primary) | Acceptable v1 trade-off; add a disclaimer "(across all schools)" in UI. Phase 2: grade-level benchmark. |
| Podium badges look silly with 1-2 classes | Only render when `classes.length >= 3`. |
| `StudentSummary.leagueTier` being required is a breaking change for ad-hoc constructors in tests | Add tests adopting the new field. `LeagueTier.bronze` is a sensible default for fixture builders. |
| `LeagueTierBadge` extraction moves code out of `student_profile_dialog.dart`, could miss an edge case | Diff the extraction carefully; keep existing dialog's visual output byte-identical. |
| RPC name collisions | Names are namespaced with `get_*` prefix; verified no existing function with these names via `grep` in `supabase/migrations/`. |

---

## 13. Out-of-Scope Follow-ups

- Grade-level benchmark (avg per grade level rather than across all students)
- Historical ranking trends (this week vs last week, podium movement)
- School-vs-school (anonymous) rankings
- Teacher-customisable ranking weight composite
- Export rankings to CSV / PDF
- Student-level league history in teacher panel (already partly in student profile dialog — not extended here)

---

## 14. Open Questions

*(Filled during review; none at time of writing.)*
