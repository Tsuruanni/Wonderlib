# All Badges Screen (Duolingo-style Grouped Achievements) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dedicated Duolingo-style All Badges screen that groups the flat 43+ badges by achievement track (Streak, XP, Books, Cards, 8 myth categories, League, etc.), shows current level per group (highest earned tier) and progress toward the next tier, with a progress bar. Fix the broken "See All" button on profile so it navigates here.

**Architecture:** Pure frontend grouping — no DB/RPC changes. A new `badgeProgressProvider` consumes existing providers (`allBadgesProvider`, `userBadgesProvider`, `userControllerProvider`, `userCardsProvider`, `completedBookIdsProvider`, `vocabularyStatsProvider`, `categoryProgressProvider`, plus a new perfect-scores provider) and produces a `List<AchievementGroup>` where each group carries current level, next target badge, and progress value. UI renders each group as a row following Duolingo's layout (icon tile with LEVEL badge + title + progress bar + description).

**Tech Stack:** Flutter + Riverpod + go_router. No new packages.

**Spec base:** `docs/specs/11-badge-achievement.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `lib/domain/entities/achievement_group.dart` | `AchievementGroup` entity — one per badge track (group_key, title, description, icon, badges[], earnedBadges[], currentLevel, nextBadge?, currentValue, targetValue, isMaxed) |
| `lib/presentation/providers/badge_progress_provider.dart` | Pure-compute `achievementGroupsProvider` that builds `List<AchievementGroup>` from existing providers |
| `lib/presentation/providers/perfect_scores_provider.dart` | New `perfectScoresCountProvider` — `FutureProvider<int>` counting `activity_results WHERE user_id=X AND score=max_score` |
| `lib/presentation/screens/badges/all_badges_screen.dart` | The screen widget |
| `lib/presentation/widgets/badges/achievement_group_row.dart` | Per-group row widget (icon tile + title + progress bar + current/target text + description) |

### Modified Files
| File | Change |
|------|--------|
| `lib/app/router.dart` | Add `AppRoutes.allBadges = '/badges'` constant + `GoRoute` inside Vocab/Profile branch |
| `lib/presentation/screens/profile/profile_screen.dart` | Line 907: change `context.go(AppRoutes.quests)` → `context.go(AppRoutes.allBadges)` |

### Untouched (but consumed)
- `lib/presentation/providers/badge_provider.dart` (`userBadgesProvider`, `allBadgesProvider`)
- `lib/presentation/providers/user_provider.dart` (`userControllerProvider`, `displayStreakProvider`)
- `lib/presentation/providers/card_provider.dart` (`userCardsProvider`, `categoryProgressProvider`)
- `lib/presentation/providers/book_provider.dart` (`completedBookIdsProvider`)
- `lib/presentation/providers/vocabulary_provider.dart` (`vocabularyStatsProvider`)

---

## Task 1: `AchievementGroup` Entity

**Files:**
- Create: `lib/domain/entities/achievement_group.dart`

- [ ] **Step 1: Create entity file**

```dart
import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'badge.dart';

/// Represents a Duolingo-style achievement "track" — a grouping of tiered badges
/// that the user progresses through. Example: the Streak track contains 6 badges
/// (3, 7, 14, 30, 60, 100 days); the user is at LEVEL 3 if they've earned 3 of them.
class AchievementGroup extends Equatable {
  const AchievementGroup({
    required this.groupKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.badges,
    required this.earnedBadgeIds,
    required this.currentValue,
    required this.nextBadge,
  });

  /// Stable identifier for the group (e.g. 'streak_days', 'myth_category_completed:turkish_myths').
  final String groupKey;

  /// Display title shown in the row (e.g. "Streak", "Turkish Myths").
  final String title;

  /// Displayed under the progress bar. Usually the description of the NEXT unearned
  /// badge (e.g. "Reach a 14 day streak") or the MAX badge's description when complete.
  final String description;

  /// Emoji shown inside the icon tile.
  final String icon;

  /// All badges in this track, sorted ascending by condition_value (or tier ordinal).
  final List<Badge> badges;

