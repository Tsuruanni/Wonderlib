# Owlio Feature Map — Unified (App + Admin + Teacher)

Each feature spans up to 3 surfaces: Admin (content creation), App (student experience), Teacher (monitoring/management). Feature specs should cover all surfaces for that system.

---

## Feature Spec Process

Each feature goes through: **Review → Fix → Document → Track**. All in one spec file at `docs/specs/NN-feature-name.md`.

### Review Checklist

Run this checklist for every feature. Document findings in the spec's Audit section.

**Architecture Compliance:**
- [ ] Clean architecture layers respected (Screen → Provider → UseCase → Repository)
- [ ] No business logic in widgets (moved to providers)
- [ ] No JSON in entities (handled in models)
- [ ] Shared package used (DbTables, RpcFunctions, enums from owlio_shared)
- [ ] No hard-coded table/RPC strings

**Code Quality:**
- [ ] Either pattern for error handling
- [ ] Consistent naming conventions
- [ ] No duplicate code
- [ ] Provider lifecycle correct (autoDispose where needed)

**Dead Code:**
- [ ] No unused imports, functions, providers, or usecases
- [ ] No commented-out code
- [ ] No unreachable code paths

**Database & Security:**
- [ ] RLS policies exist and are correct
- [ ] RPC functions enforce auth checks
- [ ] Indexes exist for frequently queried columns
- [ ] Cascading deletes handled properly
- [ ] Idempotency protection (especially XP/coin operations)

**Edge Cases & UX:**
- [ ] Empty state handled (no data scenario)
- [ ] Loading state shown
- [ ] Error state displayed to user
- [ ] Null values handled safely
- [ ] Boundary values respected (max/min limits)

**Performance:**
- [ ] No N+1 query problems
- [ ] No unnecessary provider rebuilds
- [ ] Pagination used where data can grow large

**Cross-System Integrity:**
- [ ] XP/coin awards trigger correctly
- [ ] Badge checks fire where needed
- [ ] Streak updates happen at right moments
- [ ] Assignment progress syncs properly

**Test Scenarios:**
- [ ] Happy path scenarios documented
- [ ] Empty/error/boundary states covered
- [ ] Cross-system side effects verified

### Spec Template

```markdown
# [Feature Name]

## Audit

### Findings
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | Unused `getXxxUseCase` in providers | Low | Fixed |
| 2 | Edge Case | No empty state when student has 0 cards | Medium | TODO |

### Checklist Result
- Architecture Compliance: PASS / X issues
- Code Quality: PASS / X issues
- Dead Code: PASS / X issues
- Database & Security: PASS / X issues
- Edge Cases & UX: PASS / X issues
- Performance: PASS / X issues
- Cross-System Integrity: PASS / X issues

---

## Overview
One paragraph: what this feature does, who uses it.

## Data Model
- DB tables involved (only business-critical columns)
- Key relationships between tables

## Surfaces

### Admin
- What admin can create/edit/delete
- Key workflows
(N/A if not applicable)

### Student
- User flow (step by step)
- Key screens and interactions
(N/A if not applicable)

### Teacher
- What teacher sees/does
(N/A if not applicable)

## Business Rules
- Numbered list of rules that CAN'T be inferred from code
- XP rewards, limits, conditions, state transitions, formulas

## Cross-System Interactions
- What other systems this triggers (XP, badges, streak, coins)
- Chain: "event → consequence → consequence"

## Edge Cases
- Empty states, error scenarios, boundary conditions

## Test Scenarios
Manual test cases for pre-production verification. Each scenario = one user action with expected outcome.
- [ ] Happy path: typical user flow works end-to-end
- [ ] Empty state: what user sees with no data
- [ ] Error state: what happens when backend fails
- [ ] Boundary: min/max limits respected
- [ ] Cross-system: triggered side effects work (XP, badges, streak, etc.)
- [ ] (Add feature-specific scenarios here)

## Key Files
- Main entry points only (1-3 files per surface)

## Known Issues & Tech Debt
- Current workarounds, planned refactors (if any)
```

### Spec Rules
- **English only** — consistent with codebase language
- **Mark empty surfaces as N/A** — distinguishes "not applicable" from "not yet documented"
- **Business rules over structure** — Claude can read code for structure, it can't infer implicit rules
- **Audit first, document second** — run the review checklist, fix issues, then write the spec
- **Update with code** — spec and code ship in the same commit when possible
- **One file per system** — named `docs/specs/NN-feature-name.md` (matches feature number below)
- **Update tracking on completion** — add spec to CLAUDE.md Feature Documentation table and update Spec Status column in this file

