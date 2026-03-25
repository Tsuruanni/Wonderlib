# Profile Screen Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the student profile screen from scratch with proper data, organized sections, and polished UI — replacing hard-coded/fake data with real providers.

**Architecture:** The profile screen will be a single `ConsumerWidget` that watches multiple existing providers (`userControllerProvider`, `userStatsProvider`, `vocabularyStatsSimpleProvider`, `userBadgesProvider`, `userCardStatsProvider`) plus a new `profileContextProvider` for school/class name resolution. The level formula will be extracted to a shared `LevelHelper` utility. Each visual section is a private widget within the profile screen file.

**Tech Stack:** Flutter, Riverpod, Supabase (existing RPC `get_user_stats`), GoogleFonts, flutter_animate

**Dropped from old screen:** Settings button (was `// TODO`), "Downloaded Books" card, "Top 3 Finishes" (was fake data), hard-coded "Joined" date. The `profileDownloads` route still exists and is accessible from elsewhere.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/core/utils/level_helper.dart` | Extracted `xpForLevel()` formula + progress calculation (shared between ProfileScreen and StudentProfileDialog) |
| Create | `lib/presentation/providers/profile_context_provider.dart` | Fetches school name + class name by UUID from Supabase |
| Modify | `lib/presentation/screens/profile/profile_screen.dart` | Complete rewrite — new layout with 8 sections |
| Modify | `lib/presentation/widgets/common/student_profile_dialog.dart` | Replace inline `_xpForLevel()` with `LevelHelper` import |

### Existing providers used (no changes):

| Provider | Data | Source |
|----------|------|--------|
| `userControllerProvider` | User entity (xp, level, coins, streak, avatar, schoolId, classId) | `profiles` table |
| `userStatsProvider` | `Map<String, dynamic>` with books_completed, chapters_completed, total_reading_time, words_mastered | `get_user_stats` RPC |
| `vocabularyStatsSimpleProvider` | `VocabularyStats` with masteredCount, learningCount, reviewingCount | Client-side computation from `vocabulary_progress` |
| `userBadgesProvider` | `List<UserBadge>` ordered by `earned_at DESC` | `user_badges` + `badges` join |
| `userCardStatsProvider` | `UserCardStats` with totalUniqueCards, totalPacksOpened | `user_card_stats` table |
| `todayReviewSessionProvider` | `DailyReviewSession?` | `daily_review_sessions` |
| `dailyReviewWordsProvider` | `List<VocabularyWord>` | `vocabulary_progress` due words |

---

## Final Screen Layout (top to bottom)

```
┌─────────────────────────────────────────┐
│ AppBar: "PROFILE" (no settings button)  │
├─────────────────────────────────────────┤
│ 1. HEADER                               │
│    Avatar (image or initials)           │
│    Full Name                            │
│    @username                            │
│    School • Class                       │
├─────────────────────────────────────────┤
│ 2. LEVEL & XP                           │
│    Level badge + XP count               │
│    Progress bar to next level           │
│    "Level 5 — 62% to next level"        │
├─────────────────────────────────────────┤
│ 3. CARD COLLECTION                      │
│    Icon + "Card Collection" + "32/96"   │
│    Progress bar                         │
│    "12 packs opened"                    │
├─────────────────────────────────────────┤
│ 4. RECENT BADGES                        │
│    "Recent Badges" + badge count        │
│    Last 5 badges (emoji + name + date)  │
│    "See All" button (shows all badges)  │
│    Empty state if no badges             │
├─────────────────────────────────────────┤
│ 5. READING STATS                        │
│    2-column grid:                       │
│    Books Completed | Chapters Read      │
│    Reading Time    | (empty or streak)  │
├─────────────────────────────────────────┤
│ 6. VOCABULARY STATS                     │
│    3-column: Mastered | Learning | New  │
│    "My Word Bank" tappable card →       │
├─────────────────────────────────────────┤
│ 7. DAILY REVIEW CARD                    │
│    (existing 3-state widget, preserved) │
├─────────────────────────────────────────┤
│ 8. SIGN OUT                             │
│    Outline button with confirm dialog   │
└─────────────────────────────────────────┘
```

---

## Task 1: Extract LevelHelper utility

**Files:**
- Create: `lib/core/utils/level_helper.dart`
- Modify: `lib/presentation/widgets/common/student_profile_dialog.dart:435-438`

- [ ] **Step 1: Create `LevelHelper` class**

```dart
// lib/core/utils/level_helper.dart

