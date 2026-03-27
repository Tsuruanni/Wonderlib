# Learning Paths Audit Fixes

## Context

Feature #7 (Learning Paths) audit produced 21 findings. This spec covers the fix plan for 17 of them. 4 findings are deferred as known limitations.

## Scope

**Fix (17 findings):** #1-5 (security), #7-8 (architecture), #9-14 (dead code + code quality), #16-18 (database), #20 (edge case)
**Known limitation (4 findings):** #6, #15, #19, #21

Full finding details: `docs/specs/07-learning-paths.md` → Audit section.

## Approach

- Single SQL migration for all DB changes (security + housekeeping)
- Single Dart commit for all code changes (architecture + dead code + quality)
- 2 commits total

---

## Migration: Security Fixes

### #1 — `apply_learning_path_template` auth check

Drop and recreate function. Add at top of function body:

```sql
IF NOT EXISTS(
  SELECT 1 FROM profiles
  WHERE id = auth.uid()
  AND role IN ('admin', 'head', 'teacher')
) THEN
  RAISE EXCEPTION 'Unauthorized';
END IF;
```

Admin, head, and teacher can apply templates. Students cannot.

### #2 — `get_user_learning_paths` auth check

Drop and recreate function. Add at top:

```sql
IF auth.uid() != p_user_id THEN
  RAISE EXCEPTION 'Unauthorized';
END IF;
```

### #3 — `get_path_daily_reviews` auth check

Drop and recreate function. Add at top:

```sql
IF auth.uid() != p_user_id THEN
  RAISE EXCEPTION 'Unauthorized';
END IF;
```

### #4 — `path_daily_review_completions` RLS: block DELETE

Drop existing `users_own_data` policy (`FOR ALL`). Replace with three separate policies:

```sql
CREATE POLICY "users_select_own" ON path_daily_review_completions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own" ON path_daily_review_completions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own" ON path_daily_review_completions
  FOR UPDATE USING (auth.uid() = user_id);

-- No DELETE policy: students cannot delete their own DR completions
```

### #5 — Template RLS role mismatch: `head_teacher` → `head`

Three tables affected: `learning_path_templates`, `learning_path_template_units`, `learning_path_template_items`.

Drop and recreate the admin access policies on each table, changing `role IN ('admin', 'head_teacher')` to `role IN ('admin', 'head')`.

---

## Migration: Database Housekeeping

### #16 — `scope_learning_paths.class_id` FK: add ON DELETE CASCADE

```sql
ALTER TABLE scope_learning_paths
  DROP CONSTRAINT scope_learning_paths_class_id_fkey,
  ADD CONSTRAINT scope_learning_paths_class_id_fkey
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE;
```

When a class is deleted, its scope learning paths are also deleted.

### #17 — Add missing index on `scope_learning_paths.template_id`

```sql
CREATE INDEX idx_scope_lp_template ON scope_learning_paths(template_id);
```

### #18 — Drop redundant indexes on `path_daily_review_completions`

```sql
DROP INDEX IF EXISTS idx_path_dr_user;
DROP INDEX IF EXISTS idx_path_dr_unit;
```

The UNIQUE constraint on `(user_id, scope_lp_unit_id, completed_at)` already covers lookups by `user_id` as leading key.

### #20 — `apply_learning_path_template` sort_order: make atomic