### How to Start a Review Session

Open a new Claude Code session and say:

```
features.md'deki spec process'i takip ederek Feature #N (Feature Name) için
audit + spec yaz. Önce review checklist'i çalıştır, bulguları raporla,
sonra spec dökümanını oluştur. Bitince CLAUDE.md'deki Feature Documentation
tablosuna ve features.md'deki Spec Status sütununa ekle.
```

Replace `#N` and `Feature Name` with the target feature.

---

## Learning & Reading

| # | System | Admin Surface | App Surface | Teacher Surface | Spec Priority | Spec Status |
|---|--------|---------------|-------------|-----------------|---------------|-------------|
| 1 | **Book System** | Book CRUD, JSON import, chapter editor, content blocks | Library, book detail, reader, chapter progress, offline download | Reading progress report, book stats | Medium | Done: `docs/specs/01-book-system.md` |
| 2 | **Audio/Karaoke Reader** | Audio URLs in content blocks | Word-level sync, listening mode, auto-play, scroll follow | - | **High** | Done: `docs/specs/02-audio-karaoke-reader.md` |
| 3 | **Inline Activities** | Activity editor (4 types: true_false, word_translation, find_words, matching) | In-chapter mini games, XP rewards, vocab integration | - | Medium | Done: `docs/specs/03-inline-activities.md` |
| 4 | **Book Quiz** | Quiz editor (5 types: multiple_choice, fill_blank, event_sequencing, matching, who_says_what) | End-of-book assessment, 70% pass threshold, multi-attempt | Quiz results per student | Medium | Done: `docs/specs/04-book-quiz.md` |
| 5 | **Vocabulary & Spaced Repetition** | Vocabulary CRUD, CSV import | SM-2 algorithm, 10 question types, 3 tiers/phases, mastery levels | Vocab stats per student | **High** | Done: `docs/specs/05-vocabulary-spaced-repetition.md` |
| 6 | **Word Lists** | Word list editor, word picker, drag-and-drop reordering | Categorized lists, star rating, sequential unlock | Word list progress per student | Medium | Done: `docs/specs/06-word-lists.md` |
| 7 | **Learning Paths** | Template editor (template > units > items), scope-based assignment (school/grade/class) | Path navigation, unit unlock, progress tracking | - | **High** | Done: `docs/specs/07-learning-paths.md` |
| 8 | **Daily Vocabulary Review** | - | Daily drill from SM-2 due words, triggers streak | - | Low | Done: `docs/specs/08-daily-vocabulary-review.md` |

## Gamification

| # | System | Admin Surface | App Surface | Teacher Surface | Spec Priority | Spec Status |
|---|--------|---------------|-------------|-----------------|---------------|-------------|
| 9 | **XP/Leveling** | System settings (XP values per activity type) | Earn XP, combo bonuses, level progression | XP-based ranking in reports | **High** | Done: `docs/specs/09-xp-leveling.md` |
| 10 | **Streak System** | System settings (freeze price, freeze max, milestone interval) | Daily streak, freeze mechanic (coins), milestone bonuses | Streak stats per student | **High** | Done: `docs/specs/10-streak-system.md` |
| 11 | **Badge/Achievement** | Badge editor (condition types, thresholds, XP rewards, categories) | Auto-award, badge collection display | Badge list per student | Medium | - |
| 12 | **Leaderboard/Leagues** | - | Weekly/total ranking, league tiers, promotion/demotion | Leaderboard report | Medium | Done: `docs/specs/12-leaderboard-leagues.md` |
| 13 | **Coin Economy** | - (coins earned through system rules) | Earn from quests/bonuses, spend on cards/avatar/freeze | - | **High** | Done: `docs/specs/13-coin-economy.md` |
| 14 | **Daily Quest** | Quest management (title, goal, reward, active toggle) | Daily tasks, progress tracking, reward claiming | - | Medium | Done: `docs/specs/14-daily-quest.md` |
| 15 | **Card Collection** | Card editor (image, rarity, category, stats) | Buy packs (coins), collect 96 cards, 8 myth categories, pity mechanic | - | Medium | Done: `docs/specs/15-card-collection.md` |
| 16 | **Avatar System** | Avatar management (bases, categories, items with image upload) | Customize avatar, buy items (coins), z-index layering | - | Low | Done: `docs/specs/16-avatar-system.md` |