  /// IDs of badges the user has earned within this track.
  final List<String> earnedBadgeIds;

  /// User's current raw stat (xp, streak days, total cards, tier ordinal, etc.).
  final int currentValue;

  /// The next badge to work toward. `null` means the user has maxed this track.
  final Badge? nextBadge;

  /// Current level = number of earned badges in this track.
  int get currentLevel => earnedBadgeIds.length;

  /// Maximum achievable level for this track (total tier count).
  int get maxLevel => badges.length;

  /// True once every tier in the track is earned.
  bool get isMaxed => nextBadge == null;

  /// Target value for the next badge (condition_value or tier ordinal). 0 when maxed.
  int get targetValue => nextBadge?.conditionValue ?? 0;

  /// Progress toward the next badge, clamped to [0.0, 1.0]. 1.0 when maxed.
  double get progress {
    if (isMaxed) return 1.0;
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0).toDouble();
  }

  @override
  List<Object?> get props => [
        groupKey,
        title,
        description,
        icon,
        badges,
        earnedBadgeIds,
        currentValue,
        nextBadge,
      ];
}
```

- [ ] **Step 2: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/entities/achievement_group.dart`

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/achievement_group.dart
git commit -m "feat(domain): add AchievementGroup entity for grouped badge tracks"
```

---

## Task 2: Perfect Scores Provider (minor gap filler)

**Files:**
- Create: `lib/presentation/providers/perfect_scores_provider.dart`

**Context:** Needed because the existing providers don't expose `activity_results WHERE score=max_score` count, which the `perfect_scores` condition type evaluates against.

- [ ] **Step 1: Create provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_provider.dart';

/// Count of activity_results where the user achieved a perfect score.
/// Used to compute progress for `perfect_scores` condition badges.
final perfectScoresCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  try {
    final response = await Supabase.instance.client
        .from(DbTables.activityResults)
        .select('id')
        .eq('user_id', userId)
        .filter('score', 'eq', 'max_score');
    // Note: Supabase SDK can't express `score = max_score` (column-to-column) via the
    // builder. Fallback: fetch rows and compare client-side.
    return (response as List).length;
  } catch (_) {
    return 0;
  }
});
```

**IMPORTANT:** Before writing, verify `DbTables.activityResults` exists by reading `/Users/wonderelt/Desktop/Owlio/packages/owlio_shared/lib/src/constants/tables.dart`. If the constant name differs (e.g. `activity_results` vs `activityResults`), adjust accordingly. If the SDK truly cannot express column-to-column equality, keep the fallback: select `score, max_score` and filter client-side:

```dart
final response = await Supabase.instance.client
    .from(DbTables.activityResults)
    .select('score, max_score')
    .eq('user_id', userId);
final rows = (response as List);
return rows.where((r) {
  final s = (r as Map)['score'];
  final m = r['max_score'];
  return s != null && m != null && s == m;
}).length;
```

Use this fallback form — it's the safe path.

