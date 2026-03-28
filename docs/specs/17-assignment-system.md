# Assignment System

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `AssignmentModel.fromEntity` and `toJson` defined but never called — read-only model, no write-back path | Low | Fixed |
| 2 | Dead Code | `StudentAssignmentModel.fromEntity` and `toJson` defined but never called — same as above | Low | Fixed |
| 3 | Dead Code | `AssignmentStudentModel.fromEntity` and `toJson` defined but never called — same as above | Low | Fixed |
| 4 | Dead Code | `pendingAssignmentCountProvider` defined but never consumed — no badge or widget reads it | Low | Fixed |
| 5 | Code Quality | `activeAssignmentsProvider` has 4 `debugPrint` statements that fire in production builds | Low | Fixed |
| 6 | Code Quality | `assignmentSyncProvider` has 5 `debugPrint` statements that fire in production builds | Low | Fixed |
| 7 | Architecture | `AssignmentDetailScreen._AssignmentAppBar` calls `deleteAssignmentUseCaseProvider` directly in widget — bypasses Provider layer | Medium | Fixed |
| 8 | Architecture | `StudentAssignmentDetailScreen._startReading/_startVocabulary/_startUnitItem` call `startAssignmentUseCaseProvider` directly in widget — bypasses Provider layer | Medium | Fixed |
| 9 | Architecture | `getActiveAssignments` 3-day overdue grace period is business logic in repository (`supabase_student_assignment_repository.dart`) — should be in UseCase or entity | Low | Skipped (acceptable) |
| 10 | Code Quality | `_StatusBadge` private widget duplicated between `assignments_screen.dart` and `assignment_report_screen.dart` with inconsistent "Upcoming" color (orange vs blue) | Low | Fixed |
| 11 | Code Quality | Unit item type rendering (switch on `LearningPathItemType`) duplicated in 3 places: create screen `_UnitItemRow`, teacher detail `_UnitContentSection`, student detail `_UnitItemsList` | Low | Fixed |
| 12 | Edge Case | `CreateAssignmentScreen` does not validate content selection before submission — `bookId`, `wordListId`, or `scopeLpUnitId` can be null when UseCase is called | Medium | Fixed |
| 13 | Edge Case | `teacherAssignmentsProvider` returns `[]` on failure — error state in `assignments_screen.dart` is unreachable, teacher sees empty state instead of error | Low | Fixed |
| 14 | Database | `overdue` status is a display-only concept computed client-side in `StudentAssignmentModel.fromJson` — no server-side state transition by design (no business logic depends on it) | Medium | Skipped (client-only by design) |
| 15 | Database | `settings` JSONB column on `assignments` table is unused — no model, entity, or repository reads or writes it | Low | Skipped (no harm) |
| 16 | Security | `startAssignment` and `completeAssignment` are direct table UPDATEs protected only by RLS — a student could forge `status='completed'`, `score=100`, `progress=100` via Supabase client for book/vocabulary assignments | High | Fixed |
| 17 | Code Quality | `AssignmentType.fromDbValue` and `AssignmentStatus.fromDbValue` silently fall back to `book`/`pending` on unknown values — masks data corruption | Low | Skipped (codebase-wide pattern) |

### Checklist Result (post-fix)

