# Class Management

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `ChangeStudentClassUseCase` + `changeStudentClassUseCaseProvider` registered but never called — `BulkMoveStudentsUseCase` handles all moves (single + multi) | Low | Fixed |
| 2 | Dead Code | `GetClassmatesUseCase` + `getClassmatesUseCaseProvider` registered but never called from any screen or provider | Low | Fixed |
| 3 | Dead Code | `TeacherClassModel.fromEntity` and `toJson` defined but never called — read-only RPC projection, no write-back path | Low | Fixed |
| 4 | Dead Code | `StudentSummaryModel.fromEntity` and `toJson` defined but never called — same as above | Low | Fixed |
| 5 | Edge Case | `_showEditClassDialog` in `ClassesScreen` does not expose description field — editing always passes `description: null` to `update_class` RPC, silently clearing any existing description | Medium | Fixed |
| 6 | Code Quality | `teacherClassesProvider` and `classStudentsProvider` return `[]` on failure — `error:` branch in screen `.when()` is unreachable; network errors appear as empty states | Medium | Fixed |
| 7 | Code Quality | `_showSingleStudentMoveSheet` and `_showMoveToSheet` in `ClassDetailScreen` are near-identical bottom sheets differing only in single vs. multi selection | Low | Skipped (minor) |
| 8 | Architecture | `profileContextProvider` queries `DbTables.schools` and `DbTables.classes` directly without UseCase/Repository — acknowledged in comment as pragmatic choice | Low | Skipped (intentional) |
| 9 | Performance | No index on `classes(school_id)` — `get_classes_with_stats` scans `classes WHERE school_id = p_school_id` without covering index | Low | Skipped (< 50 classes per school) |
| 10 | Dead Code | `TeacherRepository.updateStudentClass` + `SupabaseTeacherRepository` implementation wired to `update_student_class` RPC but only called by dead `ChangeStudentClassUseCase` | Low | Skipped (repo interface kept) |

### Checklist Result