/// Shared level/XP calculation used by ProfileScreen and StudentProfileDialog.
/// Formula: Level n starts at (n-1) * n * 50 cumulative XP.
/// Level 1 = 0, Level 2 = 100, Level 3 = 300, Level 4 = 600, Level 5 = 1000, ...
abstract class LevelHelper {
  /// Cumulative XP threshold to reach [level].
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level - 1) * level * 50;
  }

  /// XP earned within current level (numerator for progress bar).
  static int xpInCurrentLevel(int totalXp, int level) {
    return totalXp - xpForLevel(level);
  }

  /// XP needed to go from [level] to [level + 1] (denominator for progress bar).
  static int xpToNextLevel(int level) {
    return xpForLevel(level + 1) - xpForLevel(level);
  }

  /// Progress fraction (0.0 to 1.0) toward next level.
  static double progress(int totalXp, int level) {
    final needed = xpToNextLevel(level);
    if (needed <= 0) return 1.0;
    return (xpInCurrentLevel(totalXp, level) / needed).clamp(0.0, 1.0);
  }
}
```

- [ ] **Step 2: Update StudentProfileDialog to use LevelHelper**

In `lib/presentation/widgets/common/student_profile_dialog.dart`:

Replace the `_xpForLevel` method and its usages:

```dart
// Add import at top:
import '../../../core/utils/level_helper.dart';

// In _buildLevelProgress(), replace:
//   final xpInLevel = entry.totalXp - _xpForLevel(entry.level);
//   final xpNeeded = _xpForLevel(entry.level + 1) - _xpForLevel(entry.level);
//   final progress = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;
// With:
final progress = LevelHelper.progress(entry.totalXp, entry.level);

// In the Text widget below, replace:
//   'Level ${entry.level} — ${(progress * 100).toInt()}% to next level'
// (no change needed — same variable name)

// Delete the static _xpForLevel method (lines 435-438)
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/core/utils/level_helper.dart lib/presentation/widgets/common/student_profile_dialog.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/core/utils/level_helper.dart lib/presentation/widgets/common/student_profile_dialog.dart
git commit -m "refactor: extract LevelHelper utility from StudentProfileDialog"
```

---

## Task 2: Create profileContextProvider

**Files:**
- Create: `lib/presentation/providers/profile_context_provider.dart`

This provider resolves the current user's `schoolId` and `classId` UUIDs to human-readable names via simple Supabase lookups.

- [ ] **Step 1: Create the provider**

```dart
// lib/presentation/providers/profile_context_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_provider.dart';

/// Resolved school + class names for the current user's profile display.
class ProfileContext {
  const ProfileContext({this.schoolName, this.className});
  final String? schoolName;
  final String? className;
}

/// Fetches the current user's school name and class name by UUID.
/// Note: Direct Supabase query (bypasses UseCase layer) — pragmatic choice
/// for two simple single-row lookups that don't warrant full UseCase/Repo plumbing.
final profileContextProvider = FutureProvider<ProfileContext>((ref) async {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user == null) return const ProfileContext();

  final supabase = Supabase.instance.client;
  String? schoolName;
  String? className;

  try {
    final schoolResult = await supabase
        .from(DbTables.schools)
        .select('name')
        .eq('id', user.schoolId)
        .maybeSingle();
    schoolName = schoolResult?['name'] as String?;
  } catch (_) {}

  if (user.classId != null) {
    try {
      final classResult = await supabase
          .from(DbTables.classes)
          .select('name')
          .eq('id', user.classId!)
          .maybeSingle();
      className = classResult?['name'] as String?;
    } catch (_) {}
  }

  return ProfileContext(schoolName: schoolName, className: className);
});
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/providers/profile_context_provider.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/profile_context_provider.dart
git commit -m "feat: add profileContextProvider for school/class name resolution"
```

---

## Task 3: Rewrite ProfileScreen — Header + Level & XP

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart`

This task replaces the entire file. Because the file is 764 lines and we're doing a complete rewrite, we write it in stages. This task covers the scaffold, header section (1), and level & XP section (2).

- [ ] **Step 1: Write the new ProfileScreen scaffold + Header + Level**