- [ ] **Step 2: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/perfect_scores_provider.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/perfect_scores_provider.dart
git commit -m "feat(badges): add perfect scores count provider"
```

---

## Task 3: `achievementGroupsProvider` — Pure Compute

**Files:**
- Create: `lib/presentation/providers/badge_progress_provider.dart`

- [ ] **Step 1: Create provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../domain/entities/achievement_group.dart';
import '../../domain/entities/badge.dart';
import 'badge_provider.dart';
import 'book_provider.dart';
import 'card_provider.dart';
import 'perfect_scores_provider.dart';
import 'user_provider.dart';
import 'vocabulary_provider.dart';

/// League tier ordinal mapping — matches the RPC's array_position logic.
/// bronze=1, silver=2, gold=3, platinum=4, diamond=5.
int _leagueTierOrdinal(String? tier) {
  switch (tier) {
    case 'bronze':
      return 1;
    case 'silver':
      return 2;
    case 'gold':
      return 3;
    case 'platinum':
      return 4;
    case 'diamond':
      return 5;
    default:
      return 0;
  }
}

/// Human-readable titles/icons per group_key. Kept here for simplicity;
/// could be moved to a helper if reused elsewhere.
class _GroupMeta {
  const _GroupMeta(this.title, this.icon);
  final String title;
  final String icon;
}

const Map<String, _GroupMeta> _groupMetaByConditionType = {
  'xp_total': _GroupMeta('Total XP', '⚡'),
  'streak_days': _GroupMeta('Streak', '🔥'),
  'books_completed': _GroupMeta('Books', '📚'),
  'vocabulary_learned': _GroupMeta('Vocabulary', '📝'),
  'perfect_scores': _GroupMeta('Perfect Scores', '💯'),
  'level_completed': _GroupMeta('Level', '🎖️'),
  'cards_collected': _GroupMeta('Card Collection', '🎴'),
  'league_tier_reached': _GroupMeta('League', '🏆'),
};

const Map<String, _GroupMeta> _groupMetaByMythCategory = {
  'turkish_myths': _GroupMeta('Turkish Myths', '🇹🇷'),
  'ancient_greece': _GroupMeta('Ancient Greece', '🏛️'),
  'viking_ice_lands': _GroupMeta('Viking & Ice Lands', '⚔️'),
  'egyptian_deserts': _GroupMeta('Egyptian Deserts', '🐫'),
  'far_east': _GroupMeta('Far East', '🐉'),
  'medieval_magic': _GroupMeta('Medieval Magic', '🧙'),
  'legendary_weapons': _GroupMeta('Legendary Weapons', '🗡️'),
  'dark_creatures': _GroupMeta('Dark Creatures', '👻'),
};

/// Aggregates every active badge into a Duolingo-style "track". Used by the
/// All Badges screen. Pure compute — no DB calls of its own.
final achievementGroupsProvider = Provider<AsyncValue<List<AchievementGroup>>>((ref) {
  final allBadgesAsync = ref.watch(allBadgesProvider);
  final userBadgesAsync = ref.watch(userBadgesProvider);
  final userAsync = ref.watch(userControllerProvider);
  final userCardsAsync = ref.watch(userCardsProvider);
  final completedBooksAsync = ref.watch(completedBookIdsProvider);
  final vocabStatsAsync = ref.watch(vocabularyStatsProvider);
  final perfectScoresAsync = ref.watch(perfectScoresCountProvider);
  final categoryProgress = ref.watch(categoryProgressProvider);
  final displayStreak = ref.watch(displayStreakProvider);

  // Short-circuit while any upstream is loading or errored.
  if (allBadgesAsync.isLoading ||
      userBadgesAsync.isLoading ||
      userAsync.isLoading ||
      userCardsAsync.isLoading ||
      completedBooksAsync.isLoading ||
      vocabStatsAsync.isLoading ||
      perfectScoresAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (allBadgesAsync.hasError) {
    return AsyncValue.error(allBadgesAsync.error!, allBadgesAsync.stackTrace ?? StackTrace.current);
  }

  final allBadges = allBadgesAsync.value ?? const <Badge>[];
  final earnedIds = (userBadgesAsync.value ?? const [])
      .map((ub) => ub.badgeId)
      .toSet();
  final user = userAsync.value;

  // Resolve user stats to raw integers.
  final xp = user?.xp ?? 0;
  final streak = displayStreak;
  final level = user?.level ?? 0;
  // user.leagueTier is a non-nullable LeagueTier enum (default bronze) — use .dbValue to
  // get the snake_case string ('bronze', 'silver', etc.) that _leagueTierOrdinal expects.
  final tierOrdinal = _leagueTierOrdinal(user?.leagueTier.dbValue);
  final totalCards = (userCardsAsync.value ?? const []).length;
  final booksCompleted = (completedBooksAsync.value ?? const <String>{}).length;
  final vocabMastered = (vocabStatsAsync.value ?? const <String, int>{})['mastered'] ?? 0;
  final perfectScores = perfectScoresAsync.value ?? 0;

  // Group badges by key. Myth categories split on condition_param; everything
  // else groups on condition_type alone.
  final Map<String, List<Badge>> buckets = {};
  for (final b in allBadges) {
    final key = b.conditionType == BadgeConditionType.mythCategoryCompleted
        ? 'myth_category_completed:${b.conditionParam ?? "unknown"}'
        : b.conditionType.dbValue;
    (buckets[key] ??= <Badge>[]).add(b);
  }

  int currentValueFor(Badge example) {
    switch (example.conditionType) {
      case BadgeConditionType.xpTotal:
        return xp;
      case BadgeConditionType.streakDays:
        return streak;
      case BadgeConditionType.booksCompleted:
        return booksCompleted;
      case BadgeConditionType.vocabularyLearned:
        return vocabMastered;
      case BadgeConditionType.perfectScores:
        return perfectScores;
      case BadgeConditionType.levelCompleted:
        return level;
      case BadgeConditionType.cardsCollected:
        return totalCards;
      case BadgeConditionType.mythCategoryCompleted:
        final slug = example.conditionParam;
        if (slug == null) return 0;
        // categoryProgress is Map<CardCategory, int>; convert slug → enum.
        for (final entry in categoryProgress.entries) {
          if (entry.key.dbValue == slug) return entry.value;
        }
        return 0;
      case BadgeConditionType.leagueTierReached:
        return tierOrdinal;
    }
  }

  /// For tier badges, condition_value is placeholder=1; we compare against
  /// the condition_param's ordinal instead.
  int thresholdFor(Badge b) {
    if (b.conditionType == BadgeConditionType.leagueTierReached) {
      return _leagueTierOrdinal(b.conditionParam);
    }
    return b.conditionValue;
  }

  final groups = <AchievementGroup>[];
  for (final entry in buckets.entries) {
    final key = entry.key;
    final badges = List<Badge>.from(entry.value)
      ..sort((a, b) => thresholdFor(a).compareTo(thresholdFor(b)));
    if (badges.isEmpty) continue;
    final example = badges.first;

    // Identify meta (title/icon).
    _GroupMeta? meta;
    if (key.startsWith('myth_category_completed:')) {
      final slug = key.substring('myth_category_completed:'.length);
      meta = _groupMetaByMythCategory[slug];
    } else {
      meta = _groupMetaByConditionType[key];
    }
    meta ??= _GroupMeta(key, '🏅');

    final currentValue = currentValueFor(example);
    final earnedInGroup = badges.where((b) => earnedIds.contains(b.id)).toList();
    final nextBadge = badges.firstWhere(
      (b) => !earnedIds.contains(b.id),
      orElse: () => badges.last, // placeholder; isMaxed handled below
    );
    final isMaxed = earnedInGroup.length == badges.length;
    final effectiveNext = isMaxed ? null : nextBadge;

    final description = effectiveNext?.description
            ?? (earnedInGroup.isNotEmpty ? earnedInGroup.last.description : null)
            ?? '';

    groups.add(AchievementGroup(
      groupKey: key,
      title: meta.title,
      description: description,
      icon: meta.icon,
      badges: badges,
      earnedBadgeIds: earnedInGroup.map((b) => b.id).toList(),
      currentValue: currentValue,
      nextBadge: effectiveNext,
    ));
  }

  // Sort: incomplete groups first (by progress descending), then maxed groups.
  groups.sort((a, b) {
    if (a.isMaxed && !b.isMaxed) return 1;
    if (!a.isMaxed && b.isMaxed) return -1;
    if (a.isMaxed && b.isMaxed) return a.title.compareTo(b.title);
    return b.progress.compareTo(a.progress); // most-progressed first
  });

  return AsyncValue.data(groups);
});
```

