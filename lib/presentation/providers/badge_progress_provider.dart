import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return AsyncValue.error(
      allBadgesAsync.error!,
      allBadgesAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (userBadgesAsync.hasError) {
    return AsyncValue.error(
      userBadgesAsync.error!,
      userBadgesAsync.stackTrace ?? StackTrace.current,
    );
  }

  final allBadges = allBadgesAsync.value ?? const <Badge>[];
  final earnedIds = (userBadgesAsync.value ?? const [])
      .map((ub) => ub.badgeId)
      .toSet();
  final user = userAsync.value;

  final xp = user?.xp ?? 0;
  final streak = displayStreak;
  final level = user?.level ?? 0;
  // user.leagueTier is a non-nullable LeagueTier enum — convert to snake_case slug.
  final tierOrdinal = _leagueTierOrdinal(user?.leagueTier.dbValue);
  final totalCards = (userCardsAsync.value ?? const []).length;
  final booksCompleted = (completedBooksAsync.value ?? const <String>{}).length;
  final vocabMastered = (vocabStatsAsync.value ?? const <String, int>{})['mastered'] ?? 0;
  final perfectScores = perfectScoresAsync.value ?? 0;

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
        for (final entry in categoryProgress.entries) {
          if (entry.key.dbValue == slug) return entry.value;
        }
        return 0;
      case BadgeConditionType.leagueTierReached:
        return tierOrdinal;
    }
  }

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
      orElse: () => badges.last,
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
      targetValue: effectiveNext == null ? 0 : thresholdFor(effectiveNext),
      nextBadge: effectiveNext,
    ),);
  }

  groups.sort((a, b) {
    if (a.isMaxed && !b.isMaxed) return 1;
    if (!a.isMaxed && b.isMaxed) return -1;
    if (a.isMaxed && b.isMaxed) return a.title.compareTo(b.title);
    final progressCmp = b.progress.compareTo(a.progress);
    if (progressCmp != 0) return progressCmp;
    return a.groupKey.compareTo(b.groupKey);
  });

  return AsyncValue.data(groups);
});
