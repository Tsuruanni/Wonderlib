# Badge/Achievement System

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Security | `check_and_award_badges` RPC has no `auth.uid()` check — any authenticated user can trigger badge awards for any other user | Critical | Fixed |
| 2 | Architecture | `checkEarnableBadges()` in repository contains business logic (condition evaluation, stat queries) — should be in UseCase or server RPC | Medium | Fixed (removed — dead code) |
| 3 | Architecture | `awardBadge()` in repository orchestrates XP side-effect (`_awardXP`) — XP orchestration belongs in UseCase layer | Medium | Tech debt |
| 4 | Architecture | Admin screens (`badge_edit_screen.dart`, `badge_list_screen.dart`) access Supabase directly, bypassing repository/UseCase layers | Low | Accepted (admin pattern) |
| 5 | Dead Code | `allBadgesProvider` defined but never consumed by any screen or widget | Low | Fixed (removed) |
| 6 | Dead Code | `earnableBadgesProvider` + `CheckEarnableBadgesUseCase` + repo method — entire dead path | Low | Fixed (removed) |
| 7 | Dead Code | `GetBadgeByIdUseCase` + `getBadgeByIdUseCaseProvider` + `GetAllBadgesUseCase` + repo methods | Low | Fixed (removed) |
| 8 | Performance | `checkEarnableBadges()` made 6 sequential DB queries (N+1 pattern) | Medium | Fixed (removed — dead code) |
| 9 | Code Quality | All badge FutureProviders lack `.autoDispose` — cached in memory after navigation | Low | Tech debt |
| 10 | Edge Case | Badge FutureProviders silently return `[]` on failure — user cannot distinguish "no badges" from "network error" | Medium | Tech debt |
| 11 | Edge Case | UI `.when(error:)` renders `SizedBox.shrink()` — error state invisible to user | Medium | Tech debt |
| 12 | Code Quality | `BadgeController` invalidates `recentBadgesProvider` but not `earnableBadgesProvider` after award | Low | N/A (earnableBadgesProvider removed) |

### Checklist Result