- Architecture Compliance: **PASS** — Screen → Provider → UseCase → Repository respected; `profileContextProvider` bypass is acknowledged and scoped (#8)
- Code Quality: **PASS** — silent failure in class providers fixed (#6); bottom-sheet duplication minor (#7, skipped)
- Dead Code: **PASS** — unused usecases removed (#1, #2), unused model methods removed (#3, #4); repository method kept as interface contract (#10)
- Database & Security: **PASS** — all mutation RPCs are SECURITY DEFINER with school-scope enforcement; RLS covers table-level access; `scope_learning_paths.class_id` has ON DELETE CASCADE (fixed in prior learning-path audit); `delete_class` RPC enforces zero-student precondition
- Edge Cases & UX: **PASS** — edit dialog description field added (#5); empty/loading/error states handled; null values guarded; grade 1–12 enforced at DB + UI
- Performance: **PASS** — no N+1 (stats aggregated in RPCs); composite index `idx_profiles_class_role` covers student enumeration; `classes(school_id)` scan acceptable at current scale (#9)
- Cross-System Integrity: **PASS** — class change fires `on_student_class_change` trigger (withdraws old assignments, enrolls in new); learning paths cascade on class delete; leaderboard `class_id` SET NULL on delete; league history preserved

---

## Overview

Class Management provides school, class, and student roster administration across three surfaces. **Admin** creates and manages schools and classes with full student roster control. **Teachers** create/edit/delete classes within their school, view student rosters, move students between classes (single or bulk), download login credential cards as PDF, and access student profiles. **Students** passively belong to a class — their `class_id` in `profiles` determines which assignments, learning paths, and leaderboard scopes apply to them.

## Data Model

### Tables

**`schools`** — Top-level organizational unit
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | VARCHAR(255) NOT NULL | |
| code | VARCHAR(20) UNIQUE NOT NULL | Used during signup for school lookup |
| status | VARCHAR(20) | CHECK: `active`, `trial`, `suspended` |
| subscription_tier | VARCHAR(20) | default `free` |
| subscription_expires_at | TIMESTAMPTZ | nullable |
| settings | JSONB | default `{}` |

**`classes`** — Belongs to a school
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| school_id | UUID FK → schools | ON DELETE CASCADE |
| name | VARCHAR(100) NOT NULL | |
| grade | INTEGER NOT NULL | CHECK: 1–12 |
| academic_year | VARCHAR(20) | nullable |
| description | TEXT | nullable |
| settings | JSONB | default `{}` |
| UNIQUE | | `(school_id, name, academic_year)` + partial index for NULL year |

**`profiles.class_id`** — Student/teacher membership
| Column | Type | Notes |
|--------|------|-------|
| class_id | UUID FK → classes | ON DELETE SET NULL |

### Key Relationships

- `schools` 1:N `classes` (CASCADE delete)
- `classes` 1:N `profiles` (SET NULL on delete — students become class-less)
- `classes` 1:N `assignments` (CASCADE delete)
- `classes` 0:N `scope_learning_paths` (CASCADE delete — added in learning-path audit)
- `classes` 0:N `league_history` (SET NULL on delete)

## Surfaces

### Admin

**School Management** (`owlio_admin/lib/features/schools/`)
- CRUD schools with inline class management (expandable cards within school edit)
- Add/remove students from classes via direct table operations
- View school code, subscription status, settings

**Class Management** (`owlio_admin/lib/features/classes/`)
- Dedicated class list and edit screens
- Student panel within class edit (add/remove students)
- Direct Supabase table access (no UseCase layer — admin uses service role)

### Student

- Passive class membership via `profiles.class_id`
- Class name displayed in profile context (`profileContextProvider`)
- Class determines: which assignments they receive, which learning path scope applies, which class leaderboard they appear in
- No student-initiated class operations

### Teacher

**Class List** (`ClassesScreen`)
- View all classes in their school with stats (student count, avg progress, avg XP, avg streak, reading time, completed books, active students, vocab words)
- Create new class (name, grade 1–12, optional description)
- Edit class (name, grade) — **description field missing from edit dialog (Finding #5)**
- Delete class (disabled if students remain; server enforces too)

**Class Detail** (`ClassDetailScreen`) — dual mode:
- **Management mode**: student roster, tap for info sheet (password, profile link, single move), select mode for bulk move, download login cards as PDF
- **Report mode**: class stats bar (student count, avg XP, avg streak, progress, books), student cards with progress bars and stat chips, tap to view full student detail

**Student Move Flow**:
1. Single move: student info sheet → "Move to Another Class" → class picker bottom sheet
2. Bulk move: toggle select mode → checkbox students → "Move to..." bar → class picker bottom sheet
3. Both use `BulkMoveStudentsUseCase` (single move passes 1-element list)
4. Server-side `on_student_class_change` trigger handles assignment sync automatically

## Business Rules

1. **Grade range**: Classes must have grade 1–12 (DB constraint + UI dropdown)
2. **Unique class names**: `(school_id, name, academic_year)` must be unique; partial index handles NULL academic_year
3. **Delete precondition**: Class can only be deleted if it has zero students (UI disables button + RPC raises exception)
4. **School-scope enforcement**: All teacher RPCs verify caller's `school_id` matches the target class/student's `school_id`
5. **Class change triggers assignment sync**: When `profiles.class_id` changes, the `on_student_class_change` trigger:
   - Withdraws student from old class's pending/in_progress assignments (status → `withdrawn`)
   - Enrolls student in new class's active, non-expired assignments
   - Backfills unit assignment progress from existing learning path work via `_backfill_student_unit_progress`
6. **Password visibility**: Teachers can see and copy `password_plain` for students in their school (used for login card distribution to younger students)
7. **Login cards**: PDF generation for class rosters containing student name, school code, email/username, and password
8. **School lookup**: Public `lookup_school_by_code()` returns only school_id + name for active schools — no sensitive data exposed

## Cross-System Interactions

### Class Change → Assignment Sync
```
profiles.class_id UPDATE
  → on_student_class_change trigger (PostgreSQL)
    → old class assignments: status = 'withdrawn'
    → new class assignments: INSERT/re-activate assignment_students
    → unit assignments: _backfill_student_unit_progress()
```

### Class Change → Learning Path
```
profiles.class_id UPDATE
  → scope_learning_paths resolution uses new class_id
  → student sees new class's learning path immediately on next load
```

### Class Change → Leaderboard
```
profiles.class_id UPDATE
  → class leaderboard queries join on profiles.class_id
  → student appears in new class leaderboard immediately
  → historical league_history records retain old class_id
```

### Class Delete → Cascades
```
DELETE classes WHERE id = ?
  → profiles.class_id SET NULL (students become class-less)
  → assignments CASCADE deleted
  → scope_learning_paths CASCADE deleted
  → league_history.class_id SET NULL
```

## Edge Cases

- **Empty class**: Shows `EmptyStateWidget` with "No students in this class" message
- **No classes in school**: Shows `EmptyStateWidget` with "No classes found" message
- **Delete class with students**: Delete button disabled in UI; RPC raises exception as safety net
- **Class change with active assignments**: Trigger withdraws from old, enrolls in new, backfills progress
- **Student with no class**: `class_id = NULL` — student appears in no class leaderboard, receives no class-scoped assignments, no class learning path
- **Duplicate class name**: UNIQUE constraint returns `ServerFailure` → shown as error snackbar
- **Network failure loading classes**: Provider returns empty list (Finding #6) — appears as empty state rather than error state

## Test Scenarios

- [ ] Happy path: teacher creates a class with name, grade, description → class appears in list with correct stats
- [ ] Happy path: teacher opens class detail → student roster loads with correct XP, level, streak, books
- [ ] Happy path: teacher moves single student via info sheet → student disappears from source, appears in target class
- [ ] Happy path: teacher bulk-selects 3 students → moves to another class → all three transfer atomically
- [ ] Happy path: teacher downloads login cards PDF → PDF contains all students' credentials
- [ ] Edit: teacher edits class name and grade → changes persist on reload
- [ ] Delete: teacher deletes empty class → class removed from list
- [ ] Delete blocked: teacher tries to delete class with students → delete option disabled
- [ ] Empty state: school with zero classes → "No classes found" message shown
- [ ] Empty state: class with zero students → "No students in this class" message shown
- [ ] Cross-system: move student to new class → old class assignments withdrawn, new class assignments enrolled
- [ ] Cross-system: delete class → students' class_id becomes null, class assignments cascade deleted
- [ ] Security: teacher in School A cannot view/modify classes in School B (RPC rejects)

## Key Files

### Teacher (Main App)
- `lib/presentation/screens/teacher/classes_screen.dart` — Class CRUD UI
- `lib/presentation/screens/teacher/class_detail_screen.dart` — Student roster + move operations
- `lib/presentation/providers/teacher_provider.dart` — `teacherClassesProvider`, `classStudentsProvider`, `currentTeacherClassesProvider`

### Domain
- `lib/domain/entities/teacher.dart` — `TeacherClass`, `StudentSummary` entities
- `lib/domain/repositories/teacher_repository.dart` — Class management interface
- `lib/domain/usecases/teacher/` — `CreateClassUseCase`, `UpdateClassUseCase`, `DeleteClassUseCase`, `GetClassesUseCase`, `GetClassStudentsUseCase`, `BulkMoveStudentsUseCase`

### Data
- `lib/data/repositories/supabase/supabase_teacher_repository.dart` — Full implementation
- `lib/data/models/teacher/teacher_class_model.dart` — JSON ↔ entity mapping
- `lib/data/models/teacher/student_summary_model.dart` — JSON ↔ entity mapping

### Admin
- `owlio_admin/lib/features/schools/screens/school_edit_screen.dart` — School + inline class management
- `owlio_admin/lib/features/classes/screens/class_edit_screen.dart` — Dedicated class editor

### Database
- `supabase/migrations/20260131000002_create_core_tables.sql` — schools, classes, profiles DDL
- `supabase/migrations/20260325000014_class_management_rpcs.sql` — delete_class, bulk_move_students, update_class
- `supabase/migrations/20260327000009_student_class_change_sync.sql` — Assignment sync trigger on class change

## Known Issues & Tech Debt

1. **No `classes(school_id)` index** (Finding #9) — acceptable at current scale but would benefit large schools
2. **Bottom-sheet duplication** (Finding #7) — `_showSingleStudentMoveSheet` and `_showMoveToSheet` are near-identical; minor, not worth extracting
3. **`TeacherRepository.updateStudentClass`** (Finding #10) — method + RPC still wired but no usecase consumer; kept as part of repo interface contract