## Teacher & Assignment

| # | System | Admin Surface | App Surface | Teacher Surface | Spec Priority | Spec Status |
|---|--------|---------------|-------------|-----------------|---------------|-------------|
| 17 | **Assignment System** | Teacher assignments (read-only view) | Student: receive, complete, track progress/score | Teacher: create (book/vocab/unit), monitor submissions, grades | **High** | Done: `docs/specs/17-assignment-system.md` |
| 18 | **Class Management** | School + class management, student roster | Student: class membership | Teacher: create/manage classes, bulk student operations | Low | Done: `docs/specs/18-class-management.md` |
| 19 | **Teacher Dashboard & Reports** | Recent activity analytics | - | Dashboard stats, 4 report types (reading, assignment, class, leaderboard) | Low | - |
| 20 | **Student Management** | User management (CRUD, tabbed detail view) | - | Student detail, password reset, class transfer | Low | - |

## Infrastructure

| # | System | Admin Surface | App Surface | Teacher Surface | Spec Priority | Spec Status |
|---|--------|---------------|-------------|-----------------|---------------|-------------|
| 21 | **Auth** | Admin login (admin/head-teacher role check) | Student/teacher email login, role routing | - | None | - |
| 22 | **User Profile** | User detail view | Profile screen, avatar display | - | None | - |
| 23 | **System Settings** | Multi-category settings editor (xp_reading, xp_vocab, progression, game, app) | Runtime config consumption | - | Low | - |
| 24 | **Notification System** | Notification gallery (preview, toggle, settings per type) | In-app notifications (planned) | - | Low | - |
| 25 | **Content Blocks** | Content block editor in chapter editor | Flexible rendering in reader (text, image, audio) | - | Low | - |
| 26 | **Book Access Control** | - | Assignment-based access gating | - | Low | - |

---

## Spec Priority Guide

- **High**: Complex business logic, cross-system interactions, state machines, algorithms — Claude can't infer from code alone
- **Medium**: Non-trivial but patterns are partially visible in code
- **Low**: Standard CRUD or straightforward UI — code is self-documenting
- **None**: Too simple to warrant a spec

## Suggested Review Order

All features will be reviewed. Start with high-complexity systems where implicit rules are densest:

