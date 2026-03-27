# Daily Vocabulary Review

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Security | `complete_daily_review` RPC has no `auth.uid()` check — any authenticated user can award XP to another user by passing arbitrary `p_user_id`. `SECURITY DEFINER` bypasses RLS. | Critical | Fixed |
| 2 | Security | `get_due_review_words` RPC has no `auth.uid()` check — information disclosure of another user's vocabulary. | Medium | Fixed |
| 3 | Architecture | `daily_review_screen.dart` reads `vocabularyRepositoryProvider` directly for `saveDailyReviewPosition`. Missing UseCase wrapper — violates Screen → Provider → UseCase rule. | High | Fixed |
| 4 | Bug | `_isProcessingAnswer` flag not reset in `currentProgress == null` branch (`daily_review_provider.dart:385-394`). After one word without a progress record, all subsequent answers are silently dropped. Critical in unit review mode where unstarted words lack progress records. | High | Fixed |
| 5 | Bug | No error state in `DailyReviewState`. Network errors in `loadSession` and `loadUnitReviewSession` silently produce empty word lists — user sees "All caught up!" instead of an error with retry option. | High | Fixed |
| 6 | Bug | 10-word gate threshold mismatch: Flutter counts all due words (incl. mastered), quest RPC counts only non-mastered (`status != 'mastered'`). User can complete a DR session that the quest never registers. | Medium | Fixed |
| 7 | Bug | `saveDailyReviewPosition` uses `DateTime.now()` (device local time) while session record uses `app_current_date()` (Istanbul TZ). Near-midnight timezone mismatch causes `UPDATE` to match 0 rows. | Medium | Fixed |
| 8 | Bug | Completion dialog displays XP as "Coins" (`'+$xpEarned Coins'` at line 231). | Low | Fixed |
| 9 | Dead Code | `getWordProgressUseCase` injected into `DailyReviewController` but never called — batch variant used instead. | Medium | Fixed |
| 10 | Dead Code | `totalDueWordsForReviewProvider` is a trivial `.length` wrapper over `dailyReviewWordsProvider`. | Low | Fixed |
| 11 | Dead Code | `DailyReviewSessionModel.fromEntity` factory constructor — no code path converts entity back to model. | Low | Fixed |
| 12 | Dead Code | Audio button in `_CardFront` renders but `onPressed` is a stub (haptic only, no audio). | Low | Fixed |
| 13 | Performance | `loadUnitReviewSession` issues 2N DB queries (one `word_list_items` + one `vocabulary_words` per list) via `Future.wait`. Should be a single RPC with JOIN. | Medium | Deferred |
| 14 | Performance | `loadUnitReviewSession` fetches all word lists via `getAllWordListsUseCase` then filters client-side by `unitId`. No server-side filter. | Medium | Fixed |
| 15 | Performance | `get_due_review_words` RPC missing `status != 'mastered'` filter — cannot use the existing partial index `idx_vocabulary_progress_review`. Falls back to full scan. | Medium | Fixed |
| 16 | Code Quality | `dailyReviewWordsProvider`, `todayReviewSessionProvider`, `totalDueWordsForReviewProvider` missing `.autoDispose` — stay alive after all listeners unmount. | Low | Fixed |
| 17 | Code Quality | `.take(30)` in `dailyReviewWordsProvider` redundant with RPC `p_limit = 30`. | Low | Fixed |
| 18 | Code Quality | Mixed `Navigator.of(context).pop()` (line 353) vs `context.pop()` (line 269) — should use go_router consistently. | Low | Fixed |
| 19 | Code Quality | Completion dialog stats count all responses incl. requeues. `knownPercent` doesn't match first-pass accuracy used for XP. | Low | Fixed |
| 20 | Code Quality | `dailyReviewControllerProvider` throws unhandled `Exception('User not logged in')` if `currentUserIdProvider` is null — crashes screen instead of graceful redirect. | Medium | Fixed |

### Checklist Result

