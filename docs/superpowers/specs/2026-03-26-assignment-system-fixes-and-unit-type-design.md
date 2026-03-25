# Assignment System Fixes + Unit Assignment Type

**Date:** 2026-03-26
**Status:** Approved
**Scope:** Bug fixes, dead code cleanup, new "unit" assignment type

---

## Overview

Two goals:
1. Fix existing assignment system issues (dead code, inactive sync, missing RPC, broken mixed type)
2. Add new `unit` assignment type — teachers assign a learning path unit, students complete all word lists + books in that unit

---

## Part 1: Mixed Type Removal + Unit Type Addition

### DB Migration

Update `assignments.type` CHECK constraint:

```sql
ALTER TABLE assignments DROP CONSTRAINT assignments_type_check;
ALTER TABLE assignments ADD CONSTRAINT assignments_type_check
  CHECK (type IN ('book', 'vocabulary', 'unit'));
```

No existing `mixed` rows exist (UI never exposed it).

### Shared Package

`AssignmentType` enum:
- Remove `mixed`
- Add `unit` with `dbValue: 'unit'`, `displayName: 'Unit'`

### content_config Structure (unit type)

```json
{
  "scopeLpUnitId": "<uuid>",
  "unitName": "Unit 3 - Daily Routines",
  "totalItems": 4
}
```

`unitName` and `totalItems` are denormalized snapshots at creation time. `totalItems` counts only `word_list` + `book` items (game/treasure excluded from progress).

### New RPC: `get_class_learning_path_units(p_class_id)`

Returns the learning path units assigned to a class's scope, with full item details.

**Auth:** Caller must be the teacher of the class or admin.

**Returns flat rows:**
| Column | Type | Description |
|--------|------|-------------|
| `path_id` | UUID | scope_learning_paths.id |
| `path_name` | TEXT | scope_learning_paths.name |
| `unit_id` | UUID | vocabulary_units.id |
| `scope_lp_unit_id` | UUID | scope_learning_path_units.id |
| `unit_name` | TEXT | vocabulary_units.name |
| `unit_color` | TEXT | vocabulary_units.color |
| `unit_icon` | TEXT | vocabulary_units.icon |
| `unit_sort_order` | INT | scope_learning_path_units.sort_order |
| `item_type` | TEXT | scope_unit_items.item_type |
| `item_id` | UUID | scope_unit_items.id |
| `item_sort_order` | INT | scope_unit_items.sort_order |
| `word_list_id` | UUID | nullable, for word_list items |
| `word_list_name` | TEXT | nullable |
| `words` | TEXT[] | nullable, array of word texts for word_list items |
| `book_id` | UUID | nullable, for book items |
| `book_title` | TEXT | nullable |
| `book_chapter_count` | INT | nullable |

