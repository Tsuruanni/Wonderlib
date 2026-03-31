# Learning Paths

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Security | `apply_learning_path_template` RPC has no `auth.uid()` check — any authenticated user can create scope paths for any school | High | Fixed |
| 2 | Security | `get_user_learning_paths` RPC has no `auth.uid()` check — any user can fetch another user's paths | Medium | Fixed |
| 3 | Security | `get_path_daily_reviews` RPC has no `auth.uid()` check — any user can query another user's DR history | Medium | Fixed |
| 4 | Security | `path_daily_review_completions` RLS uses `FOR ALL` — students can DELETE own rows and replay daily review | Medium | Fixed |
| 5 | Security | `head_teacher` role in template RLS policies doesn't match `profiles.role` CHECK which uses `head` — head teachers cannot manage templates | Medium | Fixed |
| 6 | Security | `authenticated_select` on scope tables is too broad — any user can read all schools' curriculum via direct table access | Low | Known Limitation |
| 7 | Architecture | `getStudentUnitProgress` skips UseCase layer — teacher provider calls repository directly | Low | Fixed (pre-existing) |
| 8 | Architecture | `itemType` stored as raw `String` in 3 entities (`ClassLearningPathUnit`, `UnitAssignmentItem`, `StudentUnitProgressItem`) instead of using `LearningPathItemType` enum — fragile string comparisons | Medium | Fixed |
| 9 | Dead Code | `RpcFunctions.getPathDailyReviews` declared in shared package but never called from any Dart code | Low | Fixed |
| 10 | Dead Code | `LabelPosition.below` enum value and its build branch in `PathNode` are unreachable — no caller passes this value | Low | Fixed |
| 11 | Dead Code | Orphaned route `AppRoutes.vocabularyUnitReviewPath` — GoRoute registered but zero callers | Low | Fixed |
| 12 | Dead Code | Stale comments in `path_node.dart`: `// Pill removed`, `// Crown badge removed by user request` | Low | Fixed |
| 13 | Dead Code | Duplicate `allAssignmentsProvider` in admin — defined in both `template_list_screen.dart` and `assignment_list_screen.dart` | Low | Fixed |
| 14 | Code Quality | `debugPrint` statements left in `supabase_teacher_repository.dart` (9 calls) and `teacher_provider.dart` (2 calls) | Low | Fixed |
| 15 | Code Quality | `VocabularyUnit` adapter hack in `learningPathProvider` — synthesizes instances with fake `DateTime.now()` timestamps for legacy widget compatibility | Low | Known Limitation |
| 16 | Database | `scope_learning_paths.class_id` FK has no `ON DELETE CASCADE` — class deletion fails if scope paths reference it | Medium | Fixed |
| 17 | Database | Missing index on `scope_learning_paths.template_id` | Low | Fixed |
| 18 | Database | Redundant single-column indexes on `path_daily_review_completions` (covered by unique composite) | Low | Fixed |
| 19 | Edge Case | Admin delete-then-reinsert save strategy cascades delete to `path_daily_review_completions`, silently resetting student DR progress | Medium | Known Limitation |
| 20 | Edge Case | `apply_learning_path_template` sort_order calculation is non-atomic — concurrent applications can produce duplicate sort_order | Low | Fixed |
| 21 | Performance | `dailyWordListLimit = 30` hardcoded in provider — not configurable from `system_settings` | Low | Known Limitation |

### Checklist Result