Replace the entire contents of `lib/presentation/screens/profile/profile_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/level_helper.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/daily_review_session.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/profile_context_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/pressable_scale.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'PROFILE',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: AppColors.neutralText,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          if (!user.role.isStudent) {
            return _buildTeacherFallback(context, ref);
          }
          return _StudentProfileBody(user: user);
        },
      ),
    );
  }

  Widget _buildTeacherFallback(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: 64, color: AppColors.neutralText),
            const SizedBox(height: 16),
            Text(
              'Teacher Profile',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 32),
            GameButton(
              label: 'SIGN OUT',
              onPressed: () async {
                final confirmed = await context.showConfirmDialog(
                  title: 'Sign Out',
                  message: 'Are you sure you want to sign out?',
                  confirmText: 'Sign Out',
                  isDestructive: true,
                );
                if (confirmed ?? false) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
              variant: GameButtonVariant.outline,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentProfileBody extends ConsumerWidget {
  const _StudentProfileBody({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // 1. Header
          _ProfileHeader(user: user).animate().fadeIn().moveY(begin: 10, end: 0),
          const SizedBox(height: 24),

          // 2. Level & XP
          _LevelXpSection(user: user).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 20),

          // 3. Card Collection
          const _CardCollectionSection().animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),

          // 4. Recent Badges
          const _RecentBadgesSection().animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 20),

          // 5. Reading Stats
          const _ReadingStatsSection().animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 20),

          // 6. Vocabulary Stats
          const _VocabularyStatsSection().animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 20),

          // 7. Daily Review
          const _DailyReviewProfileCard().animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 32),

          // 8. Sign Out
          const _SignOutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. HEADER
// ─────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileContext = ref.watch(profileContextProvider).valueOrNull;

    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: ClipOval(
            child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? Image.network(
                    user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitials(),
                  )
                : _buildInitials(),
          ),
        ),
        const SizedBox(height: 12),

        // Full Name
        Text(
          user.fullName,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),

        // Username
        if (user.username != null && user.username!.isNotEmpty)
          Text(
            '@${user.username}',
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: AppColors.neutralText,
              fontWeight: FontWeight.w600,
            ),
          ),

        const SizedBox(height: 6),

        // School & Class
        if (profileContext != null) _buildSchoolClass(profileContext),
      ],
    );
  }

  Widget _buildInitials() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          user.initials,
          style: GoogleFonts.nunito(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolClass(ProfileContext ctx) {
    final parts = <String>[];
    if (ctx.schoolName != null) parts.add(ctx.schoolName!);
    if (ctx.className != null) parts.add(ctx.className!);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.school_rounded, size: 16, color: AppColors.neutralText),
        const SizedBox(width: 4),
        Text(
          parts.join(' • '),
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppColors.neutralText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 2. LEVEL & XP
// ─────────────────────────────────────────────

class _LevelXpSection extends StatelessWidget {
  const _LevelXpSection({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final progress = LevelHelper.progress(user.xp, user.level);
    final xpIn = LevelHelper.xpInCurrentLevel(user.xp, user.level);
    final xpNeeded = LevelHelper.xpToNextLevel(user.level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.neutral, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.wasp.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.wasp, width: 2),
                ),
                child: Text(
                  'LVL ${user.level}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.waspDark,
                  ),
                ),
              ),
              const Spacer(),
              // XP count
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 20, color: AppColors.wasp),
                  const SizedBox(width: 4),
                  Text(
                    '${user.xp} XP',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
              color: AppColors.wasp,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level ${user.level} — $xpIn / $xpNeeded XP to next level',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLACEHOLDER SECTIONS (implemented in next tasks)
// ─────────────────────────────────────────────

class _CardCollectionSection extends ConsumerWidget {
  const _CardCollectionSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _RecentBadgesSection extends ConsumerWidget {
  const _RecentBadgesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _ReadingStatsSection extends ConsumerWidget {
  const _ReadingStatsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _VocabularyStatsSection extends ConsumerWidget {
  const _VocabularyStatsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _DailyReviewProfileCard extends ConsumerWidget {
  const _DailyReviewProfileCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GameButton(
      label: 'SIGN OUT',
      onPressed: () async {
        final confirmed = await context.showConfirmDialog(
          title: 'Sign Out',
          message: 'Are you sure you want to sign out?',
          confirmText: 'Sign Out',
          isDestructive: true,
        );
        if (confirmed ?? false) {
          await ref.read(authControllerProvider.notifier).signOut();
        }
      },
      variant: GameButtonVariant.outline,
      fullWidth: true,
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No issues (unused imports are OK at this stage — they'll be used in later tasks)

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat: rewrite profile screen scaffold with header + level sections"
```