**Query logic:**
1. Find `scope_learning_paths` where `class_id = p_class_id` (or school-wide/grade-level fallback matching the class's school and grade)
2. JOIN `scope_learning_path_units` → `vocabulary_units`
3. JOIN `scope_unit_items` with LEFT JOINs to `word_lists` and `books`
4. For word_list items: subquery to get word texts from vocabulary junction table
5. ORDER BY `path_sort_order, unit_sort_order, item_sort_order`

### CreateAssignmentScreen Changes

- Segmented button: `Book | Vocabulary | Unit`
- When `unit` selected: fetch units via `get_class_learning_path_units` for the selected class
- Unit selection modal bottom sheet shows:
  ```
  Unit 3 - Daily Routines
    📝 Greetings (12 words) — hello, goodbye, thanks, please, ...
    📝 Family (8 words) — mother, father, sister, brother, ...
    📖 My School Day (5 chapters)
    🎮 Game
    🎁 Treasure
  ```
- All words shown for each word list (no truncation)
- On select: `scopeLpUnitId`, `unitName`, `totalItems` (word_list + book count only) stored in `content_config`

### CreateAssignmentUseCase Changes

- Add `unit` type validation: requires `scopeLpUnitId != null`
- Build content_config with `scopeLpUnitId`, `unitName`, `totalItems`

---

## Part 2: Unit Assignment Completion Tracking

### What Counts Toward Progress

| Item Type | Completion Criteria | Source Table |
|-----------|-------------------|--------------|
| `word_list` | `completed_at IS NOT NULL` | `user_word_list_progress` |
| `book` | All chapters read | `reading_progress.completed_chapter_ids` vs `chapters` count |
| `game` | NOT tracked | — |
| `treasure` | NOT tracked | — |

**Progress formula:** `completed (word_list + book) / total (word_list + book) * 100`

### New RPC: `calculate_unit_assignment_progress(p_assignment_id, p_student_id)`

1. Get `scopeLpUnitId` from `assignments.content_config`
2. Get all `scope_unit_items` for that unit WHERE `item_type IN ('word_list', 'book')`
3. For each `word_list` item: check `user_word_list_progress.completed_at IS NOT NULL`
4. For each `book` item: check if all chapters are in `reading_progress.completed_chapter_ids`
5. Calculate `progress = completed_count / total_count * 100`
6. If progress = 100: UPDATE `assignment_students` SET `status = 'completed'`, `progress = 100`, `score = NULL`, `completed_at = now()` (no single accuracy score for unit assignments — multiple items)
7. Else: UPDATE `assignment_students` SET `progress = calculated`, `status = 'in_progress'` (if was `pending`)
8. Return `{progress, completed_count, total_count}`

**Auth:** Caller must be the student (`auth.uid() = p_student_id`).

### Trigger Points

Two existing code paths get a unit assignment check added:

1. **Word list session completes** (`session_summary_screen.dart`):
   - After existing vocabulary assignment check
   - Find active unit assignments → for each, call `calculate_unit_assignment_progress` RPC
   - Invalidate assignment providers

2. **Chapter completes** (`book_provider.dart` → `_updateAssignmentProgress`):
   - After existing book assignment check
   - Find active unit assignments → for each, call `calculate_unit_assignment_progress` RPC
   - Invalidate assignment providers

### New RPC: `get_unit_assignment_items(p_scope_lp_unit_id, p_student_id)`

Returns item list with per-student completion state. Used by student assignment detail screen.

| Column | Type | Description |
|--------|------|-------------|
| `item_type` | TEXT | word_list / book / game / treasure |
| `sort_order` | INT | |
| `word_list_id` | UUID | nullable |
| `word_list_name` | TEXT | nullable |
| `word_count` | INT | nullable |
| `is_word_list_completed` | BOOL | nullable |
| `book_id` | UUID | nullable |
| `book_title` | TEXT | nullable |
| `total_chapters` | INT | nullable |
| `completed_chapters` | INT | nullable |
| `is_book_completed` | BOOL | nullable |

**Auth:** Caller must be the student (`auth.uid() = p_student_id`).

---

## Part 3: Bug Fixes and Cleanup

### 3a. Remove `chapterIds` Dead Code

- Delete `chapterIds` getter from `StudentAssignment` entity
- Remove any references in models or providers

### 3b. Activate `assignmentSyncProvider`

- Add `ref.watch(assignmentSyncProvider)` in `StudentAssignmentsScreen.build()`
- Extend sync logic to handle `unit` type assignments:
  - For unit assignments: call `calculate_unit_assignment_progress` RPC
  - If all word_list + book items already done, assignment auto-completes

### 3c. New RPC: `get_assignment_detail_with_stats(p_assignment_id)`

Replaces the two-query approach in `SupabaseTeacherRepository.getAssignmentDetail()`.

**Returns:**
- All `assignments` table fields
- `class_name` from joined `classes`
- `total_students` count from `assignment_students`
- `completed_students` count (status = 'completed')

**Auth:** Caller must be the assignment's teacher or admin.

**Repository change:** `getAssignmentDetail()` calls this RPC instead of two separate queries.

### 3d. Mixed → Unit DB Constraint

Covered in Part 1 migration. Single migration handles both the constraint change and any enum updates.

---

## Part 4: Student Experience — Unit Assignment

### Assignment Detail Screen

Unit type assignment detail shows:

```
📘 Unit 3 - Daily Routines
Status: In Progress  |  Due: Mar 30  |  3 days left
Progress: ████████░░ 75% (3/4 items)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What to Do:
  📝 Greetings (12 words)              ✅ Completed
  📝 Family (8 words)                  ✅ Completed
  📝 Daily Activities (10 words)       ✅ Completed
  📖 My School Day (3/5 chapters)      🔄 In Progress
  🎮 Game                              — (not graded)
  🎁 Treasure                          — (not graded)
```

- Data fetched via `get_unit_assignment_items` RPC
- Word list and book items are tappable → navigate to respective screens
- Game/treasure shown but dimmed, marked "not graded"
- First tap on any item triggers `startAssignment` if status is `pending`

### Home Screen (Daily Quest)

Active unit assignments appear in the quest list (existing pattern). Progress percentage shown.

### Assignments List Screen

Unit assignments appear alongside book/vocabulary assignments. Grouped into To Do / Completed / Overdue as usual.

---

## Part 5: Teacher Experience — Unit Assignment Detail

### Assignment Detail Screen (Teacher)

Unit content section added below the stats bar:

```
Unit Content:
  📝 Greetings (12 words)
  📝 Family (8 words)
  📖 My School Day (5 chapters)
  🎮 Game
  🎁 Treasure
```

Data source: `get_class_learning_path_units` RPC filtered to the relevant unit (reuse from creation flow).

Student list remains the same — progress/score from `assignment_students` table.

---

## Files Affected (Summary)

### New Migrations
1. `YYYYMMDD000XXX_add_unit_assignment_type.sql` — CHECK constraint update
2. `YYYYMMDD000XXX_get_class_learning_path_units_rpc.sql` — teacher-side unit listing
3. `YYYYMMDD000XXX_calculate_unit_assignment_progress_rpc.sql` — progress calculation
4. `YYYYMMDD000XXX_get_unit_assignment_items_rpc.sql` — student-side item listing
5. `YYYYMMDD000XXX_get_assignment_detail_with_stats_rpc.sql` — teacher detail RPC

### Shared Package
- `assignment_type.dart` — remove `mixed`, add `unit`
- `rpc_functions.dart` — add 4 new RPC constants
- `tables.dart` — no changes needed

### Domain Layer
- `student_assignment.dart` — remove `chapterIds` getter, add `scopeLpUnitId` getter
- `assignment.dart` — no structural changes
- New use case: `GetClassLearningPathUnitsUseCase`
- New use case: `CalculateUnitAssignmentProgressUseCase`
- New use case: `GetUnitAssignmentItemsUseCase`
- Update: `CreateAssignmentUseCase` — add `unit` type validation

### Data Layer
- New model: `ClassLearningPathUnitModel` (for teacher unit selection)
- New model: `UnitAssignmentItemModel` (for student item listing)
- Update: `StudentAssignmentModel` — remove `chapterIds` reference
- Update: `SupabaseTeacherRepository` — `getAssignmentDetail` uses RPC
- New repo methods for unit-related RPCs

### Presentation Layer
- Update: `CreateAssignmentScreen` — add unit type + unit selection sheet
- Update: `StudentAssignmentDetailScreen` — unit item list view
- Update: `AssignmentDetailScreen` (teacher) — unit content section
- Update: `session_summary_screen.dart` — unit assignment progress trigger
- Update: `book_provider.dart` — unit assignment progress trigger
- Update: `student_assignments_screen.dart` — watch `assignmentSyncProvider`
- Update: `student_assignment_provider.dart` — extend sync for unit type
- Update: `ui_helpers.dart` — add unit type color/icon
- New providers for unit-related data fetching