- [ ] **Step 2: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/badge_progress_provider.dart`

Expected: No errors. Import issues (wrong path to `CardCategory`) should be fixed by whichever import already exists in the codebase — check `card_provider.dart` to see how `CardCategory` is imported.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/badge_progress_provider.dart
git commit -m "feat(badges): add achievementGroupsProvider for grouped badge tracks"
```

---

## Task 4: `AchievementGroupRow` Widget

**Files:**
- Create: `lib/presentation/widgets/badges/achievement_group_row.dart`

**Design match** (from Duolingo screenshots):
- Left: colored square tile with emoji + `LEVEL N` label
- Right: title + progress bar + X/Y count + description

- [ ] **Step 1: Create widget**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/achievement_group.dart';

class AchievementGroupRow extends StatelessWidget {
  const AchievementGroupRow({super.key, required this.group});

  final AchievementGroup group;

  Color _tileColor() {
    // Cycle through the gamification palette based on group key hash so
    // rows visually differ even when all are partially complete.
    final palette = [
      AppColors.danger,
      AppColors.primary,
      AppColors.wasp,
      AppColors.secondary,
      AppColors.streakOrange,
    ];
    final idx = group.groupKey.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final tileColor = _tileColor();
    final progress = group.progress;
    final progressLabel = group.isMaxed
        ? 'MAX'
        : '${group.currentValue}/${group.targetValue}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon tile with LEVEL label
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(group.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 2),
                Text(
                  group.isMaxed ? 'MAX' : 'LEVEL ${group.currentLevel}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Text + progress column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.neutralText,
                        ),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.gray200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      group.isMaxed ? AppColors.primary : AppColors.wasp,
                    ),
                  ),
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    group.description,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.gray600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/widgets/badges/achievement_group_row.dart`

**NOTE on color palette**: the subagent must verify each `AppColors.*` member name actually exists by reading `lib/app/theme.dart`. If `AppColors.gray600` or `AppColors.neutralText` don't exist, substitute with the closest existing member (e.g. `AppColors.gray700` or `Colors.black87`). Do NOT invent names.

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/badges/achievement_group_row.dart
git commit -m "feat(badges): add AchievementGroupRow widget"
```