- **Architecture Compliance**: PASS — UseCase created for `saveDailyReviewPosition` (#3).
- **Code Quality**: PASS — autoDispose added (#16), redundant take removed (#17), nav consistent (#18), stats use first-pass (#19), auth handled (#20).
- **Dead Code**: PASS — Unused UseCase injection (#9), derived provider (#10), dead factory (#11), stub button (#12) all removed.
- **Database & Security**: PASS — Auth checks on both RPCs (#1, #2). Index aligned (#15).
- **Edge Cases & UX**: PASS — Error state added (#5), threshold aligned (#6), timezone fixed (#7), XP label corrected (#8).
- **Performance**: PASS — unitId filter added (#14). Index aligned (#15). N+1 deferred (#13).
- **Cross-System Integrity**: PASS — Quest/UI threshold aligned (#6). XP, badges, streak chain all correct.

---

## Overview

Daily Vocabulary Review is a spaced repetition drill that presents SM-2 due words to students as a daily practice session. Words become "due" when their `next_review_at` timestamp passes. The feature gates learning path progression — students must complete their daily review before advancing to new word lists. Two modes exist: **daily review** (standard SRS session with XP awards) and **unit review** (cram mode for all words in a unit, no XP). Admin and Teacher surfaces are N/A.

## Data Model

### Tables

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `daily_review_sessions` | user_id (FK profiles), session_date (DATE, UNIQUE with user_id), words_reviewed, correct_count, incorrect_count, xp_earned, is_perfect, completed_at, path_position | One row per user per day. Records session stats and XP. `path_position` saves where the DR node was in the learning path. |
| `path_daily_review_completions` | user_id, scope_lp_unit_id (FK scope_learning_path_units), position, completed_at (DATE), UNIQUE(user_id, scope_lp_unit_id, completed_at) | Tracks DR completion per unit per day for learning path gate logic. |
| `vocabulary_progress` | user_id, word_id, ease_factor, interval_days, repetitions, next_review_at, status | SM-2 word-level progress. `next_review_at <= NOW()` determines due words. Updated per-answer during session. |

### Key Relationships

- `daily_review_sessions.user_id` → `profiles.id` (CASCADE)
- `path_daily_review_completions.scope_lp_unit_id` → `scope_learning_path_units.id`
- Words are fetched from `vocabulary_progress` JOIN `vocabulary_words` via `get_due_review_words` RPC

## Surfaces

### Admin

N/A — Daily review is fully automatic. No admin configuration surface.

### Student

**Entry points:**
1. Home screen "Daily Review" button (visible when ≥ 10 due words)
2. Learning path DR gate node (injected automatically when ≥ 10 due words)
3. Unit review node on learning path (cram mode — all unit words regardless of SRS schedule)

**Daily Review flow:**
1. Screen opens → `loadSession()` fetches up to 30 due words via `get_due_review_words` RPC
2. Session composed: max 20 non-mastered + max 5 mastered reinforcement = max 25 words total
3. Words ordered by most overdue first
4. Flashcard presented (front: word, phonetic, part of speech; back: definition, example sentence)
5. User taps to flip, then responds: Hard (😕) / Good (😊) / Easy (🚀)
6. **First answer writes SM-2 progress to DB immediately** (first-answer-wins semantics)
7. Hard responses requeue the word (max 2 requeues per word per session)
8. Requeued answers update local state only — no additional DB writes
9. After all words: `complete_daily_review` RPC called atomically (insert session, award XP, check badges)
10. `path_position` saved to session row so completed DR node stays fixed in learning path
11. Completion dialog shows stats and XP earned

**Unit Review (cram mode) flow:**
1. Launched from unit practice node on learning path with `unitId`
2. Fetches all words from all word lists in the unit (ignores SRS schedule)
3. Words shuffled for variety — no minimum count gate
4. Same flashcard UI and response mechanics
5. On completion: `completePathNode` called to mark unit node complete
6. `complete_daily_review` RPC is **not** called — no session XP, no quest credit

### Teacher

N/A — No teacher-facing view for daily review sessions.

## Business Rules

1. **Minimum threshold**: Daily review requires ≥ 10 due words (constant `minDailyReviewCount = 10`). Below this, the DR button and path gate do not appear.
2. **Session composition**: Max 20 non-mastered words + max 5 mastered reinforcement words = max 25 total. Ordered by most overdue first.
3. **First-answer-wins**: Only the first response to a word updates SM-2 in the database. Requeued attempts affect local state only.
4. **Requeue limit**: Hard responses requeue a word up to 2 times per session.
5. **XP formula**: `(correctCount × 5) + 10 session bonus [+ 20 perfect bonus if 100% first-pass accuracy]`. Only first-pass counts are used.
6. **Idempotency**: One session per user per day. Re-calling the RPC on the same day returns `is_new_session = false` with 0 XP.
7. **Learning path gate**: When daily review is needed (≥ 10 due words, not yet completed today), a DR node is injected into the learning path. Word list nodes are blocked until DR is completed.
8. **Position persistence**: After completion, `path_position` is saved so the completed DR node stays at the same position when the path is revisited.
9. **Streak**: NOT updated by daily review. Streak is login-based only (updated on app open).
10. **Unit review isolation**: Unit review (cram mode) does not create a `daily_review_sessions` record, does not award session XP, and does not satisfy the daily review gate.

## Cross-System Interactions

### XP Chain
```
Daily review completed
  → complete_daily_review RPC (atomic)
    → daily_review_sessions INSERT
    → award_xp_transaction(xp, 'daily_review', session_id)
      → profiles.total_xp += xp
      → xp_logs INSERT
    → check_and_award_badges(user_id)
      → badge threshold checks
      → user_badges INSERT if earned
  → Client: refreshProfileOnly() → navbar XP updates
  → Client: invalidate leaderboardEntriesProvider
```

### Daily Quest Integration
```
Quest type 'daily_review' in get_daily_quest_progress RPC:
  → Count non-mastered due words (status != 'mastered', next_review_at <= NOW())
  → IF count < 10: quest skipped entirely (not shown)
  → IF count >= 10: check daily_review_sessions for today
    → Session exists: quest complete, award quest XP
    → No session: quest in progress (0/1)
```

### Learning Path Integration
```
learningPathProvider builds path:
  → Check dailyReviewWordsProvider.length >= 10
  → Check todayReviewSessionProvider (completed today?)
  → IF needed and not done: inject PathDailyReviewItem before first locked non-exempt item
  → dailyReviewNeededProvider = true → blocks word list navigation with dialog
  → After completion: providers invalidated → gate clears → path rebuilds
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| < 10 due words | DR button hidden, path gate not injected, quest skipped |
| Exactly 10 due words | Gate active, session loadable |
| 0% accuracy (all Hard) | 10 XP (session bonus only), quest still completes |
| 100% accuracy (Perfect) | Base + 10 + 20 bonus XP, "Perfect Session!" in dialog |
| Re-submission same day | RPC returns `is_new_session=false`, 0 XP, dialog shown without XP |
| Network error during load | Error state shown with "Try Again" button (Fixed #5) |
| Word without progress record | Initial SM-2 values created, session continues (Fixed #4) |
| Near-midnight timezone mismatch | Position saved by session ID, not date (Fixed #7) |
| Logged-out user navigates to DR | Error state shown: "Not authenticated" (Fixed #20) |

## Test Scenarios

- [ ] **Happy path**: Open daily review with ≥ 10 due words, answer all, verify XP = `(correct × 5) + 10 [+ 20 if perfect]`, verify quest completes, verify DR gate clears on learning path
- [ ] **Empty state**: User has < 10 due words → DR button hidden on home/profile, no path gate node
- [ ] **Error state**: Disconnect network before session load → error screen with "Try Again" button
- [ ] **Boundary — 10 words**: Exactly 10 due non-mastered words → session starts, quest registers
- [ ] **Boundary — 0% accuracy**: Answer all Hard → 10 XP only (session bonus), quest still marks complete
- [ ] **Boundary — 100% accuracy**: Answer all Easy/Good → perfect bonus 20 XP, "Perfect Session!" display
- [ ] **Requeue**: Answer Hard → word reappears later → second answer doesn't re-write SM-2 progress
- [ ] **Max requeue**: Answer Hard 3 times on same word → word stops requeuing after 2nd requeue
- [ ] **Idempotency**: Complete DR, navigate away, open DR again → second session shows "All caught up!" or empty (words no longer due), re-calling RPC returns 0 XP
- [ ] **Learning path gate**: With ≥ 10 due words, tap word list node → "Complete daily review first" dialog → complete DR → word list node now tappable
- [ ] **Unit review (cram)**: Open unit review node → all unit words shown (no 10-word gate) → completion marks path node, no session XP, no quest credit
- [ ] **XP → badge chain**: Earn enough XP from DR to cross a badge threshold → badge awarded server-side
- [ ] **Cross-device**: Complete DR on device A → open on device B → DR shows as completed, path gate cleared

## Key Files

| Layer | File | Purpose |
|-------|------|---------|
| Entity | `lib/domain/entities/daily_review_session.dart` | `DailyReviewSession`, `DailyReviewResult` domain models |
| UseCases | `lib/domain/usecases/vocabulary/complete_daily_review_usecase.dart` | Complete session RPC call |
| UseCases | `lib/domain/usecases/vocabulary/get_due_for_review_usecase.dart` | Fetch due words |
| UseCases | `lib/domain/usecases/vocabulary/get_today_review_session_usecase.dart` | Check today's completion |
| UseCases | `lib/domain/usecases/vocabulary/save_daily_review_position_usecase.dart` | Save DR position in learning path |
| Model | `lib/data/models/vocabulary/daily_review_session_model.dart` | JSON serialization |
| Repository | `lib/data/repositories/supabase/supabase_vocabulary_repository.dart` | Supabase queries and RPC calls |
| Provider | `lib/presentation/providers/daily_review_provider.dart` | `DailyReviewController`, state, FutureProviders |
| Screen | `lib/presentation/screens/vocabulary/daily_review_screen.dart` | Flashcard UI, completion dialog |
| Path Integration | `lib/presentation/providers/vocabulary_provider.dart` | DR injection, gate logic, `dailyReviewNeededProvider` |
| Migration | `supabase/migrations/20260203000001_add_daily_review_sessions.sql` | Table + `complete_daily_review` RPC (original) |
| Migration | `supabase/migrations/20260327000008_get_due_review_words_rpc.sql` | `get_due_review_words` RPC (original) |
| Migration | `supabase/migrations/20260328000003_daily_review_audit_fixes.sql` | Auth checks + mastered filter (deployed) |

## Known Issues & Tech Debt

1. **Performance — Unit review N+1** (#13): `loadUnitReviewSession` issues 2N DB queries per unit (one `word_list_items` + one `vocabulary_words` per list). A single RPC with JOIN would eliminate this. Low priority — `Future.wait` already parallelizes the calls.