- **Architecture Compliance**: 2 issues (#7, #8)
- **Code Quality**: 2 issues (#14, #15)
- **Dead Code**: 5 issues (#9, #10, #11, #12, #13)
- **Database & Security**: 8 issues (#1, #2, #3, #4, #5, #6, #16, #17)
- **Edge Cases & UX**: 2 issues (#19, #20)
- **Performance**: 1 issue (#21)
- **Cross-System Integrity**: PASS

---

## Overview

Learning Paths is a hierarchical content delivery system that organizes vocabulary word lists, books, mini-games, and treasure rewards into a Duolingo-style vertical path for students. Admins create **templates** (template → units → items), then **assign** them to scopes (school, grade, or class). Students see their assigned path as an interactive map with sequential unlock, daily review gates, and progress tracking. Teachers use path units when creating unit-type assignments.

## Data Model

Two parallel hierarchies:

**Template tables (admin authoring):**
- `learning_path_templates` → `learning_path_template_units` → `learning_path_template_items`
- Templates are blueprints that can be applied to multiple scopes

**Scope tables (runtime, student-facing):**
- `scope_learning_paths` → `scope_learning_path_units` → `scope_unit_items`
- Created by applying a template to a scope (school/grade/class)
- Each scope path is an independent copy — editing a template does NOT update existing scope paths

**Progress tracking:**
- `user_node_completions` — game/treasure node completions (in vocabulary tables)

**Key relationships:**
- `scope_learning_path_units.unit_id` → `vocabulary_units(id)` — units are shared containers with the vocabulary system
- `scope_unit_items.word_list_id` → `word_lists(id)` — word list items link to the vocabulary word list system
- `scope_unit_items.book_id` → `books(id)` — book items link to the book system
- `scope_learning_paths` uses a scope resolution pattern: `school_id` (required) + optional `grade` or `class_id` (mutually exclusive via CHECK constraint)

**Item types:** `word_list`, `book`, `game`, `treasure` (from `LearningPathItemType` enum in owlio_shared)

## Surfaces

### Admin

**Template Management:**
- CRUD for templates at `/learning-paths` (Şablonlar tab)
- Each template has a name, description, and lock settings (`sequential_lock`, `books_exempt_from_lock`)
- Template units reference `vocabulary_units` — drag-and-drop reorder via `LearningPathTreeView` widget
- Template items within each unit: word lists, books, game nodes, treasure nodes — drag-and-drop reorder
- Save strategy: delete-then-reinsert all units/items on every save (no diff)

**Scope Assignment:**
- At `/learning-paths` (Atamalar tab), admin selects a scope (school, grade, or class)
- Can apply a template to create a new scope path (via `apply_learning_path_template` RPC)
- Can also create empty scope paths and add units/items manually
- Lock settings can be toggled per scope path independently from the source template
- Save strategy: same delete-then-reinsert as templates

### Student

**Path Navigation (Duolingo-style vertical map):**
1. Student opens Vocabulary Hub → sees `LearningPath` widget
2. Path renders as a sine-wave vertical layout with nodes for each item
3. Node types with distinct visuals:
   - **Word List nodes** (`PathNode`) — circular with star rating, progress indicator, tap to open word list detail/session
   - **Book nodes** (`PathBookNode`) — book icon with cover, tap to open book reader
   - **Game nodes** (`PathGameNode`) — mini-game icon, tap to complete (one-time)
   - **Treasure nodes** (`PathTreasureNode`) — chest icon, tap to collect reward (one-time)
   - ~~Daily Review gate~~ — removed. Gating is now dialog-only (no visible path node).
4. **Unit banners** (`PathUnitBanner`) separate units visually with unit name and icon

**Sequential Lock System:**
- When `sequential_lock = true` on the scope path, items unlock one at a time
- An item is locked if the previous item in the same unit is not completed
- When `books_exempt_from_lock = true`, book items are always accessible regardless of lock state
- Lock calculation runs in `calculateLocks()` function in `vocabulary_provider.dart`

**Daily Review Gate:**
- If student has ≥ `minDailyReviewCount` (10) words due for review, word list nodes show a dialog prompting daily review completion
- No visible node is rendered in the path — gating is dialog-only via `dailyReviewNeededProvider`
- After completing DR (from home screen or daily quest), providers are invalidated and word lists become accessible

**Progress Tracking:**
- Word list completion: tracked via `user_word_list_progress` (star rating 0–3 based on accuracy)
- Book completion: tracked via `reading_progress.is_completed`
- Game/treasure completion: tracked via `user_node_completions` table
- DR completion: gated via `dailyReviewNeededProvider` (checks due word count + today's session)

**Daily Word Limit:**
- Students can start at most `dailyWordListLimit` (30) new words per day across all word lists
- Enforced in `canStartWordListProvider` — disables word list nodes when limit reached

### Teacher

- Teachers select learning path units when creating **unit-type assignments** via `CreateAssignmentScreen`
- `classLearningPathUnitsProvider(classId)` fetches available units for the teacher's class
- Teacher can view per-student unit progress via `getStudentUnitProgress` RPC in assignment detail view
- No direct path management — teachers consume the paths assigned by admins

## Business Rules

1. **Scope resolution order**: When fetching a student's paths, the RPC unions paths matching: (a) student's `class_id`, (b) student's `grade` + `school_id`, (c) `school_id` only (school-wide). A student can see paths from all three scopes simultaneously.
2. **Template application is a copy**: `apply_learning_path_template` copies template structure into scope tables. Subsequent template edits do NOT propagate to existing scope paths.
3. **Mutual exclusivity**: A scope path targets either a grade OR a class, never both (enforced by CHECK constraint). School-wide paths have both `grade` and `class_id` as NULL.
4. **Sequential lock**: When enabled, each item in a unit must be completed before the next unlocks. The lock applies within units only — the first item of a new unit is always accessible.
5. **Books exempt from lock**: When enabled, book-type items in the path are never locked, even if the previous item is incomplete. This allows students to read freely while vocabulary is gated.
6. **Daily review gate**: When `totalDueWords >= minDailyReviewCount (10)` and no session completed today, word list nodes are gated via dialog prompt. No path node is rendered.
7. **Game and treasure nodes are non-trackable**: They do not count toward assignment progress calculations. Only `word_list` and `book` items contribute to unit assignment progress.
8. **Daily word limit**: 30 new words per day across all lists (hardcoded, not from system_settings).
9. **Node completion is idempotent**: Game/treasure nodes check `user_node_completions` before inserting. DR completion has a UNIQUE constraint on `(user_id, scope_lp_unit_id, completed_at)`.
10. **Class change handling**: When a student's `class_id` changes, a trigger fires `handle_student_class_change()` which withdraws the student from old class assignments and backfills them into new class unit assignments.
11. **Assignment progress for units**: `calculate_unit_assignment_progress` counts completed trackable items (word_list with ≥1 session, book with `is_completed = true`) divided by total trackable items. `sync_unit_assignment_progress` runs this for all non-withdrawn students in a unit assignment.

## Cross-System Interactions

**Learning Path → Vocabulary:**
- Path word list items link to `word_lists` — tapping a node opens the word list detail/session flow
- Completing a vocabulary session updates `user_word_list_progress` → path node shows updated star rating
- Daily review session completion invalidates `learningPathProvider` → DR gate refreshes

**Learning Path → Books:**
- Path book items link to `books` — tapping opens the book reader
- Book/chapter completion updates `reading_progress` → path node shows completion state
- Book completion contributes to unit assignment progress

**Learning Path → Assignment System:**
- Teachers create unit-type assignments referencing `scope_learning_path_units`
- Student progress auto-tracked: `calculateUnitAssignmentProgress` checks item completions
- `syncUnitAssignmentProgress` runs after assignment creation to backfill existing progress
- Class change trigger handles student reassignment

**Learning Path → XP/Gamification:**
- Path itself does NOT award XP — XP is earned through the activities within the path (vocab sessions, book chapters, inline activities)
- Game/treasure node completions do NOT award XP (they are cosmetic milestones)

**Learning Path → Daily Quest:**
- Activities completed within path items (chapters read, vocab sessions) count toward daily quest progress implicitly

## Edge Cases

- **Student with no assigned path**: Empty state shown — owl icon + message explaining teacher will assign a path
- **Student changes class**: Trigger withdraws from old assignments, backfills into new class assignments. Old paths from different scope remain visible (school/grade-level paths persist).
- **Admin re-saves scope path**: Delete-then-reinsert resets scope structure — students see refreshed path
- **Concurrent template application**: Sort order calculation uses non-atomic `MAX(sort_order) + 1` — concurrent applications to same scope can produce duplicate sort_order values
- **All items completed in path**: No explicit "path complete" event — students simply see all nodes as completed
- **Daily word limit reached**: Word list nodes become non-tappable, showing a tooltip about the daily limit
- **Word list or book deleted**: FK cascade (`ON DELETE CASCADE`) removes the item from scope tables. Path re-renders without the deleted item.
- **Class deletion blocked**: `scope_learning_paths.class_id` FK defaults to RESTRICT — must delete scope paths first

## Test Scenarios

- [ ] Happy path: Admin creates template → applies to class → student sees path with correct units/items
- [ ] Sequential lock: Items unlock one-by-one after each completion
- [ ] Books exempt: Book nodes accessible even when previous word list is locked
- [ ] Daily review gate: DR node appears when ≥10 words due, blocks until completed, disappears after
- [ ] Game/treasure: Tap completes node, second tap shows "already completed"
- [ ] Unit assignment: Teacher creates unit assignment → student completes items → progress updates
- [ ] Class change: Student transferred to new class → old assignments withdrawn, new assignments backfilled
- [ ] Empty state: Student with no path sees empty message
- [ ] Daily word limit: After 30 new words, word list nodes show limit reached
- [ ] Admin re-save: Editing and saving a scope path preserves unit structure (verify DR progress impact)
- [ ] Scope resolution: Student sees school-wide + grade-level + class-level paths simultaneously

## Key Files

**Student path:**
- `lib/presentation/widgets/vocabulary/learning_path.dart` — main path renderer
- `lib/presentation/providers/vocabulary_provider.dart` (lines 420–784) — `learningPathProvider` + lock calculation + path data assembly

**Admin:**
- `owlio_admin/lib/features/templates/screens/template_edit_screen.dart` — template CRUD
- `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart` — scope assignment CRUD

**Database:**
- `supabase/migrations/20260320000001_create_learning_path_tables.sql` — core schema
- `supabase/migrations/20260320000002_create_learning_path_rpcs.sql` — core RPCs
- `supabase/migrations/20260327000009_student_class_change_sync.sql` — class change trigger

## Known Issues & Tech Debt

1. **Security: 2 RPCs missing auth checks** (#1, #2) — `apply_learning_path_template`, `get_user_learning_paths` need `auth.uid()` validation
2. **Security: head_teacher role mismatch** (#5) — template RLS uses `'head_teacher'` but profiles CHECK uses `'head'`
3. **Architecture: raw string itemType** (#8) — 3 entities use `String` instead of `LearningPathItemType` enum for type comparisons
4. **Admin save strategy** (#19) — delete-then-reinsert resets scope structure on re-save
6. **`VocabularyUnit` adapter** (#15) — path widgets depend on legacy `VocabularyUnit` entity with fake timestamps
7. **`dailyWordListLimit` hardcoded** (#21) — should come from `system_settings` (planned for type-based XP migration)
8. **Orphaned tables in migration history** — `unit_book_assignments` and `unit_curriculum_assignments` creation migrations still exist (tables were dropped in `20260320000003`)