---

## Task 5: `AllBadgesScreen`

**Files:**
- Create: `lib/presentation/screens/badges/all_badges_screen.dart`

- [ ] **Step 1: Create screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../providers/badge_progress_provider.dart';
import '../../widgets/badges/achievement_group_row.dart';

class AllBadgesScreen extends ConsumerWidget {
  const AllBadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(achievementGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Achievements',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.neutralText,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load achievements.\n$e',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: AppColors.gray600),
            ),
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text(
                'No achievements yet.',
                style: GoogleFonts.nunito(fontSize: 16, color: AppColors.gray600),
              ),
            );
          }
          final earnedCount =
              groups.fold<int>(0, (sum, g) => sum + g.currentLevel);
          final totalCount =
              groups.fold<int>(0, (sum, g) => sum + g.maxLevel);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: groups.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    '$earnedCount / $totalCount earned',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.gray600,
                    ),
                  ),
                );
              }
              return AchievementGroupRow(group: groups[index - 1]);
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/badges/`

Expected: No errors. If `AppColors.neutralText` / `gray600` don't exist, swap with verified members.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/badges/all_badges_screen.dart
git commit -m "feat(badges): add AllBadgesScreen with grouped tracks"
```

---

## Task 6: Router — Add `/badges` Route

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Read the file**

Read `/Users/wonderelt/Desktop/Owlio/lib/app/router.dart` fully to locate the `AppRoutes` class (around line 55) and the `StatefulShellRoute.indexedStack` Branch 0 config (around line 458-470).

- [ ] **Step 2: Add route constant**

Inside the `AppRoutes` class, after an existing constant (e.g. `quests`), add:

```dart
  static const allBadges = '/badges';
```

- [ ] **Step 3: Add `GoRoute` in Branch 0 (Vocab/Profile)**

Inside Branch 0's `routes: [...]`, after the existing profile-adjacent `GoRoute`s, add:

```dart
GoRoute(
  path: AppRoutes.allBadges,
  builder: (context, state) => const AllBadgesScreen(),
),
```

Add the import at the top:

```dart
import '../presentation/screens/badges/all_badges_screen.dart';
```

**IMPORTANT**: the subagent must verify where Branch 0 sits (not inside Branch 1/Library or any other). Branch 0 is the Vocab/Profile tab. If unsure, report the structure with NEEDS_CONTEXT rather than guessing.

