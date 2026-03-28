# Teacher Dashboard & Reports

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `TeacherStatsModel.fromEntity()` never called (data flows JSON→entity only) | Low | Fixed |
| 2 | Dead Code | `TeacherStatsModel.toJson()` never called | Low | Fixed |
| 3 | Dead Code | `StudentBookProgressModel.fromEntity()` never called | Low | Fixed |
| 4 | Dead Code | `StudentBookProgressModel.toJson()` never called | Low | Fixed |
| 5 | Dead Code | `BookReadingStats.completionRate` getter unused (only `Assignment.completionRate` is used) | Low | Fixed |
| 6 | Code Quality | Unnecessary `teacher.dart` imports in `get_recent_school_activity_usecase.dart` and `get_school_book_reading_stats_usecase.dart` (already re-exported via repository) | Low | Fixed |
| 7 | Performance | `allStudentsLeaderboardProvider` N+1 pattern: fetches N classes sequentially, then N separate `getClassStudents` RPC calls | Medium | TODO |
| 8 | Code Quality | `teacherStudentBadgesProvider`, `teacherStudentCardsProvider`, `wordListWordsProvider` use `List<dynamic>` instead of typed entities | Low | Noted |

### Checklist Result

- Architecture Compliance: **PASS** — screens use providers, providers use use cases, use cases use repository
- Code Quality: **2 issues** (#6 fixed, #8 noted)
- Dead Code: **5 issues** (#1-5 all fixed)
- Database & Security: **PASS** — all RPCs enforce `is_teacher_or_higher()` + school-scoping via `auth.uid()`
- Edge Cases & UX: **PASS** — empty/loading/error states handled in all screens
- Performance: **1 issue** (#7 N+1 in leaderboard provider)
- Cross-System Integrity: **PASS** — read-only feature, no mutations

---

## Overview

The Teacher Dashboard & Reports feature provides teachers with an overview of their school's performance and detailed reports across 4 dimensions: class overview, reading progress, assignment performance, and student leaderboard. The admin panel has a separate surface with system-wide recent activity analytics and content statistics.

## Data Model

### Teacher App (data fetched via RPCs)

No dedicated tables — this feature aggregates from existing tables:

- `profiles` — student/teacher data, XP, level, streak, school_id
- `classes` — class info + computed stats via RPC
- `reading_progress` — per-book reading stats
- `xp_logs` — recent activity feed source
- `assignments` / `assignment_students` — assignment performance data

### Admin Panel (direct queries)

Aggregates counts/lists from: `books`, `chapters`, `vocabulary_words`, `inline_activities`, `scope_learning_paths`, `profiles`, `inline_activity_results`, `reading_progress`, `xp_logs`

### Key RPCs

| RPC Function | Purpose | Auth |
|-------------|---------|------|
| `get_teacher_stats` | Dashboard summary (students, classes, assignments, avg progress) | `auth.uid() = p_teacher_id` + `is_teacher_or_higher()` |
| `get_classes_with_stats` | Class list with enriched stats (XP, streak, reading time, vocab, activity) | `is_teacher_or_higher()` + school-scoped |
| `get_students_in_class` | Student list with XP, level, streak, books read | `is_teacher_or_higher()` + school-scoped |
| `get_school_book_reading_stats` | Per-book reader/completion counts for school | `is_teacher_or_higher()` + school-scoped |
| `get_recent_school_activity` | Last 7 days of XP events from school students | `is_teacher_or_higher()` + school-scoped |
| `get_assignments_with_stats` | All teacher assignments with student counts | teacher-scoped |

## Surfaces

### Admin

**Dashboard** (`/`): Grid of 11 cards showing system-wide counts (books, schools, users, badges, vocabulary, learning paths, quests). Each card links to its management page.

**Recent Activity** (`/recent-activity`): Two-column layout showing 11 sections:
- Content: recently added books, chapters, words, inline activities, learning path assignments
- Users: new users, active users, completed activities, reading progress, XP logs
- Summary: today's active users, weekly total XP
- Each section shows latest 10 items with "View All" linking to paginated detail page (50 per page)

### Student

N/A — students do not see teacher dashboard or reports.

### Teacher

**Dashboard** (`/teacher`):
- Welcome header with time-based greeting
- Quick actions: New Assignment, Reports, Manage Classes, Leaderboard
- Stats grid: Total Students, Total Classes, Active Assignments, Avg Progress
- Recent Activity feed: last 10 XP events from school students (filtered to exclude noise)
- Responsive: 2-column on wide screens, single column on narrow

**Reports Hub** (`/teacher/reports`):
- Quick stats summary (same data as dashboard)
- 4 report type cards linking to detail screens

**Report: Class Overview** (`/teacher/reports/class-overview`):
- School-level summary: active students (30d), avg XP, total reading time, highest streak
- Per-class cards with: grade badge, student count, avg progress bar, metric chips (avg XP, avg streak, books/student, reading time, words mastered, activity rate)
- Tap → class detail screen (in report mode)

**Report: Reading Progress** (`/teacher/reports/reading-progress`):
- Summary: total books, books being actively read
- Per-book cards with: cover image, level badge, reader count, completed count, circular avg progress indicator

**Report: Assignment Performance** (`/teacher/reports/assignments`):
- Overall: total assignments, completed/total students, avg completion rate
- Per-assignment cards with: type icon, title, class name, status badge, completion progress bar, due date
- Tap → assignment detail screen

**Report: Student Leaderboard** (`/teacher/reports/leaderboard`):
- All students across all teacher's classes, ranked by XP descending
- Top 3 get medal icons (gold/silver/bronze)
- Each row: rank, avatar, name, streak, books read, XP, level
- Tap → student profile

## Business Rules

1. **School scoping**: All teacher data is scoped to the teacher's `school_id`. A teacher cannot view data from other schools. RPCs enforce this via `auth.uid()` lookup.
2. **Active assignments**: Counted as assignments where `due_date >= NOW()` (not expired).
3. **Avg progress**: Calculated as average `completion_percentage` across all `reading_progress` rows for students in the school.
4. **Recent activity source**: Uses `xp_logs` table — every XP-earning event creates a log entry. Activity feed shows last 7 days, limited to 20 entries.
5. **Activity filtering (dashboard)**: Client-side filters out entries with `activityType = 'activity'`, `'manual'`, or description containing "xp awarded" to reduce noise, then takes top 10.
6. **Leaderboard aggregation**: Currently fetches students per-class then merges client-side (N+1 pattern — see Known Issues).
7. **Admin recent activity**: Not school-scoped — admin sees all data across all schools. Uses RLS (admin role has full SELECT).
8. **Admin detail pagination**: 50 items per page with "Load More" button (not infinite scroll).

## Cross-System Interactions

This is a **read-only** feature — it does not trigger any side effects.

**Data consumed from:**
- XP/Leveling (#9): `xp_logs` for activity feed, `profiles.xp` for leaderboard ranking
- Streak (#10): `profiles.current_streak` shown in class overview and leaderboard
- Assignment System (#17): `assignments`/`assignment_students` for assignment performance report
- Book System (#1): `reading_progress` for reading stats, `books` for library listing
- Vocabulary (#5): `vocabulary_progress` word counts via class stats RPC
- Class Management (#18): `classes` for class listing and student grouping

## Edge Cases

- **Teacher with no school**: Stats return 0s, class/activity lists return empty arrays
- **Teacher with no classes**: Class overview shows "No classes found" empty state
- **Teacher with no assignments**: Assignment report shows "No assignments yet" empty state
- **No students in school**: Leaderboard shows "No students found" empty state
- **No reading data**: Reading progress report shows book cards with 0 readers
- **No recent XP events**: Dashboard activity feed shows "No recent activity" with helper text
- **Admin empty sections**: Shows "Henüz veri yok" (no data yet) per section
- **RPC failure**: All report screens show ErrorStateWidget with retry button

## Test Scenarios

- [ ] **Dashboard loads**: Teacher sees stats, quick actions, and recent activity
- [ ] **Dashboard refresh**: Pull-to-refresh invalidates stats + activity providers
- [ ] **Class Overview**: Shows all classes with enriched metric chips
- [ ] **Reading Progress**: Shows all books with reader counts and avg progress circles
- [ ] **Assignment Report**: Shows all assignments with completion bars and status badges
- [ ] **Leaderboard**: Shows all students sorted by XP, top 3 with medals
- [ ] **Empty school**: All reports show appropriate empty states
- [ ] **RPC error**: All reports show error state with working retry button
- [ ] **Admin dashboard**: Shows correct counts for all 9 stat categories
- [ ] **Admin recent activity**: Shows 11 sections with latest 10 entries each
- [ ] **Admin detail pagination**: "Tümünü Gör" navigates to paginated detail, "Daha Fazla Yükle" loads next 50
- [ ] **Cross-school isolation**: Teacher A cannot see Teacher B's school data
- [ ] **Responsive layout**: Dashboard switches between 2-column (wide) and single column (narrow)

## Key Files

### Teacher App
- `lib/presentation/screens/teacher/dashboard_screen.dart` — main dashboard
- `lib/presentation/screens/teacher/reports_screen.dart` — reports hub
- `lib/presentation/screens/teacher/reports/` — 4 report screens
- `lib/presentation/providers/teacher_provider.dart` — all dashboard/report providers
- `lib/domain/entities/teacher.dart` — TeacherStats, TeacherClass, StudentSummary, BookReadingStats, RecentActivity
- `lib/data/repositories/supabase/supabase_teacher_repository.dart` — RPC calls

### Admin Panel
- `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart` — admin dashboard with counts
- `owlio_admin/lib/features/recent_activity/screens/recent_activity_screen.dart` — 11-section activity view
- `owlio_admin/lib/features/recent_activity/screens/recent_activity_detail_screen.dart` — paginated detail

### Database
- `supabase/migrations/20260316000003_fix_teacher_stats_auth.sql` — `get_teacher_stats` RPC
- `supabase/migrations/20260325000009_school_book_reading_stats_rpc.sql` — `get_school_book_reading_stats` RPC
- `supabase/migrations/20260325000011_recent_school_activity_rpc.sql` — `get_recent_school_activity` RPC

## Known Issues & Tech Debt

1. **N+1 in leaderboard provider** (`allStudentsLeaderboardProvider`): Fetches N classes, then N separate `getClassStudents` calls. Should be replaced with a single `get_school_leaderboard` RPC that returns all students for a school sorted by XP. Impact is low for small schools but will degrade as class count grows.
2. **Untyped providers**: `teacherStudentBadgesProvider`, `teacherStudentCardsProvider`, and `wordListWordsProvider` use `List<dynamic>` instead of typed entities. Low risk since these are display-only but reduces IDE support and type safety.
3. **Admin 12-query parallel fetch**: `recentActivityProvider` fires 12 simultaneous Supabase queries. Works fine with `Future.wait` parallelism but could be consolidated into fewer RPCs if response time becomes an issue.
