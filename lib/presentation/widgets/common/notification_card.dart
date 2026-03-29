import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/badge_earned.dart';

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
        onDismiss: onDismiss,
      );
    }

    return NotificationCard(
      icon: '🏅',
      title: '${badges.length} New Badges!',
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
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // X close button — top-right
                Positioned(
                  top: -16,
                  right: -16,
                  child: IconButton(
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.gray400,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
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
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Subtitle
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.subtitleColor ?? AppColors.gray500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Body
                    if (widget.body != null) ...[
                      const SizedBox(height: 16),
                      widget.body!,
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    if (widget.secondaryButtonLabel != null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onSecondaryButtonPressed ??
                                  widget.onDismiss,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gray600,
                                side: const BorderSide(
                                  color: AppColors.gray300,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                widget.secondaryButtonLabel!,
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PrimaryButton(
                              label: widget.buttonLabel,
                              color: widget.buttonColor,
                              onPressed:
                                  widget.onButtonPressed ?? widget.onDismiss,
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: _PrimaryButton(
                          label: widget.buttonLabel,
                          color: widget.buttonColor,
                          onPressed:
                              widget.onButtonPressed ?? widget.onDismiss,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primary button (extracted to avoid duplication)
// ---------------------------------------------------------------------------

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

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
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
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
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$xp XP',
        style: GoogleFonts.nunito(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