- [ ] **Step 4: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/app/router.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat(routing): add /badges route for AllBadgesScreen"
```

---

## Task 7: Profile "See All" Button — Fix Navigation

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart`

- [ ] **Step 1: Edit the navigation call**

In `/Users/wonderelt/Desktop/Owlio/lib/presentation/screens/profile/profile_screen.dart`, line 907 currently reads:

```dart
                      onPressed: () {
                        context.go(AppRoutes.quests);
                      },
```

Replace `AppRoutes.quests` with `AppRoutes.allBadges`:

```dart
                      onPressed: () {
                        context.go(AppRoutes.allBadges);
                      },
```

- [ ] **Step 2: Verify analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/profile/profile_screen.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "fix(profile): route See All Badges button to /badges"
```

---

## Task 8: End-to-End Smoke Test

- [ ] **Step 1: Dart analyzer across main app**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Confirm: no NEW errors introduced by this feature. Pre-existing info-level warnings OK.

- [ ] **Step 2: Launch the app**

```bash
cd /Users/wonderelt/Desktop/Owlio && flutter run -d chrome
```

Expect Chrome to launch. Log in as `advstu1` (the advanced test user) via `advanced@demo.com` / `Test1234`.

**Manual steps to confirm (flag these for the user, subagent cannot execute):**

- [ ] Navigate to Profile → Recent Badges section shows up
- [ ] Click "See All ... Badges" button → navigates to `/badges`
- [ ] All Badges screen renders:
  - Header "X / Y earned" shows e.g. "17 / 43 earned"
  - Multiple group rows visible
  - Streak row shows LEVEL N with progress toward next tier
  - XP row shows current XP / next tier
  - Card Collection row shows total cards / next tier
  - League row shows current tier + next (unless Diamond)
  - 8 Myth Category rows each show category progress
  - Maxed groups (if any) show MAX label + full progress bar + green color
- [ ] Back button returns to Profile
- [ ] Sorting: incomplete groups first (highest progress first), maxed groups last

- [ ] **Step 3: Report**

If any of the manual steps fail, the subagent should STOP and flag it. Don't auto-fix — report and let the human decide.

---

## Completion Criteria

- [ ] 5 new files created, 2 files modified
- [ ] `dart analyze lib/` clean (no new errors)
- [ ] Route `/badges` registered and navigable
- [ ] Profile "See All" button goes to the new screen
- [ ] Advstu1 sees meaningful progress on the new screen

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Provider not found (`categoryProgressProvider`, `vocabularyStatsProvider`) | Subagent must verify each import; if missing, report NEEDS_CONTEXT |
| `AppColors` member names differ | **Pre-verified by controller**: `gray200, gray600, primary, wasp, danger, secondary, streakOrange, neutralText` all exist in `lib/app/theme.dart`. Safe to use as-written. |
| `DbTables.activityResults` wrong name | **Pre-verified by controller**: `DbTables.activityResults = 'activity_results'` exists at `packages/owlio_shared/lib/src/constants/tables.dart:29`. Safe to use. |
| Branch 0 in router isn't what I expect | Subagent reads `lib/app/router.dart` fully; if layout unclear, report NEEDS_CONTEXT rather than inventing |
| Perfect scores SDK limit | Use client-side filter fallback shown in Task 2 |
| Loading states cascade in provider (anything null → whole thing loading) | Deliberate — a partial view would be misleading. If UX complains later, refine to per-group skeletons |
| `user.leagueTier` shape (String vs enum) | **Pre-verified by controller**: `user.leagueTier` is a non-nullable `LeagueTier` enum (default bronze). Task 3 already adapted: calls `user?.leagueTier.dbValue` to convert to the 'bronze'/'silver'/... snake_case string that `_leagueTierOrdinal(String?)` expects. |

---

## Out of Scope (explicit)

- No DB/RPC changes
- No admin panel changes
- No "badge detail" modal (clicking a row does nothing for now)
- No "last 5 badges" redesign on the profile screen — the "See All" button now just points to the new page; the recent-badges list stays
- No onboarding/empty-state polish beyond the simple "No achievements yet" line
- No analytics events