In the already-recreated `apply_learning_path_template` function (from #1), wrap the sort_order calculation in a locked subquery:

```sql
v_sort_order := COALESCE((
  SELECT MAX(sort_order) + 1
  FROM scope_learning_paths
  WHERE school_id = p_school_id
    AND grade IS NOT DISTINCT FROM p_grade
    AND class_id IS NOT DISTINCT FROM p_class_id
  FOR UPDATE
), 0);
```

This prevents concurrent template applications from producing duplicate sort_order values.

---

## Dart: Architecture Fixes

### #7 — Add `GetStudentUnitProgressUseCase`

Create `lib/domain/usecases/assignment/get_student_unit_progress_usecase.dart`:
- Class: `GetStudentUnitProgressUseCase`
- Params: `GetStudentUnitProgressParams { assignmentId: String, studentId: String }`
- Delegates to `TeacherRepository.getStudentUnitProgress`

Register in `usecase_providers.dart`. Update `teacher_provider.dart` to call UseCase instead of repository directly.

### #8 — Raw string `itemType` → `LearningPathItemType` enum

**Entities** (change `String itemType` → `LearningPathItemType itemType`):
- `lib/domain/entities/class_learning_path_unit.dart` — `ClassLearningPathItem`
- `lib/domain/entities/unit_assignment_item.dart` — `UnitAssignmentItem`
- `lib/domain/entities/student_unit_progress_item.dart` — `StudentUnitProgressItem`

Update string comparisons:
- `i.itemType == 'word_list'` → `i.itemType == LearningPathItemType.wordList`
- `i.itemType == 'book'` → `i.itemType == LearningPathItemType.book`

**Models** (parse in fromJson):
- `class_learning_path_unit_model.dart` — use `LearningPathItemType.fromDbValue(json['item_type'])`
- `unit_assignment_item_model.dart` — same
- `student_unit_progress_item_model.dart` — same

---

## Dart: Dead Code Removal

### #9 — Delete `RpcFunctions.getPathDailyReviews`

Remove from `packages/owlio_shared/lib/src/constants/rpc_functions.dart`. Constant is declared but never called from any Dart code.

### #10 — Delete `LabelPosition.below` dead branch

In `lib/presentation/widgets/vocabulary/path_node.dart`:
- Remove `below` value from `LabelPosition` enum
- Remove the unreachable build branch that handles it

### #11 — Delete orphaned route `vocabularyUnitReviewPath`

In `lib/app/router.dart`:
- Remove the `AppRoutes.vocabularyUnitReviewPath` string constant
- Remove the corresponding `GoRoute` registration

### #12 — Delete stale comments

In `lib/presentation/widgets/vocabulary/path_node.dart`:
- Remove `// Pill removed`
- Remove `// Crown badge removed by user request`

### #13 — Delete duplicate `allAssignmentsProvider`

Remove the duplicate provider definition from `owlio_admin/lib/features/learning_path_assignments/screens/assignment_list_screen.dart`. If that screen imports it, update the import to reference the one in `template_list_screen.dart`.

---

## Dart: Code Quality

### #14 — Remove `debugPrint` statements

**`lib/data/repositories/supabase/supabase_teacher_repository.dart`:**
- Remove all 9 `debugPrint` calls
- Remove `import 'package:flutter/foundation.dart'` if no longer needed

**`lib/presentation/providers/teacher_provider.dart`:**
- Remove 2 `debugPrint` calls

---

## Known Limitations (no code changes)

| # | Finding | Rationale |
|---|---------|-----------|
| #6 | `authenticated_select` broad RLS on scope tables | Client uses RPCs exclusively, no direct table queries. Low risk. |
| #15 | `VocabularyUnit` adapter hack with fake timestamps | Deferred to type-based XP spec which will refactor path widgets. |
| #19 | Admin delete-then-reinsert cascades to DR completions | Admin saves are rare. Documented as known edge case. |
| #21 | `dailyWordListLimit = 30` hardcoded | Deferred to type-based XP spec which will move limits to `system_settings`. |

---

## Verification

After implementation:
1. `dart analyze lib/` — must pass with no issues
2. `supabase db push --dry-run` — verify migration applies cleanly
3. Manual test: student cannot call `apply_learning_path_template` (RPC auth)
4. Manual test: student cannot delete own `path_daily_review_completions` rows (RLS)
5. Manual test: head role user can manage templates (RLS fix)
6. Manual test: class deletion cascades to scope paths
7. Grep: no remaining `'word_list'` or `'book'` string literals in affected entities

## Spec Update

After all fixes are implemented, update `docs/specs/07-learning-paths.md`:
- Change status of fixed findings from `TODO` to `Fixed`
- Keep #6, #15, #19, #21 as `Known Limitation`