---

## Task 4: Card Collection section

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart` (replace `_CardCollectionSection` placeholder)

- [ ] **Step 1: Replace `_CardCollectionSection`**

Replace the placeholder with:

```dart
class _CardCollectionSection extends ConsumerWidget {
  const _CardCollectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userCardStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        const totalCards = AppConstants.totalCardCount;
        final progress = stats.totalUniqueCards / totalCards;

        return PressableScale(
          onTap: () => context.push(AppRoutes.cards),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardEpic.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cardEpic.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardEpic.withValues(alpha: 0.1),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.collections_bookmark_rounded,
                        size: 22, color: AppColors.cardEpic),
                    const SizedBox(width: 8),
                    Text(
                      'Card Collection',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stats.totalUniqueCards} / $totalCards',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.cardEpic,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.cardEpic),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                    color: AppColors.cardEpic,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${stats.totalPacksOpened} packs opened',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat(profile): add card collection section with progress bar"
```

---

## Task 5: Recent Badges section

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart` (replace `_RecentBadgesSection` placeholder)

Uses `userBadgesProvider` (ordered by `earned_at DESC`) and takes first 5. Each badge shows emoji, name, and relative earned date.

- [ ] **Step 1: Replace `_RecentBadgesSection`**

```dart
class _RecentBadgesSection extends ConsumerWidget {
  const _RecentBadgesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider);

    return badgesAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (allBadges) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.neutral, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Badges',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${allBadges.length}',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (allBadges.isEmpty)
                // Empty state
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 32, color: AppColors.neutralText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete lessons to earn badges!',
                          style: GoogleFonts.nunito(
                            color: AppColors.neutralText,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Last 5 badges
                ...allBadges.take(5).map((b) => _BadgeRow(badge: b)),

                // "See All" button if more than 5
                if (allBadges.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        _showAllBadgesSheet(context, allBadges);
                      },
                      child: Text(
                        'See All ${allBadges.length} Badges',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAllBadgesSheet(BuildContext context, List<UserBadge> badges) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'All Badges (${badges.length})',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: badges.length,
                  itemBuilder: (_, i) => _BadgeRow(badge: badges[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});
  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Badge icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                badge.badge.icon ?? '🏆',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.badge.name,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.black,
                  ),
                ),
                if (badge.badge.description != null)
                  Text(
                    badge.badge.description!,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Earned date
          Text(
            _formatDate(badge.earnedAt),
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat(profile): add recent badges section with see-all bottom sheet"
```

---

## Task 6: Reading Stats + Vocabulary Stats sections

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart` (replace `_ReadingStatsSection` and `_VocabularyStatsSection` placeholders)

- [ ] **Step 1: Replace `_ReadingStatsSection`**

```dart
class _ReadingStatsSection extends ConsumerWidget {
  const _ReadingStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final booksCompleted = stats['books_completed'] as int? ?? 0;
        final chaptersCompleted = stats['chapters_completed'] as int? ?? 0;
        final readingTimeMin = stats['total_reading_time'] as int? ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.neutral, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded,
                      size: 22, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Reading Stats',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.menu_book_rounded,
                      value: '$booksCompleted',
                      label: 'Books',
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.bookmark_rounded,
                      value: '$chaptersCompleted',
                      label: 'Chapters',
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.schedule_rounded,
                      value: _formatTime(readingTimeMin),
                      label: 'Reading',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}
```

- [ ] **Step 2: Replace `_VocabularyStatsSection`**

```dart
class _VocabularyStatsSection extends ConsumerWidget {
  const _VocabularyStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabularyStatsSimpleProvider);

