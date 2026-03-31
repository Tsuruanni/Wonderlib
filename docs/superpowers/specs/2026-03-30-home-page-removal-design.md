# Home Page Removal — Spec

## Overview

Remove the home page entirely. Redistribute its functional sections to more appropriate locations: Continue Reading → Library, Daily Review → Learning Path, Daily Quests + Badges → new dedicated Quests page. Update navigation to replace the Home tab with a Quests tab and make Learning Path the default.

## Motivation

The home page acts as a hub that duplicates navigation available through tabs. Moving each section to where it contextually belongs reduces indirection and puts content closer to related features.

---

## 1. Continue Reading → Library

### Current State
- Home page renders a horizontal `ListView` of up to 5 in-progress books via `continueReadingProvider`.
- Each `_BookCard` shows: cover image, quiz-ready badge, reading progress bar, title, level.

### Target State
- Library screen gains a "Continue Reading" section between the category/search bar and the first level shelf.
- Rendered as a `SliverToBoxAdapter` inside the existing `CustomScrollView`.
- Horizontal `ListView` of book cards — same style as home's `_BookCard` (cover + progress bar + quiz badge).
- If no in-progress books → section hidden entirely (`SizedBox.shrink()`).
- Section header: "Continue Reading" with a book count badge.

### Data Flow
- Reuses `continueReadingProvider` (no changes to domain/data layers).
- Reuses `isQuizReadyProvider` and `readingProgressProvider` per book.

---

## 2. Recommended for You → Remove

### Current State
- Home page renders a horizontal `ListView` via `recommendedBooksProvider`.

### Target State
- Section removed entirely.
- `recommendedBooksProvider`, `GetRecommendedBooksUseCase`, and related repository method deleted (not used elsewhere).

---

## 3. Daily Review Section → Learning Path

### Current State
- Home page inline `_DailyReviewSection` with 3 states:
  - Completed today → green "+X XP earned" card.
  - Due words available → orange "Review X words" card with play button → `/vocabulary/daily-review`.
  - No due words → hidden.

### Target State
- Moved to `VocabularyHubScreen`, rendered after TopNavbar and before path content.
- In the single-path scenario (where `UnitMapScreen` renders directly), the daily review card appears as a compact banner above the map.
- Same 3-state logic, same providers (`todayReviewSessionProvider`, `dailyReviewWordsProvider`).

---

## 4. Quests Page (New)

### Layout (Scrollable, Top to Bottom)

```
Quests Screen
├── TopNavbar
├── Monthly Quest Hero Card [PLACEHOLDER]
│   ├── Month label chip ("MARCH")
│   ├── Title ("March Quest")
│   ├── Countdown timer ("1 DAY")
│   └── Progress card ("Complete 20 quests" — 0/20 bar + avatar)
├── Daily Quests Section
│   ├── Header ("Daily Quests") + countdown timer (hours until reset)
│   ├── Assignment rows (from activeAssignmentsProvider)
│   ├── Quest rows (from dailyQuestProgressProvider)
│   └── Bonus claim row
├── Badges Section
│   ├── Header ("Badges") + count badge
│   ├── Earned badges — full color grid (emoji, name, date)
│   └── Unearned badges — grey/locked grid (emoji, name, description)
└── Monthly Badges Card [PLACEHOLDER]
    ├── "Earn your first badge!"
    └── Description + illustration
```

### Responsive Behavior
- **Mobile (< 600px):** Single column, all sections stacked vertically. Monthly Badges at the bottom.
- **Wide (≥ 600px):** Monthly Badges moves to a right sidebar (Duolingo-style reference layout).

### Visual Reference
- Monthly Quest hero card: Large orange/primary-colored card with rounded corners, month chip, countdown, inner progress card.
- Daily Quests: Card with divider-separated rows, each row has icon, title, progress bar, reward icon. Countdown timer in header right.
- Badges grid: Wrap-based grid of badge tiles. Earned = colored + emoji + name + date. Unearned = grey overlay + lock + name + description.

### Data Sources
- Daily Quests: `dailyQuestProgressProvider`, `dailyBonusClaimedProvider`, `activeAssignmentsProvider` (all existing).
- `QuestCompletionDialog` popup triggers on this screen via `ref.listen`.
- Badges earned: `userBadgesProvider` (existing).
- All badges (for unearned): Requires new domain/data work:
  - `BadgeRepository.getAllBadges()` → queries `DbTables.badges` where `is_active = true`.
  - `GetAllBadgesUseCase` wrapping the repository call.
  - `allBadgesProvider` — fetches all active badges.
  - UI diffs `allBadges` against `userBadges` to determine unearned set.
- Monthly Quest / Monthly Badges: Hardcoded/static placeholder data (no backend).

### Route
- Path: `/quests`
- No sub-routes for now.

---

## 5. Home Tab Removal & Navigation Update

### Current Tab Order
```
0: Learning Path (/vocabulary)
1: Home (/)
2: Library (/library)
3: Cards (/cards)
4: Leaderboard (/leaderboard)
```

### New Tab Order
```
0: Learning Path (/vocabulary)  ← default (initialLocation)
1: Library (/library)
2: Quests (/quests)
3: Cards (/cards)
4: Leaderboard (/leaderboard)
```

### Changes
- Router: Remove home branch, add quests branch with `QuestsScreen` at `/quests`.
- `initialLocation` updated to `/vocabulary`.
- `MainShellScaffold`: Update tab list — icons, labels, index mapping.
- Quests tab icon: `emoji_events` or `military_tech` (achievement-style).
- `AppRoutes.home` removed, `AppRoutes.quests = '/quests'` added.

### Profile Page
- `_RecentBadgesSection` remains on the profile screen.
- "See All" button navigates to `/quests` instead of opening a bottom sheet.

---

## 6. Cleanup

### Files to Delete
- `lib/presentation/screens/home/home_screen.dart`
- `lib/presentation/widgets/home/daily_quest_widget.dart` (moved to quests)
- `lib/presentation/widgets/home/daily_quest_list.dart` (moved to quests)
- Any home-only providers or helper widgets not used elsewhere.

### Files to Delete (Recommended Books)
- `lib/domain/usecases/book/get_recommended_books_usecase.dart`
- Related repository method in `BookRepository` interface and implementations.
- `recommendedBooksProvider` from `book_provider.dart`.

### Providers to Keep
- `continueReadingProvider` — used by library now.
- `dailyQuestProgressProvider`, `dailyBonusClaimedProvider` — used by quests page.
- `todayReviewSessionProvider`, `dailyReviewWordsProvider` — used by learning path.

---

## Out of Scope
- Monthly Quest backend/logic (placeholder only).
- Monthly Badges backend/logic (placeholder only).
- Teacher shell changes (teacher dashboard unaffected).
