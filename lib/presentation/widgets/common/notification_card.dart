import 'package:flutter/material.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/badge_earned.dart';
import '../../../domain/entities/daily_quest.dart';
import 'app_chip.dart';
import 'game_button.dart';

// ---------------------------------------------------------------------------
// Unified notification card — Duolingo-style white card with entry animation
// ---------------------------------------------------------------------------

class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.icon,
    this.iconData,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.body,
    this.buttonLabel = 'OK',
    this.buttonColor = AppColors.primary,
    this.secondaryButtonLabel,
    this.onButtonPressed,
    this.onSecondaryButtonPressed,
    required this.onDismiss,
  });

  /// Emoji string (e.g. '🎉'). Used when [iconData] is null.
  final String icon;

  /// Material icon. When provided, renders [Icon] instead of emoji.
  final IconData? iconData;

  /// Color for Material icon.
  final Color? iconColor;

  /// Main title text.
  final String title;

  /// Subtitle text.
  final String? subtitle;

  /// Color for subtitle.
  final Color? subtitleColor;

  /// Optional body widget (pills, badge lists, etc.).
  final Widget? body;

  /// Primary button label.
  final String buttonLabel;

  /// Primary button color.
  final Color buttonColor;

  /// If non-null, shows an outlined secondary button on the left.
  final String? secondaryButtonLabel;

  /// Primary button callback — defaults to [onDismiss].
  final VoidCallback? onButtonPressed;

  /// Secondary button callback — defaults to [onDismiss].
  final VoidCallback? onSecondaryButtonPressed;

  /// X-button + default button callback.
  final VoidCallback onDismiss;

  // ---- Static factory methods ----

  static Widget levelUp({
    required int oldLevel,
    required int newLevel,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '🎉',
      title: 'Level Up!',
      subtitle: 'Great job! Keep it up!',
      subtitleColor: AppColors.primary,
      body: _TransitionPill(
        from: 'Level $oldLevel',
        to: 'Level $newLevel',
        color: AppColors.primary,
      ),
      buttonColor: AppColors.primary,
      onDismiss: onDismiss,
    );
  }

  static Widget leagueChange({
    required LeagueTier oldTier,
    required LeagueTier newTier,
    required VoidCallback onDismiss,
  }) {
    final isPromotion = newTier.index > oldTier.index;
    final tierColor = _leagueTierColor(newTier);
    final tierEmoji = _leagueTierEmoji(newTier);

    return NotificationCard(
      icon: isPromotion ? tierEmoji : '📉',
      title: isPromotion ? 'League Promoted!' : 'League Demoted',
      subtitle: isPromotion
          ? 'Great work this week! Keep climbing!'
          : 'Keep practicing to climb back up!',
      subtitleColor: isPromotion ? tierColor : AppColors.danger,
      body: _TransitionPill(
        from: oldTier.label,
        to: newTier.label,
        color: isPromotion ? tierColor : AppColors.danger,
        isUpward: isPromotion,
      ),
      buttonColor: isPromotion ? tierColor : AppColors.danger,
      onDismiss: onDismiss,
    );
  }

  static Widget leagueJoined({
    required LeagueTier tier,
    required VoidCallback onDismiss,
  }) {
    final tierColor = _leagueTierColor(tier);
    final tierEmoji = _leagueTierEmoji(tier);

    return NotificationCard(
      icon: tierEmoji,
      title: 'Welcome to ${tier.label} League!',
      subtitle: "You're now competing with 30 rivals.\nEarn XP to climb the ranks!",
      subtitleColor: tierColor,
      buttonLabel: "LET'S GO!",
      buttonColor: tierColor,
      onDismiss: onDismiss,
    );
  }

  static Color _leagueTierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => Colors.brown,
      LeagueTier.silver => Colors.grey,
      LeagueTier.gold => Colors.amber,
      LeagueTier.platinum => Colors.blueGrey,
      LeagueTier.diamond => Colors.cyan,
    };
  }

  static String _leagueTierEmoji(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => '🥉',
      LeagueTier.silver => '🥈',
      LeagueTier.gold => '🥇',
      LeagueTier.platinum => '💎',
      LeagueTier.diamond => '👑',
    };
  }

  static Widget streakExtended({
    required int newStreak,
    required int previousStreak,
    required VoidCallback onDismiss,
  }) {
    final isFirstDay = previousStreak == 0;

    final title = isFirstDay ? "Day 1! Let's go!" : 'Day $newStreak!';

    final subtitle = isFirstDay
        ? 'Your learning streak starts today!'
        : _streakSubtitles[newStreak % _streakSubtitles.length];

    return NotificationCard(
      icon: '',
      iconData: Icons.local_fire_department_rounded,
      iconColor: AppColors.streakOrange,
      title: title,
      subtitle: subtitle,
      subtitleColor: AppColors.streakOrange,
      buttonColor: AppColors.streakOrange,
      onDismiss: onDismiss,
    );
  }

  static Widget streakMilestone({
    required int newStreak,
    required int bonusXp,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '',
      iconData: Icons.local_fire_department_rounded,
      iconColor: AppColors.streakOrange,
      title: '$newStreak-Day Streak!',
      subtitle: '+$bonusXp XP earned!',
      subtitleColor: AppColors.streakOrange,
      buttonColor: AppColors.streakOrange,
      onDismiss: onDismiss,
    );
  }

  static Widget streakFreeze({
    required int newStreak,
    required int freezesRemaining,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '',
      iconData: Icons.ac_unit,
      iconColor: AppColors.secondary,
      title: 'Streak Freeze Saved You!',
      subtitle:
          'Your $newStreak-day streak is safe.\n$freezesRemaining freeze${freezesRemaining == 1 ? '' : 's'} left.',
      subtitleColor: AppColors.secondary,
      buttonColor: AppColors.secondary,
      onDismiss: onDismiss,
    );
  }

  static Widget streakBroken({
    required int previousStreak,
    required int freezesConsumed,
    required VoidCallback onDismiss,
  }) {
    String title;
    String subtitle;

    if (previousStreak <= 6) {
      title = 'Welcome Back!';
      subtitle = 'Start a new streak today.';
    } else if (previousStreak <= 9) {
      title = 'Your $previousStreak-day streak ended';
      subtitle = 'You can build it again!';
    } else if (previousStreak <= 20) {
      title = 'Your $previousStreak-day streak was broken';
      subtitle = "Don't give up!";
    } else {
      title = 'Your $previousStreak-day streak was broken';
      subtitle = 'That was impressive — you can do it again!';
    }

    if (freezesConsumed > 0) {
      subtitle +=
          '\n\nYour $freezesConsumed freeze${freezesConsumed == 1 ? '' : 's'} covered $freezesConsumed day${freezesConsumed == 1 ? '' : 's'}, but you were away too long.';
    }

    return NotificationCard(
      icon: '',
      iconData: Icons.local_fire_department_rounded,
      iconColor: AppColors.gray400,
      title: title,
      subtitle: subtitle,
      subtitleColor: AppColors.gray500,
      buttonColor: AppColors.gray400,
      onDismiss: onDismiss,
    );
  }

  static Widget badgeEarned({
    required List<BadgeEarned> badges,
    required VoidCallback onDismiss,
  }) {
    final isSingle = badges.length == 1;

    if (isSingle) {
      final badge = badges.first;
      return NotificationCard(
        icon: badge.badgeIcon,
        title: 'New Badge!',
        subtitle: badge.badgeName,
        subtitleColor: AppColors.gray500,
        body: _XpChip(xp: badge.xpReward),
        buttonColor: AppColors.wasp,
        onDismiss: onDismiss,
      );
    }

    return NotificationCard(
      icon: '🏅',
      title: '${badges.length} New Badges!',
      buttonColor: AppColors.wasp,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: badges
            .map(
              (badge) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      badge.badgeIcon,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        badge.badgeName,
                        style: AppTextStyles.bodyLarge()
                            .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    _XpChip(xp: badge.xpReward),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      onDismiss: onDismiss,
    );
  }

  static Widget assignment({
    required int count,
    required VoidCallback onView,
    required VoidCallback onDismiss,
  }) {
    final isSingle = count == 1;
    return NotificationCard(
      icon: '📋',
      title: isSingle ? 'New Assignment!' : '$count New Assignments!',
      subtitle: isSingle
          ? 'Your teacher sent you an assignment.'
          : 'Your teacher sent you $count assignments.',
      subtitleColor: AppColors.gray500,
      secondaryButtonLabel: 'Later',
      buttonLabel: 'View',
      buttonColor: AppColors.secondary,
      onButtonPressed: onView,
      onDismiss: onDismiss,
    );
  }

  static Widget questComplete({
    required List<DailyQuestProgress> quests,
    required bool allQuestsComplete,
    required VoidCallback onDismiss,
  }) {
    final isSingle = quests.length == 1;

    return NotificationCard(
      icon: '🎯',
      title: isSingle ? 'Quest Complete!' : '${quests.length} Quests Complete!',
      subtitle: allQuestsComplete
          ? 'All quests done! Claim your bonus card pack!'
          : null,
      subtitleColor: AppColors.wasp,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: quests.map((p) {
          final (text, color) = _questRewardTextAndColor(p.quest);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(p.quest.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p.quest.title,
                    style: AppTextStyles.bodyMedium(color: AppColors.black)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                AppChip(
                  label: text,
                  variant: AppChipVariant.custom,
                  customColor: color,
                  uppercase: false,
                  icon: p.quest.rewardType == QuestRewardType.coins
                      ? Image.asset(
                          'assets/icons/gem_outline_256.png',
                          width: 14,
                          height: 14,
                        )
                      : null,
                ),
              ],
            ),
          );
        }).toList(),
      ),
      buttonColor: AppColors.streakOrange,
      onDismiss: onDismiss,
    );
  }

  static Widget allQuestsComplete({
    required VoidCallback onClaim,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '🏆',
      title: 'All Quests Done!',
      subtitle: 'Amazing work today!\nClaim your bonus card pack!',
      subtitleColor: AppColors.wasp,
      secondaryButtonLabel: 'Later',
      buttonLabel: 'Claim Pack',
      buttonColor: AppColors.streakOrange,
      onButtonPressed: onClaim,
      onDismiss: onDismiss,
    );
  }

  static (String, Color) _questRewardTextAndColor(DailyQuest quest) {
    return switch (quest.rewardType) {
      QuestRewardType.coins => ('+${quest.rewardAmount} gems', AppColors.wasp),
      QuestRewardType.cardPack =>
        ('+${quest.rewardAmount} pack', AppColors.gemBlue),
    };
  }

  /// Map buttonColor to the closest GameButtonVariant.
  static GameButtonVariant _colorToVariant(Color color) {
    if (color == AppColors.primary) return GameButtonVariant.primary;
    if (color == AppColors.secondary) return GameButtonVariant.secondary;
    if (color == AppColors.danger) return GameButtonVariant.danger;
    if (color == AppColors.wasp) return GameButtonVariant.wasp;
    if (color == AppColors.streakOrange) return GameButtonVariant.wasp;
    return GameButtonVariant.neutral;
  }

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