- Architecture Compliance: **PASS** — UseCase-in-widget pattern fixed (#7, #8) via `AssignmentDeleteController` and `StudentAssignmentController`; 3-day grace in repository kept as-is (#9, acceptable)
- Code Quality: **PASS** — debugPrint removed (#5, #6); StatusBadge consolidated (#10); unit item icon/color/isTracked extracted to `LearningPathItemDisplay` helper (#11)
- Dead Code: **PASS** — `fromEntity`/`toJson` on 3 models removed; unused `pendingAssignmentCountProvider` removed
- Database & Security: **1 remaining** — `student_update` RLS still allows direct UPDATEs (future hardening). Start/complete migrated to SECURITY DEFINER RPCs (#16); overdue kept client-only by design (#14)
- Edge Cases & UX: **PASS** — content validation added (#12); error state reachable (#13)
- Performance: **PASS** — No N+1 (stats aggregated in RPCs); `assignmentSyncProvider` debounced with 60s `keepAlive`; unit progress over-broad recalculation is intentional with server-side no-op optimization
- Cross-System Integrity: **PASS** — Book/vocabulary/unit completions correctly propagate; `assignmentSyncProvider` back-fills offline completions; class-change trigger withdraws/re-enrolls; no XP/badge/streak awarded by assignment system itself

---

## Overview

The Assignment System lets teachers create homework tasks for their classes. Three assignment types exist: **book** (read a specific book), **vocabulary** (complete a word list session), and **unit** (complete all items in a learning path unit). Students receive assignments, track progress automatically as they complete content, and can view their status. Teachers monitor completion rates and drill into per-student details. The admin panel provides a read-only view of all teacher-created assignments with a delete option.

Assignment progress is *distributed* — each content feature (book reading, vocabulary sessions) independently checks for matching assignments and updates progress, rather than a central assignment engine polling for changes.

## Data Model

### Tables

**`assignments`** — Teacher-created assignments (one per homework task)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| teacher_id | UUID FK → profiles | ON DELETE CASCADE |
| class_id | UUID FK → classes | ON DELETE CASCADE |
| type | VARCHAR(50) | CHECK: `book`, `vocabulary`, `unit` |
| title | VARCHAR(255) NOT NULL | |
| description | TEXT | optional |
| content_config | JSONB NOT NULL | type-specific payload (see Business Rules #2) |
| settings | JSONB | default `{}`; **currently unused** |
| start_date | TIMESTAMPTZ NOT NULL | assignment becomes visible |
| due_date | TIMESTAMPTZ NOT NULL | overdue threshold |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | auto-maintained by trigger |

**`assignment_students`** — Per-student progress rows
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| assignment_id | UUID FK → assignments | ON DELETE CASCADE |
| student_id | UUID FK → profiles | ON DELETE CASCADE |
| status | VARCHAR(20) | CHECK: `pending`, `in_progress`, `completed`, `overdue`, `withdrawn` |
| score | DECIMAL(5,2) | nullable; set on completion (accuracy % for vocab, progress % for book) |
| progress | DECIMAL(5,2) | 0–100; updated incrementally for book/unit types |
| started_at | TIMESTAMPTZ | set when student first interacts |
| completed_at | TIMESTAMPTZ | set on completion |
| created_at | TIMESTAMPTZ | |
| UNIQUE(assignment_id, student_id) | | prevents duplicate enrollment |

### Key Relationships

```
teacher (profiles) → assignments (1:N via teacher_id)
class (classes) → assignments (1:N via class_id)
assignments → assignment_students (1:N, CASCADE delete)
assignment_students → profiles (N:1 via student_id)
assignments.content_config → books / word_lists / scope_learning_path_units (logical FK via JSONB)
```

### RPC Functions

| Function | Purpose | Auth |
|----------|---------|------|
| `create_assignment_with_students` | Atomic: insert assignment + all student rows | `auth.uid() == teacher_id` + `is_teacher_or_higher()` |
| `get_assignments_with_stats` | List with `total_students`/`completed_students` counts (excludes withdrawn) | teacher owns or admin |
| `get_assignment_detail_with_stats` | Single assignment with aggregated stats | teacher owns or admin |
| `update_assignment_progress` | Atomic: update progress + auto-transition `pending → in_progress` | `auth.uid() == student_id` |
| `calculate_unit_assignment_progress` | Server-side: count completed items in LP unit, write back progress | `auth.uid() == student_id` |
| `sync_unit_assignment_progress` | Bulk: recalculate all non-completed students in a unit assignment | teacher owns or admin |
| `get_unit_assignment_items` | Items in a unit with per-student completion state | `auth.uid() == student_id` |
| `get_class_learning_path_units` | Units available for unit-type assignment creation | teacher in same school |
| `get_student_unit_progress` | Per-item detail for one student in a unit assignment | teacher owns or admin |

### RLS Policies

| Table | Policy | Operation | Condition |
|-------|--------|-----------|-----------|
| assignments | `assignments_teacher_all` | ALL | `teacher_id = auth.uid() OR is_admin()` |
| assignments | `assignments_student_select` | SELECT | `is_assigned_student(id)` — SECURITY DEFINER helper |
| assignment_students | `assignment_students_teacher_all` | ALL | `get_assignment_teacher_id(assignment_id) = auth.uid() OR is_admin()` |
| assignment_students | `assignment_students_student_select` | SELECT | `student_id = auth.uid()` |
| assignment_students | `assignment_students_student_update` | UPDATE | `student_id = auth.uid()` |

Note: RLS uses 3 `SECURITY DEFINER` helper functions (`is_assignment_teacher`, `is_assigned_student`, `get_assignment_teacher_id`) to break the mutual recursion between the two tables' policies.

### Indexes

| Index | On |
|-------|----|
| `idx_assignments_teacher` | `assignments(teacher_id)` |
| `idx_assignments_class` | `assignments(class_id)` |
| `idx_assignments_due` | `assignments(due_date)` |
| `idx_assignment_students_student` | `assignment_students(student_id)` |
| `idx_assignment_students_status` | `assignment_students(status)` |

### Triggers

| Trigger | On | Purpose |
|---------|-----|---------|
| `update_assignments_updated_at` | `BEFORE UPDATE ON assignments` | Auto-maintain `updated_at` |
| `on_student_class_change` | `AFTER UPDATE OF class_id ON profiles` | Withdraw from old class assignments, enroll in new class assignments, backfill unit progress |

## Surfaces

### Admin

**Entry point:** Sidebar → Assignments → `/assignments`

**Read-only list screen** (`assignment_list_screen.dart`):
- Direct Supabase query (no domain layer — consistent with admin pattern)
- Filters by `AssignmentType` via client-side `StateProvider`
- Shows: title, teacher name, class, type badge, student count, date range
- Tap → detail screen

**Detail screen** (`assignment_detail_screen.dart`):
- Assignment info header + `DataTable` of students with: name, email, status, progress %, score, dates
- Info banner: "This view is read-only"
- Single write action: **Delete** (confirmation dialog → direct table delete with CASCADE)
- Uses `AssignmentStatus.fromDbValue` from shared package for status display

**No create/edit** — assignments are created exclusively by teachers in the main app.

### Student

**Entry point:** Home screen assignments card or bottom nav → Assignments → `/assignments`

**Assignments List** (`student_assignments_screen.dart`):
- Triggers `assignmentSyncProvider` on entry (debounced, 60s cooldown)
- Groups into 3 sections: "To Do" (pending + in_progress), "Completed", "Overdue"
- Each card shows: title, teacher, class, type icon/color, due date, progress bar, status badge
- Tap → detail screen

**Assignment Detail** (`student_assignment_detail_screen.dart`):
- Header: title, description, teacher, class, dates, status, progress
- **Book type:** "Start Reading" button → navigates to book reader; progress auto-tracked by chapter completion
- **Vocabulary type:** "Start Practice" button → navigates to word list session; completion auto-tracked
- **Unit type:** Expandable item list showing per-item completion (books + word lists in the unit)
- For pending assignments: "Start" button transitions status to `in_progress`

**Background sync** (`assignmentSyncProvider`):
- Runs on first screen open, then debounced for 60s
- For book assignments: checks `ReadingProgress.isCompleted` → auto-completes if book already finished
- For unit assignments: calls `calculateUnitProgress` RPC → server re-derives from source tables
- Handles the case where content was completed before the assignment existed

**Assignment notification** (`assignmentNotificationEventProvider`):
- On app open, if active assignments exist, fires a notification dialog
- Single assignment → direct navigation to detail; multiple → navigation to list

**Book access control** (`book_access_provider.dart`):
- `bookLockProvider` reads active assignments with `hasLibraryLock` flag
- `canAccessBookProvider` gates library access — student can only read assigned books when lock is active

### Teacher

**Entry point:** Bottom nav → Assignments → `/teacher/assignments`

**Assignments List** (`assignments_screen.dart`):
- Groups into Active, Upcoming, Past Due using entity computed properties
- FAB + AppBar button → create screen
- Pull-to-refresh via `RefreshIndicator`
- Each card: title, type icon/color, class, date range, completion progress bar

**Create Assignment** (`create_assignment_screen.dart`):
- 3-way `SegmentedButton` for type: Unit, Book, Vocabulary
- Form fields: title, description (optional), class (dropdown), start date, due date
- Type-specific content selection via bottom sheets:
  - **Book:** `_BookSelectionSheet` — filterable book list
  - **Vocabulary:** `_WordListSelectionSheet` — word list picker
  - **Unit:** `_UnitSelectionSheet` — class learning path units with item preview
- Book type: optional "Lock Library" checkbox (restricts student to assigned book only)
- Submit → `CreateAssignmentUseCase` → atomic RPC → invalidates list providers
- Pre-fill support: can be deep-linked from library with `preSelectedBookId`

**Assignment Detail** (`assignment_detail_screen.dart`):
- Assignment info header + student progress list (sorted by progress desc, then alphabetically)
- Per-student card: name, avatar, progress bar, status badge, score
- Unit assignments: tap student → `_StudentUnitDetailSheet` showing per-item breakdown
- Delete: confirmation dialog → UseCase call → back navigation
- Pull-to-refresh on both assignment and student data

**Assignment Report** (`assignment_report_screen.dart`):
- Reuses `teacherAssignmentsProvider`
- Aggregate stats: total assignments, total students, total completed, avg completion rate
- Same grouped list as assignments screen
- Note: `_StatusBadge` duplicated from assignments_screen with color inconsistency (#10)

## Business Rules

1. **Three assignment types:** `book` (read a book), `vocabulary` (complete a word list), `unit` (complete all items in a learning path unit). Type is immutable after creation.
2. **`contentConfig` is the flexible payload.** Type-specific identifiers stored as JSONB:
   - Book: `{bookId, chapterIds?, lockLibrary?}`
   - Vocabulary: `{wordListId}`
   - Unit: `{scopeLpUnitId, unitName, totalItems}`
3. **Atomic creation.** `create_assignment_with_students` RPC inserts the assignment + all student rows in one transaction. If `studentIds` array is empty, all students in the class are enrolled automatically.
4. **Status lifecycle:** `pending → in_progress → completed`. `withdrawn` is set by class-change trigger. `overdue` exists in the enum but is **never set server-side** — overdue detection is entirely client-side.
5. **Auto-transition pending → in_progress.** The `update_assignment_progress` RPC atomically promotes status when first non-zero progress arrives.
6. **Distributed completion.** Each content feature independently checks for matching assignments:
   - **Book completion** (`book_provider.dart`): after all chapters read, matches by `bookId`, computes `completedChapters / totalChapters * 100`
   - **Vocabulary completion** (`vocabulary_provider.dart`): after session, matches by `wordListId`, sets `score = accuracy %`
   - **Unit progress** (`book_provider.dart` + `vocabulary_provider.dart`): after any book/vocab completion, calls `calculateUnitProgress` RPC on ALL active unit assignments (intentionally over-broad — server is a no-op when item isn't in the unit)
7. **Vocabulary assignments complete in one shot.** No partial progress — session completion immediately triggers `completeAssignment` with `score = accuracy`.
8. **Unit progress is server-derived.** `calculate_unit_assignment_progress` RPC counts completed word lists (from `user_word_list_progress`) and books (from `reading_progress`) against the unit's `scope_unit_items`. Client never computes unit progress itself.
9. **Class change handling.** `on_student_class_change` trigger: (a) withdraws all pending/in_progress assignments for old class, (b) enrolls student in all active assignments for new class, (c) backfills unit progress from existing completions.
10. **Withdrawn students excluded from stats.** All stats RPCs filter `WHERE status != 'withdrawn'` for both `total_students` and `completed_students` counts.
11. **Library lock.** Book assignments can optionally set `lockLibrary: true` in `contentConfig`. When active, `bookLockProvider` restricts the student to only reading the assigned book.
12. **3-day overdue grace.** `getActiveAssignments` hides overdue items more than 3 days past due date (client-side filter in repository).
13. **Delete cascades.** Deleting an assignment cascades to all `assignment_students` rows via FK constraint.

## Cross-System Interactions

### Book Completion → Assignment Progress
```
Student finishes chapter → ChapterCompletionNotifier.markComplete()
  → _updateAssignmentProgress()
    → getActiveAssignments → filter book type by bookId match
    → progress = completedChapters / totalChapters * 100
    → IF progress >= 100: CompleteAssignmentUseCase
    → ELSE: UpdateAssignmentProgressUseCase
  → For ALL active unit assignments (regardless of match):
    → CalculateUnitProgressUseCase (server recalculates, no-op if book not in unit)
  → invalidate: studentAssignmentsProvider, activeAssignmentsProvider
```

### Vocabulary Session → Assignment Progress
```
Student finishes vocab session → SessionSaveNotifier.saveSession()
  → _completeAssignments() [best-effort, failure swallowed]
    → getActiveAssignments → filter vocabulary type by wordListId match
    → CompleteAssignmentUseCase(score: accuracy %)
  → For ALL active unit assignments:
    → CalculateUnitProgressUseCase
  → invalidate: studentAssignmentsProvider, activeAssignmentsProvider
```

### Class Transfer → Assignment Sync
```
Admin/teacher changes student class → profiles.class_id UPDATE
  → on_student_class_change trigger fires
    → old class assignments: status → 'withdrawn' (pending/in_progress only)
    → new class assignments: INSERT or reactivate assignment_students rows
    → for unit assignments: _backfill_student_unit_progress()
```

### What Assignment System Does NOT Trigger
- No XP awards (XP comes from the underlying activity, not the assignment itself)
- No badge checks
- No streak updates
- No coin transactions
- No daily quest progress (quest tracks activities, not assignments)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Student completes content before assignment exists | `assignmentSyncProvider` catches up on next app open; unit type uses server-side recalculation |
| Student completes assignment while offline | Assignment row stays stale until `assignmentSyncProvider` runs on reconnect |
| Teacher creates assignment for class with 0 students | RPC creates assignment with no `assignment_students` rows; detail shows empty student list |
| Student changes class mid-assignment | Trigger withdraws old, enrolls in new class assignments, backfills unit progress |
| Book assignment for book with no chapters | `totalChapters = 0` → division by zero in progress calc; currently no guard |
| Unit assignment where LP unit has no items | `totalItems = 0` in `contentConfig`; server RPC returns `progress = 0` |
| Duplicate assignment for same content | No uniqueness constraint on `(class_id, type, content_config)` — teacher can create multiple assignments for the same book/wordlist |
| Assignment deleted while students are mid-progress | CASCADE deletes all `assignment_students` rows; student's next app open will not find the assignment |
| Teacher deletes class | CASCADE on `assignments.class_id` → all assignments and student rows deleted |
| Due date in the past at creation | No validation prevents creating an already-overdue assignment |
| Student forges completion via direct API | RLS allows `UPDATE` on own `assignment_students` row — student can set arbitrary status/score/progress (Finding #16) |
| All active assignments shown on home quest card | `daily_quest_list.dart` watches `activeAssignmentsProvider`; if loading/error, silently shows empty |

## Test Scenarios

- [ ] **Happy path (book):** Teacher creates book assignment → student sees it → reads all chapters → assignment auto-completes → teacher sees 100% progress
- [ ] **Happy path (vocabulary):** Teacher creates vocab assignment → student completes word list session → assignment completes with accuracy score
- [ ] **Happy path (unit):** Teacher creates unit assignment → student completes all books and word lists in unit → progress incrementally updates → completes at 100%
- [ ] **Empty state (teacher):** No assignments created → empty state with "Create your first assignment" CTA
- [ ] **Empty state (student):** No assignments received → empty state message
- [ ] **Content pre-completed:** Student already read the book → teacher creates book assignment → `assignmentSyncProvider` auto-completes on next app open
- [ ] **Class change:** Student moves from Class A to Class B → Class A assignments show `withdrawn` → Class B assignments appear with correct progress backfill
- [ ] **Delete assignment:** Teacher deletes → confirmation → assignment and all student rows removed → teacher list updated
- [ ] **Library lock:** Teacher creates book assignment with "Lock Library" → student can only access the assigned book
- [ ] **Overdue display:** Assignment past due date → student sees "Overdue" badge → hidden after 3 days past due
- [ ] **Unit item detail (teacher):** Teacher taps student in unit assignment → sees per-item breakdown (word lists: sessions/accuracy, books: reading progress)
- [ ] **Unit item detail (student):** Student views unit assignment detail → sees checklist of items with completion status
- [ ] **Create with deep-link:** Navigate to create screen with `preSelectedBookId` → book pre-filled, type set to `book`
- [ ] **Assignment notification:** Student opens app with active assignments → notification dialog appears → tap "View" → navigates to detail
- [ ] **Admin view:** Admin opens assignments → sees all teacher assignments (read-only) → can filter by type → can view detail → can delete
- [ ] **Concurrent completion:** Two students complete same assignment simultaneously → no conflicts (separate `assignment_students` rows)

## Key Files

### App (Student)
| Layer | File |
|-------|------|
| Entity | `lib/domain/entities/student_assignment.dart` |
| Entity | `lib/domain/entities/unit_assignment_item.dart` |
| Repository interface | `lib/domain/repositories/student_assignment_repository.dart` |
| UseCases | `lib/domain/usecases/student_assignment/` (8 files) |
| Models | `lib/data/models/assignment/student_assignment_model.dart`, `unit_assignment_item_model.dart` |
| Repository impl | `lib/data/repositories/supabase/supabase_student_assignment_repository.dart` |
| Providers | `lib/presentation/providers/student_assignment_provider.dart` |
| Screens | `lib/presentation/screens/student/student_assignments_screen.dart`, `student_assignment_detail_screen.dart` |
| Access control | `lib/presentation/providers/book_access_provider.dart` |

### App (Teacher)
| Layer | File |
|-------|------|
| Entity | `lib/domain/entities/assignment.dart`, `class_learning_path_unit.dart`, `student_unit_progress_item.dart` |
| Repository interface | `lib/domain/repositories/teacher_repository.dart` (assignment methods) |
| UseCases | `lib/domain/usecases/assignment/` (7 files) |
| Models | `lib/data/models/assignment/assignment_model.dart`, `assignment_student_model.dart`, `class_learning_path_unit_model.dart`, `student_unit_progress_item_model.dart` |
| Repository impl | `lib/data/repositories/supabase/supabase_teacher_repository.dart` (lines 248–431) |
| Providers | `lib/presentation/providers/teacher_provider.dart` (lines 218–285) |
| Screens | `lib/presentation/screens/teacher/assignments_screen.dart`, `create_assignment_screen.dart`, `assignment_detail_screen.dart` |
| Report | `lib/presentation/screens/teacher/reports/assignment_report_screen.dart` |

### Admin
| Layer | File |
|-------|------|
| List screen | `owlio_admin/lib/features/assignments/screens/assignment_list_screen.dart` |
| Detail screen | `owlio_admin/lib/features/assignments/screens/assignment_detail_screen.dart` |

### Cross-Feature Integration
| File | Role |
|------|------|
| `lib/presentation/providers/book_provider.dart` | `_updateAssignmentProgress()` — auto-completes book/unit assignments on chapter completion |
| `lib/presentation/providers/vocabulary_provider.dart` | `_completeAssignments()` — auto-completes vocab/unit assignments on session completion |
| `lib/presentation/widgets/common/assignment_notification_dialog.dart` | In-app notification on app open |
| `lib/presentation/widgets/home/daily_quest_list.dart` | Active assignments shown on home screen |

### Shared Package
| File | Contents |
|------|----------|
| `packages/owlio_shared/lib/src/constants/tables.dart` | `DbTables.assignments`, `DbTables.assignmentStudents` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | 11 assignment RPCs |
| `packages/owlio_shared/lib/src/enums/assignment_type.dart` | `book`, `vocabulary`, `unit` |
| `packages/owlio_shared/lib/src/enums/assignment_status.dart` | `pending`, `inProgress`, `completed`, `overdue`, `withdrawn` |

### Database
| Migration | Purpose |
|-----------|---------|
| `20260131000007_create_assignment_tables.sql` | Tables, FKs, CHECK constraints |
| `20260131000008_create_assignment_rls.sql` | Initial RLS (superseded) |
| `20260131000009_create_indexes_and_triggers.sql` | Indexes + `updated_at` trigger |
| `20260131000011_fix_assignment_rls_recursion.sql` | SECURITY DEFINER helpers, final RLS policies |
| `20260201000002_add_assignment_students_created_at.sql` | `created_at` column on `assignment_students` |
| `20260320000003_drop_old_assignment_tables.sql` | Drop superseded `unit_book_assignments`, `unit_curriculum_assignments` |
| `20260325000008_create_assignment_rpc.sql` | Atomic `create_assignment_with_students` |
| `20260325000010_update_assignment_progress_rpc.sql` | Atomic `update_assignment_progress` |
| `20260326000009_assignment_unit_type.sql` | `unit` type, detail/items/progress RPCs |
| `20260326000014_fix_unit_items_rpc_and_add_bulk_sync.sql` | `sync_unit_assignment_progress` |
| `20260326000015_teacher_student_unit_progress.sql` | `get_student_unit_progress` |
| `20260326000016_fix_rpc_null_safety_and_auth.sql` | Null-safety + school-scope auth fixes |
| `20260327000002_notif_assignment_setting.sql` | `notif_assignment` system setting |
| `20260327000009_student_class_change_sync.sql` | `withdrawn` status, class-change trigger, updated stats RPCs |
| `20260328400001_assignment_start_complete_rpcs.sql` | SECURITY DEFINER `start_assignment` + `complete_assignment` RPCs |

## Known Issues & Tech Debt

1. ~~**Student can forge assignment completion**~~ (Finding #16) — **Fixed** in `20260328400001_assignment_start_complete_rpcs.sql`. `startAssignment` and `completeAssignment` now use SECURITY DEFINER RPCs with enrollment, status transition, and score range validation. **Remaining:** `assignment_students_student_update` RLS policy still allows direct UPDATEs — future hardening should move all student mutations to RPCs and drop this policy.
2. **`overdue` status is client-only by design** (Finding #14) — `overdue` is a display-only concept computed in `StudentAssignmentModel.fromJson`. No server-side state transition exists because no business logic depends on it. Teacher stats RPCs don't filter by `overdue` (they use `completed` vs not-completed).
3. ~~**UseCase-in-widget pattern**~~ (Findings #7, #8) — **Fixed**: `AssignmentDeleteController` (teacher delete) and `StudentAssignmentController` (student start) now handle mutations through StateNotifier controllers.
4. ~~**Missing content validation on create**~~ (Finding #12) — **Fixed**: pre-submit guards validate book/wordList/unit selection per assignment type.
5. ~~**debugPrint in production**~~ (Findings #5, #6) — **Fixed**: all 9 statements removed from `student_assignment_provider.dart`.
6. **Unused `settings` column** (Finding #15) — JSONB column on `assignments` table, never read or written. Either repurpose or drop in a future migration.
7. ~~**Unit item rendering duplication**~~ (Finding #11) — **Fixed**: `LearningPathItemDisplay` helper in `ui_helpers.dart` centralizes icon/color/isTracked mapping. Per-type title/subtitle logic remains in each screen (different entity types).