- Architecture Compliance: 3 issues (#2, #3, #4)
- Code Quality: 2 issues (#9, #12)
- Dead Code: 3 issues (#5, #6, #7)
- Database & Security: 1 issue (#1 — Critical)
- Edge Cases & UX: 2 issues (#10, #11)
- Performance: 1 issue (#8)
- Cross-System Integrity: PASS

---

## Overview

The Badge/Achievement system automatically awards badges to students when they reach milestones across reading, vocabulary, streaks, XP, levels, and activity scores. Admin creates badges with condition types and thresholds via a badge editor. Students see earned badges on their profile and receive animated notifications. Teachers can view a student's badge collection on the student detail screen.

## Data Model

### Tables

**badges**
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | VARCHAR(100) | Display name |
| slug | VARCHAR(100) UNIQUE | URL-friendly identifier |
| description | TEXT | Optional help text |
| icon | VARCHAR(50) | Emoji representation |
| category | VARCHAR(50) | Grouping: achievement, streak, reading, vocabulary, activities, xp, level, special |
| condition_type | VARCHAR(50) | CHECK constraint: xp_total, streak_days, books_completed, vocabulary_learned, perfect_scores, level_completed |
| condition_value | INTEGER | Threshold to meet |
| xp_reward | INTEGER DEFAULT 0 | XP awarded when badge is earned |
| is_active | BOOLEAN DEFAULT TRUE | Soft-delete / disable |
| created_at | TIMESTAMPTZ | |

**user_badges**
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK → profiles | ON DELETE CASCADE |
| badge_id | UUID FK → badges | ON DELETE CASCADE |
| earned_at | TIMESTAMPTZ | |
| | UNIQUE(user_id, badge_id) | Prevents duplicate awards |

### Key Relationships
- `user_badges.user_id → profiles.id` (CASCADE)
- `user_badges.badge_id → badges.id` (CASCADE)
- XP rewards logged in `xp_logs` with source = 'badge'

### RLS Policies

**badges:**
- SELECT: Anyone can read active badges (`is_active = true`)
- ALL: Admins can manage badges (`is_admin()`)

**user_badges:**
- SELECT: Users can view own badges (`user_id = auth.uid()`)
- SELECT: Users can view schoolmate badges (same `school_id`)
- INSERT: Users can only insert own badges (`user_id = auth.uid()`)

### Indexes
- `idx_user_badges_user` on `user_badges(user_id)`
- `idx_xp_logs_user` on `xp_logs(user_id)` (for badge XP tracking)
- `idx_xp_logs_created` on `xp_logs(created_at DESC)`

## Surfaces

### Admin

**Badge Editor** (`owlio_admin/lib/features/badges/screens/badge_edit_screen.dart`)
- Create/edit/delete badges
- Fields: icon (emoji), name, slug (auto-generated), description, category (dropdown), condition_type (dropdown), condition_value, xp_reward
- Live preview panel shows badge card appearance
- "Earned By" section shows students who earned the badge (with count and dates)
- Categories: achievement, streak, reading, vocabulary, activities, xp, level, special
- Admin UI is in Turkish (per project convention)

**Badge List** (`owlio_admin/lib/features/badges/screens/badge_list_screen.dart`)
- Lists all badges with condition labels
- Navigation to edit screen

### Student

**Auto-Award Flow:**
1. Student performs an action that awards XP (chapter, quiz, vocab, inline activity) or updates streak
2. `addXP()` / `updateStreak()` in `UserController` calls `CheckAndAwardBadgesUseCase`
3. Server RPC `check_and_award_badges` evaluates all active badges against user stats
4. Newly earned badges inserted atomically (ON CONFLICT DO NOTHING)
5. Badge XP rewards awarded via `award_xp_transaction` inside the same RPC
6. Client receives `List<BadgeEarned>` with badge_id, badge_name, badge_icon, xp_reward

**Badge Earned Notification:**
1. `badgeEarnedEventProvider` receives `BadgeEarnedEvent`
2. `level_up_celebration.dart` listener enqueues dialog in event queue (after level-up/streak dialogs)
3. `BadgeEarnedDialog` shows animated popup (scale + fade) with badge icon, name, and XP reward
4. Notification gated by `SystemSettings.notifBadgeEarned`

**Badge Collection:**
- Profile screen shows recent badges via `_RecentBadgesSection`
- Empty state: "Complete lessons to earn badges!" with icon
- Badges sorted by `earned_at DESC`

### Teacher

**Student Detail Screen** (`student_detail_screen.dart`)
- "Badges" section shows earned badges for selected student
- Uses `teacherStudentBadgesProvider` (FutureProvider.family by studentId)
- Each badge shows icon, name, description, earned date
- RLS allows teacher to see badges of students in the same school

## Business Rules

1. **Badge uniqueness**: A user can only earn each badge once (UNIQUE constraint on `user_id, badge_id`).
2. **Auto-award timing**: Badges are checked after every XP award (`addXP`) and after daily streak update (`updateStreak`). No manual claiming required.
3. **Server-side authority**: The `check_and_award_badges` RPC is the authoritative evaluator. Client-side `checkEarnableBadges()` exists for UI preview only.
4. **XP reward flow**: When a badge with `xp_reward > 0` is earned, the RPC calls `award_xp_transaction` internally. This XP award does NOT re-trigger badge checks (preventing infinite loops — the UNIQUE constraint would block re-insert anyway).
5. **Soft-disable**: Setting `is_active = false` prevents the badge from being awarded or shown in the active badge list. Already-earned instances remain in `user_badges`.
6. **Cascading deletes**: Deleting a badge removes all `user_badges` instances. Deleting a user removes all their badges.
7. **Notification gating**: Badge earned dialog only shows when `system_settings.notif_badge_earned = true`.
8. **Dialog queue priority**: Badge earned dialog appears after level-up and streak dialogs in the event queue.

### Condition Types

| Type | DB Value | Evaluated Against |
|------|----------|-------------------|
| Total XP | `xp_total` | `profiles.xp` |
| Streak Days | `streak_days` | `profiles.current_streak` |
| Books Completed | `books_completed` | COUNT of `reading_progress` WHERE `is_completed = TRUE` |
| Vocabulary Learned | `vocabulary_learned` | COUNT of `vocabulary_progress` WHERE `status = 'mastered'` |
| Perfect Scores | `perfect_scores` | COUNT of `activity_results` WHERE `score = max_score` |
| Level Reached | `level_completed` | `profiles.level` |

### Seeded Badges (17 total)

| Category | Badge | Threshold | XP Reward |
|----------|-------|-----------|-----------|
| Reading | First Steps | 1 book | 50 |
| Reading | Bookworm | 5 books | 200 |
| Reading | Library Master | 20 books | 500 |
| Streak | Streak Starter | 3 days | 30 |
| Streak | Streak Master | 7 days | 100 |
| Streak | Streak Warrior | 14 days | 150 |
| Streak | Streak Legend | 30 days | 500 |
| Streak | Streak Hero | 60 days | 750 |
| Streak | Streak Immortal | 100 days | 1500 |
| Vocabulary | Word Explorer | 10 mastered | 50 |
| Vocabulary | Vocabulary Champion | 50 mastered | 150 |
| Vocabulary | Word Master | 200 mastered | 500 |
| Activities | Perfect Score | 1 perfect | 75 |
| Activities | Perfectionist | 10 perfects | 200 |
| XP | Rising Star | 500 XP | 50 |
| XP | Scholar | 2000 XP | 100 |
| XP | Expert | 5000 XP | 200 |
| XP | Legend | 10000 XP | 500 |
| Level | Level 5 | Level 5 | 100 |
| Level | Level 10 | Level 10 | 250 |

## Cross-System Interactions

### Trigger Chains

```
XP-earning activity (chapter/quiz/vocab/inline)
  → addXP() in UserController
    → award_xp_transaction RPC (profiles.xp += amount, profiles.coins += amount)
    → check_and_award_badges RPC
      → IF new badge earned:
        → user_badges INSERT
        → IF xp_reward > 0: award_xp_transaction (badge XP + coins)
        → RETURN badge_id, badge_name, badge_icon, xp_reward
      → Client: badgeEarnedEventProvider → BadgeEarnedDialog
      → Client: invalidate userBadgesProvider, refreshProfileOnly()
```

```
App open (daily)
  → updateStreak() in UserController
    → streak RPC (calculates current_streak)
    → check_and_award_badges RPC (streak-based badges)
      → Same flow as above
```

```
Vocabulary session complete (server-side)
  → complete_vocabulary_session RPC
    → award_xp_transaction (session XP)
    → PERFORM check_and_award_badges(p_user_id) (inside RPC)
```

### System Dependencies

| System | Interaction |
|--------|-------------|
| XP/Leveling | Badge awards XP via `award_xp_transaction`; XP thresholds are a condition type |
| Streak | Streak days is a condition type; badge check runs after streak update |
| Coins | XP=coins 1:1 rule means badge XP also awards coins |
| Reading Progress | books_completed condition checks `reading_progress.is_completed` |
| Vocabulary | vocabulary_learned condition checks `vocabulary_progress.status = 'mastered'` |
| Activities | perfect_scores condition checks `activity_results.score = max_score` |
| Notifications | Badge dialog gated by `notif_badge_earned` system setting |

## Edge Cases

1. **Multiple badges earned at once**: When a single action unlocks multiple badges, all are returned by the RPC and displayed in a multi-badge dialog layout.
2. **XP from badge triggers another badge**: The `award_xp_transaction` inside the badge RPC could theoretically push the user past an XP badge threshold — but since badge check runs once per `addXP` call, the XP badge would be caught on the *next* action's badge check. This is acceptable because badge checks happen frequently.
3. **Deleted badge with existing earners**: CASCADE delete removes all `user_badges` rows. Admin sees a deletion warning dialog.
4. **Badge deactivation**: Setting `is_active = false` prevents future awards but does NOT remove existing earners.
5. **Concurrent badge checks**: Two simultaneous `addXP` calls could both trigger `check_and_award_badges`. The `ON CONFLICT DO NOTHING` clause ensures no duplicate inserts. XP reward is only awarded for the INSERT that succeeds.
6. **User with 0 badges**: Profile shows "Complete lessons to earn badges!" empty state message.
7. **Network error during badge check**: Badge check failure is silently ignored — the main action (XP award) still succeeds. Badge will be caught on next check.

## Test Scenarios

- [ ] Happy path: Student earns XP → badge awarded → dialog shows → profile reflects badge
- [ ] Multiple badges: Action triggers 2+ badges simultaneously → dialog shows all
- [ ] Empty state: Fresh user with 0 badges → profile shows encouraging message
- [ ] Error state: Network failure during badge check → main action still succeeds, no crash
- [ ] Idempotency: Same badge check called twice → no duplicate awards
- [ ] Deactivation: Admin disables badge → not awarded to new users, existing earners keep it
- [ ] Deletion: Admin deletes badge → all user_badges cascade-deleted
- [ ] XP reward: Badge with xp_reward=100 → user profile shows +100 XP and +100 coins
- [ ] Streak badge: Student reaches 7-day streak → Streak Master badge awarded on app open
- [ ] Teacher view: Teacher opens student detail → sees correct badge list
- [ ] Admin create: Create new badge → appears in badge list → can be earned by students
- [ ] Notification toggle: `notif_badge_earned = false` → badge still awarded but no dialog
- [ ] Cross-system: Book completion awards XP → XP triggers XP badge → badge awards more XP → all logged correctly

## Key Files

### Domain
- `lib/domain/entities/badge.dart` — Badge, UserBadge entities
- `lib/domain/entities/badge_earned.dart` — BadgeEarned (RPC response DTO)
- `lib/domain/repositories/badge_repository.dart` — Abstract interface (7 methods)
- `lib/domain/usecases/badge/check_and_award_badges_usecase.dart` — Primary use case

### Data
- `lib/data/repositories/supabase/supabase_badge_repository.dart` — Supabase implementation
- `lib/data/models/badge/badge_model.dart` — JSON serialization

### Presentation
- `lib/presentation/providers/badge_provider.dart` — FutureProviders + BadgeController
- `lib/presentation/providers/user_provider.dart` — addXP() and updateStreak() trigger badge checks
- `lib/presentation/widgets/common/badge_earned_dialog.dart` — Earned badge notification dialog
- `lib/presentation/widgets/common/level_up_celebration.dart` — Event queue listener

### Admin
- `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart` — Badge CRUD
- `owlio_admin/lib/features/badges/screens/badge_list_screen.dart` — Badge list

### Database
- `supabase/migrations/20260131000006_create_gamification_tables.sql` — Table schemas
- `supabase/migrations/20260325000004_badge_earned_notification.sql` — Latest `check_and_award_badges` RPC

### Shared
- `packages/owlio_shared/lib/src/enums/badge_condition_type.dart` — Condition type enum
- `packages/owlio_shared/lib/src/constants/tables.dart` — `DbTables.badges`, `DbTables.userBadges`
- `packages/owlio_shared/lib/src/constants/rpc_functions.dart` — `RpcFunctions.checkAndAwardBadges`

## Known Issues & Tech Debt

1. ~~**CRITICAL — Missing auth check**~~: Fixed in `20260328000008_add_auth_check_to_badge_rpc.sql`.
2. ~~**Dead code**~~: Removed `allBadgesProvider`, `earnableBadgesProvider`, `checkEarnableBadges()`, `GetAllBadgesUseCase`, `GetBadgeByIdUseCase`, and related repo methods/providers.
3. **XP side-effect in repository**: `awardBadge()` orchestrates XP award inside the repository. Should be in UseCase layer. Low risk — manual badge award flow is rarely used.
4. **Silent error handling**: Badge providers return `[]` on failure with no logging or user feedback. Consider adding error state to UI.
5. **No autoDispose**: Badge FutureProviders stay cached after navigation. Low impact since badge data is small, but inconsistent with best practices.