// ---------------------------------------------------------------------------
// Rotating subtitle pool for streak-extended
// ---------------------------------------------------------------------------

const _streakSubtitles = [
  'Keep it up!',
  "You're on fire!",
  'Great habit!',
  'Consistency is key!',
  'Unstoppable!',
  'Nice streak!',
];

// ---------------------------------------------------------------------------
// State — entry animation
// ---------------------------------------------------------------------------

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 340,
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            // 3D card: white face sits on top of gray bottom border
            child: Container(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.gray200,
                width: 1.5,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // X close button — top-right, circular with subtle bg
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gray200,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.gray400,
                      ),
                    ),
                  ),
                ),
                // Main content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon — Material or emoji
                    if (widget.iconData != null)
                      Icon(
                        widget.iconData,
                        size: 64,
                        color: widget.iconColor,
                      )
                    else
                      Text(
                        widget.icon,
                        style: const TextStyle(fontSize: 64),
                      ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      widget.title,
                      style: AppTextStyles.display(size: 24),
                      textAlign: TextAlign.center,
                    ),

                    // Subtitle
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        style: AppTextStyles.bodyLarge(
                          color: widget.subtitleColor ?? AppColors.gray500,
                        ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Body
                    if (widget.body != null) ...[
                      const SizedBox(height: 16),
                      widget.body!,
                    ],

                    const SizedBox(height: 24),

                    // Buttons — using existing GameButton for consistent 3D style
                    if (widget.secondaryButtonLabel != null)
                      Row(
                        children: [
                          Expanded(
                            child: GameButton(
                              label: widget.secondaryButtonLabel!,
                              onPressed:
                                  widget.onSecondaryButtonPressed ??
                                  widget.onDismiss,
                              variant: GameButtonVariant.outline,
                              fullWidth: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _variantButton(
                              label: widget.buttonLabel,
                              color: widget.buttonColor,
                              onPressed:
                                  widget.onButtonPressed ?? widget.onDismiss,
                            ),
                          ),
                        ],
                      )
                    else
                      _variantButton(
                        label: widget.buttonLabel,
                        color: widget.buttonColor,
                        onPressed:
                            widget.onButtonPressed ?? widget.onDismiss,
                        fullWidth: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper — maps color to GameButton variant
// ---------------------------------------------------------------------------

Widget _variantButton({
  required String label,
  required Color color,
  required VoidCallback onPressed,
  bool fullWidth = false,
}) {
  return GameButton(
    label: label,
    onPressed: onPressed,
    variant: NotificationCard._colorToVariant(color),
    fullWidth: fullWidth,
  );
}

// ---------------------------------------------------------------------------
// End of button helpers
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// TransitionPill — "From → To" pill for level-up / league-change
// ---------------------------------------------------------------------------

class _TransitionPill extends StatelessWidget {
  const _TransitionPill({
    required this.from,
    required this.to,
    required this.color,
    this.isUpward = true,
  });

  final String from;
  final String to;
  final Color color;
  final bool isUpward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            from,
            style: AppTextStyles.bodyLarge(color: AppColors.gray500)
                .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              isUpward ? Icons.arrow_forward : Icons.arrow_downward,
              color: color,
              size: 20,
            ),
          ),
          Text(
            to,
            style: AppTextStyles.titleMedium(color: color)
                .copyWith(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XP Chip — small purple "+N XP" badge
// ---------------------------------------------------------------------------

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    if (xp <= 0) return const SizedBox.shrink();

    return AppChip(
      label: '+$xp XP',
      variant: AppChipVariant.custom,
      customColor: Colors.purple,
      uppercase: false,
    );
  }
}
