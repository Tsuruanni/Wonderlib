# Remove Learning Path Review Node

## Problem

The daily review node injected into the learning path causes two issues:

1. **Ordering disruption**: The dynamically injected `PathDailyReviewItem` uses custom sort tie-breaking and sticky `pathPosition` logic that shifts node positions unpredictably.
2. **Unnecessary complexity**: The injection logic (position calculation, per-unit completion tracking, sticky positioning after completion) adds significant code surface area for a node that students can already access from the home screen.

## Decision

Remove the review node from the learning path visual rendering. Keep the daily review gating behavior — students must still complete their daily review before accessing word lists. The gating manifests as a dialog prompt, not as a path node.

## Scope

### What changes

**Presentation layer — `vocabulary_provider.dart`:**
- Remove `PathDailyReviewItem` sealed class
- Remove injection logic (daily review node insertion into the item list)
- Remove sort tie-breaking for review nodes
- Remove `isAllComplete` review node exclusion
- Keep `dailyReviewNeededProvider` (still gates word list access)

**Presentation layer — `learning_path.dart`:**
- Remove review node → `MapTileNodeData` mapping
- Remove `PathDailyReviewItem` check in active node detection

**Presentation layer — `path_node.dart`:**
- Remove `NodeType.review` enum value

**Presentation layer — `daily_review_screen.dart`:**
- Remove `pathPosition` save call after DR completion

**Presentation layer — `daily_review_provider.dart`:**
- Remove `saveDailyReviewPositionUseCase` field and constructor injection from `DailyReviewController`
- Remove `saveDailyReviewPosition` method
- Remove `saveDailyReviewPositionUseCaseProvider` watch from controller provider constructors

**Domain layer — `daily_review_session.dart`:**
- Remove `pathPosition` field from entity

**Domain layer — `vocabulary_repository.dart`:**
- Remove `saveDailyReviewPosition` method

**Domain layer — `save_daily_review_position_usecase.dart`:**
- Delete file entirely

**Data layer — `daily_review_session_model.dart`:**
- Remove `pathPosition` field and JSON mapping

**Data layer — `supabase_vocabulary_repository.dart`:**
- Remove `saveDailyReviewPosition` implementation

**Shared package — `tables.dart`:**
- Remove `pathDailyReviewCompletions` constant

**Provider registration — `usecase_providers.dart`:**
- Remove `saveDailyReviewPositionUseCaseProvider` (line 384)

**Database (new migration):**
- `DROP TABLE path_daily_review_completions` (unused in client code — only a shared constant references it, never read/written from Dart)
- `ALTER TABLE daily_review_sessions DROP COLUMN path_position`
- `DROP FUNCTION get_path_daily_reviews` (already dead code per audit finding #9)

### What stays unchanged

- `dailyReviewNeededProvider` — word list gating via dialog
- `dailyReviewWordsProvider` / `todayReviewSessionProvider` — threshold checks
- `minDailyReviewCount` constant (10 words)
- `complete_daily_review` RPC — XP award chain
- Home screen daily review button
- Daily quest `daily_review` type integration
- `daily_review_sessions` table (minus `path_position` column)

## Risk Assessment

**Low risk.** All removed code is isolated to review node rendering and position tracking. The gating behavior depends on `dailyReviewNeededProvider` which reads from `dailyReviewWordsProvider` and `todayReviewSessionProvider` — neither touches the removed code paths.

The `path_daily_review_completions` table is never read or written from any Dart code (confirmed via grep). The `get_path_daily_reviews` RPC was already flagged as dead code in the learning paths audit.

## Verification

- `dart analyze lib/` passes with no errors
- Learning path renders without review nodes
- Word list gating dialog still appears when daily review is pending
- Daily review completes successfully from home screen (no pathPosition save errors)
- Daily quest daily_review type still works
