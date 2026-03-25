# Class Management Redesign — Design Spec

## Goal

Transform the Classes tab from a hybrid management+stats view into a dedicated class management tool. Separate management actions (Classes tab) from reporting (Reports tab) with appropriate features in each context.

## Scope

### Classes Tab Changes
- Remove stats from class list cards (avg progress)
- Remove stats bar from class detail (total XP, avg progress)
- Remove 3-dot menu with individual student actions
- Add class edit and delete to class list cards
- Add "View Password" on student tap
- Add multi-select + bulk move for students
- Keep student detail navigation (tap on student name → full profile)

### Reports Tab Changes
- Class Overview → Class tıklandığında → class detail stat'lı versiyon korunur
- But 3-dot student menu removed (no management actions in reports context)

### New Features
- Edit class (name, description)
- Delete class (only if empty)
- Bulk student transfer (multi-select → move to target class)
- View student password (`password_plain` field from profiles)

## Screen Redesign

### 1. Classes List (`/teacher/classes`)

**Current:** Card shows name, grade avatar, student count, academic year, avg progress (color-coded percentage text).

**New:** Card shows name, grade, student count, academic year. **No avg progress.** Each card has a 3-dot popup menu with:
- "Edit" → dialog to edit name/description
- "Delete" → only enabled if `studentCount == 0`, confirmation dialog

### 2. Class Detail — Management Mode (`/teacher/classes/:classId`)

**Current:** Stats bar (students, total XP, avg progress) + student list with 3-dot menu per student.

**New:**
- **No stats bar** — this is management, not reports
- AppBar title: class name (not "Class Students")
- AppBar actions: "Select" toggle button (to enter multi-select mode)
- Student card: avatar, full name, student number, level badge
  - **No XP/streak/books-read mini stats** — management view
  - **Tap** → shows bottom sheet with: student name, student number, email (copyable), password (if `password_plain` exists), "View Full Profile" button
- **Select mode:**
  - Checkbox appears on each student card
  - Bottom floating bar: "X selected — Move to..."
  - "Move to..." → bottom sheet with class list (excluding current) → confirm → bulk move

### 3. Class Detail — Report Mode (from Reports → Class Overview)

**Current:** Same `ClassDetailScreen` with stats + 3-dot menu.

**New:** Stats bar kept (students, total XP, avg progress). Student list with tap → navigate to student detail (full profile). **No 3-dot menu, no select mode, no password view.** Read-only report.

**Implementation:** Single `ClassDetailScreen` with a `mode` parameter:
- `ClassDetailMode.management` — from Classes tab
- `ClassDetailMode.report` — from Reports → Class Overview

Router passes the mode based on navigation source.

## Data Flow

### Existing (no changes needed)
- `currentTeacherClassesProvider` → class list
- `classStudentsProvider(classId)` → students in class
- `changeStudentClassUseCaseProvider` → move student (already RPC-based)
- `createClassUseCaseProvider` → create class

### New
- **Edit class:** New `UpdateClassUseCase` → `TeacherRepository.updateClass(classId, name, description)`
  - Direct `classes` table UPDATE — RLS allows teachers to update classes in their school
- **Delete class:** New `DeleteClassUseCase` → `TeacherRepository.deleteClass(classId)`
  - Direct `classes` table DELETE — RLS allows, but RPC preferred for safety (check student count server-side)
- **View password:** `password_plain` needs to be included in `get_students_in_class` RPC return columns
- **Bulk move:** Loop through selected students calling `changeStudentClassUseCaseProvider` for each, or preferably a new `bulk_move_students` RPC for atomicity

## New RPC Functions

### 1. `delete_class` — safe delete with student count check
```sql
CREATE OR REPLACE FUNCTION delete_class(p_class_id UUID)
RETURNS VOID
-- Checks: is_teacher_or_higher(), same school, student count = 0
-- Then: DELETE FROM classes WHERE id = p_class_id
```

### 2. `bulk_move_students` — atomic multi-student transfer
```sql
CREATE OR REPLACE FUNCTION bulk_move_students(
  p_student_ids UUID[],
  p_target_class_id UUID
)
RETURNS VOID
-- Checks: is_teacher_or_higher(), all students + target class in same school
-- Then: UPDATE profiles SET class_id = p_target_class_id WHERE id = ANY(p_student_ids)
```

### 3. Modify `get_students_in_class` — add `password_plain`
Add `password_plain TEXT` to the RETURNS TABLE of the existing function.

## Modified Files

| File | Change |
|------|--------|
| `supabase/migrations/20260325000014_class_management_rpcs.sql` | New RPCs + modify get_students_in_class |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add constants |
| `lib/domain/entities/teacher.dart` | Add `passwordPlain` to `StudentSummary` |
| `lib/data/models/teacher/student_summary_model.dart` | Read `password_plain` from JSON |
| `lib/domain/repositories/teacher_repository.dart` | Add `updateClass`, `deleteClass`, `bulkMoveStudents` |
| `lib/data/repositories/supabase/supabase_teacher_repository.dart` | Implement new methods |
| `lib/domain/usecases/teacher/update_class_usecase.dart` | New |
| `lib/domain/usecases/teacher/delete_class_usecase.dart` | New |
| `lib/domain/usecases/teacher/bulk_move_students_usecase.dart` | New |
| `lib/presentation/providers/usecase_providers.dart` | Register new providers |
| `lib/presentation/screens/teacher/classes_screen.dart` | Remove avg progress, add edit/delete menu |
| `lib/presentation/screens/teacher/class_detail_screen.dart` | Full rewrite — mode flag, select mode, new student card |
| `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart` | Pass report mode when navigating to class detail |
| `lib/app/router.dart` | Pass mode via `state.extra` to ClassDetailScreen |

## Error Handling

- Delete class with students → SnackBar: "Cannot delete class with students. Move all students first."
- Bulk move failure → SnackBar with error, refresh list
- Edit class failure → SnackBar with error

## Out of Scope

- Creating new students (admin panel feature)
- Class scheduling / timetable
- Class-level settings or permissions
- Assigning teachers to specific classes