    return vocabAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.neutral, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.translate_rounded,
                      size: 22, color: AppColors.gemBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Vocabulary',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.check_circle_rounded,
                      value: '${stats.masteredCount}',
                      label: 'Mastered',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.loop_rounded,
                      value: '${stats.inProgressCount}',
                      label: 'Learning',
                      color: AppColors.streakOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.fiber_new_rounded,
                      value: '${stats.newCount}',
                      label: 'New',
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Word Bank shortcut
              PressableScale(
                onTap: () => context.push(AppRoutes.wordBank),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.gemBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.library_books_rounded,
                          size: 18, color: AppColors.gemBlue),
                      const SizedBox(width: 8),
                      Text(
                        'My Word Bank',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.gemBlue,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.gemBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Add shared `_MiniStat` widget (used by both sections)**

Place this after `_VocabularyStatsSection`:

```dart
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.black,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat(profile): add reading stats and vocabulary stats sections"
```

---

## Task 7: Daily Review card (port from old code)

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart` (replace `_DailyReviewProfileCard` placeholder)

Port the existing daily review card logic from the old profile screen. The 3-state card (completed / ready / building up) works well and should be preserved as-is.

- [ ] **Step 1: Replace `_DailyReviewProfileCard`**

```dart
class _DailyReviewProfileCard extends ConsumerWidget {
  const _DailyReviewProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.replay_rounded, size: 22, color: AppColors.streakOrange),
            const SizedBox(width: 8),
            Text(
              'Daily Vocabulary Review',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todaySession != null)
          _buildCompletedCard(todaySession)
        else if (dueWords.length >= minDailyReviewCount)
          _buildReadyCard(context, dueWords.length)
        else
          _buildBuildingUpCard(dueWords.length),
      ],
    );
  }

  Widget _buildCompletedCard(DailyReviewSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Complete!',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '+${session.xpEarned} XP earned today',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyCard(BuildContext context, int wordCount) {
    return PressableScale(
      onTap: () => context.push(AppRoutes.vocabularyDailyReview),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.streakOrange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.streakOrange.withValues(alpha: 0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.streakOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bolt_rounded,
                  color: AppColors.streakOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$wordCount words ready!',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.streakOrange,
                    ),
                  ),
                  Text(
                    'Tap to start your daily review',
                    style: GoogleFonts.nunito(
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.streakOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingUpCard(int currentCount) {
    final progress = currentCount / minDailyReviewCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gemBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.gemBlue.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hourglass_top_rounded,
                color: AppColors.gemBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Words Building Up',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currentCount/$minDailyReviewCount — keep learning to unlock review!',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.gemBlue.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.gemBlue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat(profile): port daily review card from old profile"
```

---

## Task 8: Final cleanup and verification

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart` — remove any unused imports
- Verify: all files compile

- [ ] **Step 1: Remove unused imports**

Check and remove any imports that are no longer needed (e.g., if `_StatBox`, `_BadgesSection` etc. from old code are gone). The new file should only import what it uses.

- [ ] **Step 2: Full analyze**

Run: `dart analyze lib/`
Expected: No new issues introduced

- [ ] **Step 3: Manual test checklist**

Test with `flutter run -d chrome` using test accounts:

- `fresh@demo.com` (0 XP, no progress) — verify empty states:
  - Header shows initials (no avatar URL)
  - Level shows LVL 1, 0 XP, empty progress bar
  - Card collection shows 0/96
  - Badges shows empty state
  - Reading stats show 0 / 0 / 0m
  - Vocabulary shows 0 / 0 / 0
  - Daily review shows "building up"

- `active@demo.com` (500 XP, mid-progress) — verify real data:
  - Level + progress bar shows correct values
  - Badges list shows earned badges with dates
  - Reading/vocab stats populated

- `teacher@demo.com` — verify teacher fallback (just sign out button)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(profile): final cleanup and verify profile screen rebuild"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Extract LevelHelper | `level_helper.dart` (new) + `student_profile_dialog.dart` (modify) |
| 2 | profileContextProvider | `profile_context_provider.dart` (new) |
| 3 | Scaffold + Header + Level | `profile_screen.dart` (rewrite) |
| 4 | Card Collection | `profile_screen.dart` (fill placeholder) |
| 5 | Recent Badges | `profile_screen.dart` (fill placeholder) |
| 6 | Reading + Vocabulary Stats | `profile_screen.dart` (fill placeholder) |
| 7 | Daily Review | `profile_screen.dart` (fill placeholder) |
| 8 | Cleanup + verify | All files |