1. **Vocabulary & Spaced Repetition** (#5) — Done
2. **Audio/Karaoke Reader** (#2) — Partial (patterns doc exists, full spec needed)
3. **XP/Leveling + Coin Economy** (#9, #13) — Cross-system reward rules
4. **Assignment System** (#17) — Dual-side, status lifecycle
5. **Streak System** (#10) — State transitions, freeze mechanic
6. **Learning Paths** (#7) — Hierarchical, scope-based assignment
7. **Book System** (#1) → **Inline Activities** (#3) → **Book Quiz** (#4) — Reading flow
8. **Badge/Achievement** (#11) → **Leaderboard** (#12) → **Daily Quest** (#14) — Gamification
9. **Card Collection** (#15) → **Avatar** (#16) — Collection systems
10. **Word Lists** (#6) → **Daily Review** (#8) — Vocabulary extensions
11. **Assignment** (#17) → **Class Management** (#18) → **Dashboard/Reports** (#19, #20) — Teacher systems
12. **Auth** (#21) → **Profile** (#22) → **Settings** (#23) → **Notifications** (#24) → **Content Blocks** (#25) → **Access Control** (#26) — Infrastructure

## Key Cross-System Flows

These flows touch multiple systems and are where "confident divergence" is most likely. Each flow is traced from actual code.

### Flow 1: Complete Chapter
```
Student finishes chapter
  → book_provider.dart: ChapterCompletionNotifier.markComplete()
    → reading_progress UPDATE (add chapter to completed_chapter_ids, recalc %)
    → daily_chapter_reads INSERT (tracking)
    → IF chapter was not already completed:
      → addXP(settings.xpChapterComplete = 50 XP)
        → badge check (via addXP → CheckAndAwardBadgesUseCase)
      → IF all chapters done AND no quiz:
        → addXP(settings.xpBookComplete = 200 XP)
    → _updateAssignmentProgress()
      → find matching book assignments
      → recalc progress (completedChapters / totalChapters)
      → IF progress >= 100%: CompleteAssignmentUseCase
    → invalidate: readingProgressProvider, continueReadingProvider, dailyQuestProgressProvider
```
**Streak**: NOT updated here (only on app open)
**Tables**: reading_progress, daily_chapter_reads, student_assignments, scope_unit_items

### Flow 2: Vocabulary Session Complete
```
Student finishes vocab session → session_summary_screen.dart
  → CompleteSessionUseCase (RPC: complete_vocabulary_session)
    → vocabulary_progress UPDATE per word (SM-2: ease_factor, interval_days, repetitions, next_review_at)
    → vocabulary_session_results INSERT (accuracy, duration, combo, XP)
    → user_word_list_progress UPDATE (list-level stats)
  → XP = session.xpEarned + (maxCombo * settings.comboBonusXp[default 5])
  → refreshProfileOnly() (re-fetch user XP, level, coins)
  → IF matching vocabulary assignment exists:
    → CompleteAssignmentUseCase (score = accuracy %)
  → invalidate: progressForListProvider, userWordListProgressProvider, leaderboardEntriesProvider, dailyQuestProgressProvider
```
**Badge check**: Via server-side XP award in RPC
**Streak**: NOT updated here (only on app open)
**Tables**: vocabulary_progress, vocabulary_session_results, user_word_list_progress, profiles, student_assignments

### Flow 3: Buy Card Pack
```
Student buys pack → BuyPackUseCase
  → RPC: RpcFunctions.buyCardPack(p_user_id, p_pack_cost = 100 coins)
    → Server checks profiles.coins >= cost
      → IF insufficient: InsufficientFundsFailure
      → IF sufficient: profiles.coins -= cost
    → unopened_packs INSERT (rarity roll with pity mechanic — server-side only)
    → pack_cards INSERT (3 cards assigned)
  → Response: BuyPackResult (success, new coin balance, pack data)
  → Open pack flow (separate): reveals cards with animation
```
**No XP, no badge, no streak** — pure coin transaction
**Pity mechanic**: Server-side, not visible in client code — audit during Card Collection review (#15)
**Tables**: profiles (coin deduction), unopened_packs, pack_cards

### Flow 4: Daily Quest Progress & Reward
```
Quest progress tracked IMPLICITLY (no explicit "complete quest" event):
  → Server RPC checks activity logs:
    → "Read chapters today" → daily_chapter_reads count
    → "Correct answers today" → inline_activity_results + vocab_session_results
    → "Words read today" → reading_progress words count
  → Progress shown via GetDailyQuestProgressUseCase

Reward claiming (separate action):
  → ClaimDailyBonusUseCase → RPC: RpcFunctions.claimDailyBonus
    → IF already claimed today: Error
    → IF eligible: unopened_packs INSERT (free pack reward)
```
**XP/coins**: Not directly from quest — earned through the activities that complete the quest
**Tables**: daily_quest_progress (read), unopened_packs (insert on claim)

### Flow 5: Assignment Creation → Student
```
Teacher creates assignment → CreateAssignmentUseCase
  → Validation: type-specific (book needs bookId, vocab needs wordListId, unit needs scopeLpUnitId)
  → RPC: RpcFunctions.createAssignmentWithStudents
    → assignments INSERT (teacher_id, class_id, type, content_config, dates)
    → student_assignments INSERT per student (status: in_progress)
  → Student notification: server-side trigger (not in client code)

Student progress auto-tracking:
  → Book type: chapter completion triggers _updateAssignmentProgress() in book_provider
  → Vocab type: session completion checks for matching wordListId in session_summary_screen
  → Unit type: syncUnitAssignmentProgress RPC on creation + calculateUnitProgressUseCase

Grade calculation:
  → Book: progress % (completedChapters / totalChapters)
  → Vocabulary: accuracy % from session
  → Unit: composite from child items
```
**Tables**: assignments, student_assignments, scope_unit_items

### Flow 6: Inline Activity Completion
```
Student answers in-chapter activity → reader_provider.dart: completeInlineActivity()
  → Check if already completed (prevents double XP)
  → saveInlineActivityResult() → inline_activity_results INSERT (unique constraint)
    → IF duplicate: returns false (no XP)
    → IF new: returns true
  → addXP(settings.xpInlineActivity = 25 XP)
    → badge check (via addXP)
  → invalidate: dailyQuestProgressProvider
```
**Tables**: inline_activity_results, profiles (XP)

### Flow 7: Book Quiz Completion
```
Student submits quiz → SubmitQuizResultUseCase
  → RPC: grades quiz, calculates score
  → book_quiz_results INSERT
  → IF passing (>= 70%):
    → reading_progress UPDATE (quizPassed = true)
    → IF all chapters complete: reading_progress.is_completed = true
    → XP award: settings.xpQuizPass (default 20 XP)
    → badge check (via addXP)
```
**Tables**: book_quiz_results, reading_progress, profiles

### Flow 8: Streak Freeze Purchase
```
Student buys freeze → BuyStreakFreezeUseCase
  → Cost: settings.streakFreezePrice (default 50 coins)
  → Max: settings.streakFreezeMax
  → Server: profiles.coins -= cost, freeze count++
  → Response: BuyFreezeResult (remaining freezes, coins)
  → Error: InsufficientFundsFailure if can't afford
```
**Tables**: profiles (coins, freeze count)

### Flow 9: Avatar Item Purchase
```
Student buys avatar item → BuyAvatarItemUseCase
  → RPC: RpcFunctions.buyAvatarItem
  → Server: profiles.coins -= item.coinPrice
  → user_avatar_items INSERT
  → Error: InsufficientFundsFailure if can't afford
```
**Tables**: profiles (coins), user_avatar_items

### Flow Summary Table

| Flow | Trigger | XP | Badge | Streak | Assignment | Coins |
|------|---------|-----|-------|--------|------------|-------|
| Chapter Complete | book_provider | +50 (+200 if book done) | via addXP | app open only | auto-update | - |
| Vocab Session | session_summary | base + combo | server-side | app open only | if match | - |
| Buy Card Pack | card shop | - | - | - | - | -100 |
| Daily Quest | implicit | via activities | via activities | app open only | - | - |
| Assignment Create | teacher | - | - | - | creates | - |
| Inline Activity | reader | +25 | via addXP | app open only | implicit | - |
| Book Quiz | quiz screen | +20 | via addXP | app open only | implicit | - |
| Streak Freeze | user action | - | - | +1 freeze | - | -50 |
| Avatar Purchase | avatar screen | - | - | - | - | -price |

### Architectural Notes
- **All XP goes through** `userControllerProvider.addXP()` → auto badge check
- **Streak NEVER updates per-activity** — only on app open via `_updateStreakIfNeeded()`
- **Assignment progress is distributed** — each activity type checks for matching assignments independently
- **Daily quest progress is implicit** — no "complete quest" event, server counts activity logs
- **Pity mechanic is server-only** — client has no visibility into legendary guarantee logic

## Supabase Tables (54 in DbTables + 2 orphan candidates)

**Users & Auth (3):** profiles, schools, classes
**Content (5):** books, chapters, content_blocks, inline_activities, inline_activity_results
**Reading (4):** reading_progress, daily_chapter_reads, activities, activity_results
**Quiz (3):** book_quizzes, book_quiz_questions, book_quiz_results
**Vocabulary (9):** vocabulary_words, vocabulary_progress, vocabulary_units, vocabulary_sessions, vocabulary_session_words, chapter_vocabulary, word_lists, word_list_items, user_word_list_progress
**Vocabulary Extensions (2):** user_node_completions, daily_review_sessions
**Gamification (14):** badges, user_badges, xp_logs, coin_logs, league_history, myth_cards, user_cards, user_card_stats, pack_purchases, daily_quest_pack_claims, daily_quests, daily_quest_completions, daily_quest_bonus_claims, daily_logins
**Learning Paths (7):** learning_path_templates, learning_path_template_units, learning_path_template_items, scope_learning_paths, scope_learning_path_units, scope_unit_items, path_daily_review_completions
**Assignments (2):** assignments, assignment_students
**Avatar (4):** avatar_bases, avatar_item_categories, avatar_items, user_avatar_items
**System (1):** system_settings

**Possibly orphaned (in migrations but NOT in DbTables):**
- unit_book_assignments, unit_curriculum_assignments — audit during Learning Paths review (#7)
