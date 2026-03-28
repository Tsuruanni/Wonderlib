# Student Management

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `resetStudentPasswordUseCaseProvider` registered but never called — full stack (UseCase → Repository → Edge Function) with no UI trigger | Medium | Fixed (removed entire stack: UseCase, provider, repo method, Edge Function) |
| 2 | Code Quality | `_getRoleColor` and `_getRoleLabel` duplicated in `user_list_screen.dart` and `user_edit_screen.dart` — raw string switch instead of using `UserRole` enum | Low | Fixed (extracted to `core/utils/role_helpers.dart`) |
| 3 | Code Quality | `_Chip` widget duplicated identically in `user_list_screen.dart:437–464` and `class_list_screen.dart:287–314` | Low | Skipped (minor) |
| 4 | Code Quality | `allSchoolsProvider` defined in `user_list_screen.dart:55` but imported by `class_edit_screen.dart` and `class_list_screen.dart` — inverted dependency; should live in `shared_providers.dart` | Low | Skipped (admin panel convention) |
| 5 | Code Quality | Three separate schools providers (`allSchoolsProvider`, `createSchoolsProvider`, `schoolClassesProvider`) and three classes providers with minor column differences — could consolidate | Low | Skipped (admin panel convention) |
| 6 | Dead Code | Admin class management screens (`class_list_screen.dart`, `class_edit_screen.dart`) exist but have no routes registered in `router.dart` — unreachable dead code | Medium | Fixed (routes registered, dashboard card added) |
| 7 | Security | `password_plain` displayed in admin edit screen and returned by `get_students_in_class` RPC — intentional for school use case but could become stale if a password reset mechanism is added in the future | Low | Resolved (reset mechanism removed in #1; no stale password path exists) |
| 8 | Code Quality | `UserModel` has local `parseRole`/`roleToString` switch that duplicates `UserRole.fromDbValue`/`UserRole.dbValue` from shared package | Low | Skipped (works correctly) |
| 9 | Code Quality | `TeacherClassModel` has unused fields (`avgXp`, `avgStreak`, `totalReadingTime`, etc.) that RPC `get_classes_with_stats` doesn't return — always default to `0` | Low | Skipped (future-proofing, harmless) |
| 10 | Architecture | Teacher screens import domain types directly (`teacher_repository.dart`, UseCase param classes) instead of through re-exported provider types | Low | Skipped (Dart convention — entity imports are standard) |
| 11 | Edge Case | `_showSingleStudentMoveSheet` in `class_detail_screen.dart:398` — initially flagged as wrong context check, but verified correct: `context` is the screen's State.context passed as method parameter, not the sheet builder's context | Low | Skipped (false positive) |
| 12 | Code Quality | Hard-coded Edge Function name `'bulk-create-students'` in `user_create_screen.dart:90` — no shared constant registry for Edge Functions | Low | Skipped (no EdgeFunctions constant class exists yet) |
| 13 | Code Quality | `StudentDetailScreen` duplicates 4-provider invalidation logic in both `RefreshIndicator.onRefresh` and `ErrorStateWidget.onRetry` | Low | Skipped (minor) |

### Checklist Result

- Architecture Compliance: **PASS** — Main app follows Screen → Provider → UseCase → Repository; admin panel uses intentionally flat architecture (no UseCases, providers co-located with screens)
- Code Quality: **PASS** — role helpers extracted to shared utility (#2 fixed); password_plain stale issue resolved by removing reset mechanism (#7 resolved); context check verified correct (#11 false positive)
- Dead Code: **PASS** — unused reset password stack removed (#1 fixed); admin class screens now routable (#6 fixed)
- Database & Security: **PASS** — RLS policies cover profiles/schools/classes; all teacher RPCs enforce `is_teacher_or_higher()`; `get_school_students_for_teacher` validates school-match; `safe_profiles` view hides sensitive fields for peer display; composite index `(class_id, role)` covers student enumeration
- Edge Cases & UX: **PASS** — empty/loading/error states handled across all screens; null-safe data parsing; CSV import handles Turkish and English headers; duplicate detection on bulk create
- Performance: **PASS** — no N+1 (stats aggregated in RPCs); student lists paginate via RPC limits; indexes on `profiles(school_id)`, `profiles(class_id)`, `profiles(class_id, role)`
- Cross-System Integrity: **PASS** — class transfer triggers `on_student_class_change` (withdraws old assignments, enrolls in new); XP/level reset in admin is a direct profile update (no cascade needed)

---

## Overview

Student Management provides individual student lifecycle operations across two surfaces. **Admin** manages all users (students, teachers, heads) with full CRUD, tabbed detail views (profile, progress, cards), bulk CSV import, and account reset capabilities. **Teachers** view student details (reading progress, vocabulary stats, badges, quiz results, card collection) and access stored credentials for password distribution. Students have no self-management surface beyond their profile screen (covered in Feature #22).

## Data Model

### Tables

**`profiles`** — Core user record (students, teachers, heads, admins)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | FK → auth.users CASCADE |
| school_id | UUID FK → schools | nullable |
| class_id | UUID FK → classes | ON DELETE SET NULL |
| role | VARCHAR(20) NOT NULL | CHECK: `student`, `teacher`, `head`, `admin` |
| first_name | VARCHAR(100) | |
| last_name | VARCHAR(100) | |
| email | VARCHAR(255) | synthetic `username@owlio.local` for students |
| student_number | VARCHAR(50) | UNIQUE per school |
| password_plain | TEXT | stored on creation for credential cards; becomes stale after reset |
| xp | INTEGER DEFAULT 0 | |
| level | INTEGER DEFAULT 1 | |
| coins | INTEGER DEFAULT 0 | |
| current_streak | INTEGER DEFAULT 0 | |
| longest_streak | INTEGER DEFAULT 0 | |
| last_activity_date | DATE | |
| avatar_url | TEXT | |
| league_tier | VARCHAR(20) | |
| streak_freeze_count | INTEGER DEFAULT 0 | |
| unopened_packs | INTEGER DEFAULT 0 | |
| settings | JSONB DEFAULT '{}' | |

**`schools`** — Organizational container (documented in spec #18)

**`classes`** — Student grouping unit (documented in spec #18)

### Key Relationships

- `auth.users` 1:1 `profiles` (CASCADE delete; auto-created via `handle_new_user` trigger)
- `profiles` N:1 `schools` (student belongs to one school)
- `profiles` N:1 `classes` (student belongs to one class; SET NULL on class delete)

### Indexes

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_profiles_school` | `(school_id)` | School-scoped queries |
| `idx_profiles_class` | `(class_id)` | Class roster lookups |
| `idx_profiles_role` | `(role)` | Role-filtered queries |
| `idx_profiles_xp` | `(xp DESC)` | Leaderboard ranking |
| `idx_profiles_class_role` | `(class_id, role)` | `get_students_in_class` optimization |
| `idx_profiles_last_activity` | `(last_activity_date)` WHERE NOT NULL | Activity-based queries |

## Surfaces

### Admin

**User List** (`owlio_admin/lib/features/users/screens/user_list_screen.dart`)
- Multi-filter: school dropdown → cascading class dropdown → role dropdown
- Server-side filtering via PostgREST `.eq()` chaining (no client-side text search)
- Displays: name, @username, role chip, school name, level + XP
- Changing school filter auto-resets class filter

**User Create** (`owlio_admin/lib/features/users/screens/user_create_screen.dart`)
- **Single tab**: toggle student/teacher mode; student requires school + class (existing or new); teacher requires real email
- **Bulk CSV tab**: file picker → CSV parse → preview (first 50 rows) → batched submission (chunks of 200)
- CSV accepts Turkish (`ad`, `soyad`, `sınıf`) and English (`first_name`, `last_name`, `class_name`) headers
- Calls `bulk-create-students` Edge Function which:
  - Auto-generates username via `generate_username` DB function
  - Generates `word+NNN` password (e.g., `owl427`)
  - Creates Supabase Auth user with synthetic email `username@owlio.local`
  - Stores `password_plain` in profiles for credential card printing
  - Handles duplicate detection (same first+last name in same class)
  - Retries username uniqueness (3-attempt loop on constraint violation)
- Results table displays username + generated password with one-time warning banner
- CSV download exports created users with BOM-prefixed UTF-8 for Excel compatibility

**User Edit** (`owlio_admin/lib/features/users/screens/user_edit_screen.dart`) — 3-tab detail view:
- **Profile tab**: edit first name, last name, role, school, student number; read-only email/username/password_plain
- **Progress tab**: reading progress DataTable (book, level, completion%, date); badge chips; quiz results DataTable (quiz, score, pass/fail, date)
- **Cards tab**: card collection grouped by `CardCategory`, rarity-colored chips, unique vs total count stats
- **Danger Zone**: reset XP/level/streak to baseline (direct `profiles` UPDATE with confirmation dialog)

### Student

N/A — students manage their own profile via the Profile screen (Feature #22).

### Teacher

**Student Detail** (`lib/presentation/screens/teacher/student_detail_screen.dart`)
- Full read-only academic profile with 8 data sections loaded via 6 concurrent providers:
  - Header: avatar, full name, student number, streak info
  - Level & XP card: level badge, total XP, progress bar
  - Reading progress: horizontal scroll of book cards (cover, chapters, reading time)
  - Quiz results: horizontal cards (book title, best score, attempts, pass/fail)
  - Vocabulary stats: 4 aggregate counts (total, mastered, learning, sessions)
  - Word lists: horizontal cards with word chips, star rating, accuracy
  - Badges: earned badge list
  - Card collection: myth cards sorted by rarity

**Password Access** (via class roster bottom sheet in `class_detail_screen.dart`)
- Bottom sheet displays `student.passwordPlain` from `get_students_in_class` RPC response
- Teacher can copy password for credential distribution
- No password reset mechanism exists — teachers distribute the original password created at account creation

**Class Transfer** (documented in spec #18 — `BulkMoveStudentsUseCase`)

## Business Rules

1. **Username generation**: Server-side `generate_username` function creates unique usernames; on collision, retries up to 3 times with regeneration
2. **Student email is synthetic**: `username@owlio.local` — not a real email; prevents Supabase Auth from sending emails to students
3. **`password_plain` lifecycle**: Written at account creation; no reset mechanism exists — password is immutable once created
4. **Role hierarchy for management**: `is_teacher_or_higher()` gates all student management RPCs; admin/head can manage teachers; teachers can only manage students
5. **School-scoped access**: Teacher RPCs validate `profiles.school_id` matches caller's school — no cross-school student access
6. **Danger Zone reset**: Admin can reset XP, level, streak to baseline; this is a direct UPDATE — no XP reversal log entries are created
7. **Bulk create batching**: CSV imports batch in chunks of 200 to avoid Edge Function timeout
8. **Duplicate detection**: Bulk create checks for existing students with same first+last name in same class before creating
9. **Class-less students**: If a student's class is deleted, `class_id` becomes NULL (SET NULL FK); student remains in school but loses class-specific assignments and learning paths

## Cross-System Interactions

- **Admin XP/level reset** → Directly clears `profiles.xp`, `profiles.level`, `profiles.current_streak` — no cascade to `xp_logs`, `coin_logs`, `league_history` (historical records remain)
- **Student creation** → `handle_new_user` trigger auto-inserts `profiles` row on `auth.users` insert; Edge Function then updates profile fields (school, class, name, etc.)
- **Class transfer** → Triggers `on_student_class_change` which withdraws old assignments and enrolls in new class learning paths (documented in spec #18)

## Edge Cases

- **Bulk create failures**: If username generation fails after 3 retries, that specific student is skipped. Partial success is possible — results table shows which users were created.
- **No text search in admin user list**: Finding a specific user requires knowing their school/class. Large user bases may be difficult to navigate.
- **No password change mechanism**: Students and teachers cannot change student passwords. The only credential is the `password_plain` stored at account creation.

## Test Scenarios

- [ ] **Happy path — Admin create single student**: Create student with school + class → verify username + password generated → verify user appears in list → verify login works
- [ ] **Happy path — Admin bulk CSV import**: Upload CSV with 5+ students → verify preview table → submit → verify all created → download CSV results
- [ ] **Happy path — Admin edit profile**: Change student name/role/school → save → verify change persists
- [ ] **Happy path — Teacher view student detail**: Open student from class roster → verify all 8 sections load (progress, vocab, badges, cards, etc.)
- [ ] **Happy path — Teacher view password**: Open student info sheet → verify `password_plain` is displayed and copyable
- [ ] **Edge case — Duplicate student**: Bulk create with same first+last name in same class → verify duplicate detection prevents double-creation
- [ ] **Edge case — Admin danger zone**: Reset student XP/level → verify profile reset → verify historical logs (xp_logs, coin_logs) remain unchanged
- [ ] **Edge case — CSV with Turkish headers**: Upload CSV with `ad`, `soyad`, `sınıf` columns → verify correct mapping
- [ ] **Error — Bulk create partial failure**: Upload CSV with one invalid entry → verify partial success with error reporting
- [ ] **Boundary — Username collision**: (Requires test setup) Force username collision → verify retry mechanism generates unique username
- [ ] **Cross-system — Class transfer**: Move student to new class → verify old assignments withdrawn → verify new learning path enrollment (documented in spec #18)

## Key Files

### Admin

| File | Purpose |
|------|---------|
| `owlio_admin/lib/features/users/screens/user_list_screen.dart` | User list with filters + co-located providers |
| `owlio_admin/lib/features/users/screens/user_edit_screen.dart` | 3-tab detail/edit view |
| `owlio_admin/lib/features/users/screens/user_create_screen.dart` | Single + bulk CSV creation |
| `owlio_admin/lib/core/utils/role_helpers.dart` | Shared role color/label helpers |
| `supabase/functions/bulk-create-students/index.ts` | Edge Function: auth user creation, username gen, duplicate detection |

### Teacher (Main App)

| File | Purpose |
|------|---------|
| `lib/presentation/screens/teacher/student_detail_screen.dart` | Full student academic profile |
| `lib/presentation/screens/teacher/class_detail_screen.dart` | Class roster + password access + transfer |
| `lib/presentation/providers/teacher_provider.dart` | All teacher-scoped providers |
| `lib/data/repositories/supabase/supabase_teacher_repository.dart` | Repository implementation |
| `lib/domain/entities/teacher.dart` | Teacher-view entities (StudentSummary, etc.) |

### Shared

| File | Purpose |
|------|---------|
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | RPC name constants |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Table name constants |
| `packages/owlio_shared/lib/src/enums/user_role.dart` | UserRole enum with role hierarchy helpers |

## Known Issues & Tech Debt

1. **No user text search in admin** — Large user bases require knowing school/class to find a specific user. A text search input would improve usability.
2. **No password reset mechanism** — Students cannot change their password, and teachers cannot reset it. The original `password_plain` from account creation is the only credential. If a future password reset feature is needed, it must update `profiles.password_plain` alongside the auth password to keep credential cards accurate.
