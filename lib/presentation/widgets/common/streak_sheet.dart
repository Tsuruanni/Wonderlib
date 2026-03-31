import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/system_settings.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/user_provider.dart';

// ---------------------------------------------------------------------------
// Public helper — call from navbar / right panel
// ---------------------------------------------------------------------------

void showStreakSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const StreakSheet(),
  );
}

// ---------------------------------------------------------------------------
// StreakSheet — full-screen bottom sheet (ConsumerStatefulWidget for freeze buy)
// ---------------------------------------------------------------------------

class StreakSheet extends ConsumerStatefulWidget {
  const StreakSheet({super.key});

  @override
  ConsumerState<StreakSheet> createState() => _StreakSheetState();
}

class _StreakSheetState extends ConsumerState<StreakSheet> {
  bool _isBuyingFreeze = false;

  Future<void> _handleBuyFreeze() async {
    setState(() => _isBuyingFreeze = true);
    final error =
        await ref.read(userControllerProvider.notifier).buyStreakFreeze();
    if (!mounted) return;
    if (error != null) {
      setState(() => _isBuyingFreeze = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userControllerProvider).valueOrNull;
    final settings = ref.watch(systemSettingsProvider).valueOrNull ??
        SystemSettings.defaults();
    final calendarDays = ref.watch(loginDatesProvider).valueOrNull ?? {};

    if (user == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Banner
            _StreakBanner(
              currentStreak: user.currentStreak,
              milestones: settings.streakMilestones,
            ),
            const SizedBox(height: 24),

            // Calendar
            _StreakCalendar(
              weeklyDays: calendarDays,
              userCreatedAt: user.createdAt,
            ),
            const SizedBox(height: 24),

            // Stats + Freeze
            _StatsSection(
              longestStreak: user.longestStreak,
              freezeCount: user.streakFreezeCount,
              freezeMax: settings.streakFreezeMax,
              freezePrice: settings.streakFreezePrice,
              userCoins: user.coins,
              isBuying: _isBuyingFreeze,
              onBuyFreeze: _handleBuyFreeze,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StreakBanner — gradient header with streak count + contextual message
// ---------------------------------------------------------------------------

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({
    required this.currentStreak,
    required this.milestones,
  });

  final int currentStreak;
  final Map<int, int> milestones;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.streakOrange.withValues(alpha: 0.06),
            AppColors.streakOrange.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: Row(
        children: [
          // Left: text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currentStreak day streak',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.streakOrange,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _contextualMessage(),
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray600,
                  ),
                ),
              ],
            ),
          ),
          // Right: decorative fire icon
          Icon(
            Icons.local_fire_department_rounded,
            size: 64,
            color: AppColors.streakOrange.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  String _contextualMessage() {
    // Check milestone proximity first (overrides range message)
    final nextMilestone = milestones.keys
        .where((d) => d > currentStreak)
        .fold<int?>(null, (prev, d) => prev == null || d < prev ? d : null);
    if (nextMilestone != null && nextMilestone - currentStreak <= 2) {
      final remaining = nextMilestone - currentStreak;
      return '$remaining day${remaining == 1 ? '' : 's'} to your next milestone!';
    }

    // Range-based pool
    final List<String> pool;
    if (currentStreak <= 0) {
      pool = [
        'Start your streak today!',
        'Open the app daily to build a streak!',
      ];
    } else if (currentStreak == 1) {
      pool = [
        'Your learning streak starts today!',
        "Day 1! Let's build a habit!",
        'Every journey starts with one step!',
      ];
    } else if (currentStreak <= 6) {
      pool = [
        'Keep it up!',
        "You're building a habit!",
        'Nice momentum!',
        'Stay consistent!',
      ];
    } else if (currentStreak <= 13) {
      pool = [
        "You're on fire!",
        'One week strong!',
        'Impressive dedication!',
        'Unstoppable!',
      ];
    } else if (currentStreak <= 29) {
      pool = [
        'Two weeks and counting!',
        "You're a machine!",
        'Incredible focus!',
        'Streak master!',
      ];
    } else {
      pool = [
        'Legendary streak!',
        "You're an inspiration!",
        'Absolutely amazing!',
        'What a champion!',
      ];
    }
    return pool[Random(currentStreak).nextInt(pool.length)];
  }
}

// ---------------------------------------------------------------------------
// _StreakCalendar — stub (implemented in Task 3)
// ---------------------------------------------------------------------------

class _StreakCalendar extends StatefulWidget {
  const _StreakCalendar({
    required this.weeklyDays,
    required this.userCreatedAt,
  });

  final Map<DateTime, bool> weeklyDays;
  final DateTime userCreatedAt;

  @override
  State<_StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<_StreakCalendar> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 100);
  }
}

// ---------------------------------------------------------------------------
// _StatsSection — stub (implemented in Task 4)
// ---------------------------------------------------------------------------

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.longestStreak,
    required this.freezeCount,
    required this.freezeMax,
    required this.freezePrice,
    required this.userCoins,
    required this.isBuying,
    required this.onBuyFreeze,
  });

  final int longestStreak;
  final int freezeCount;
  final int freezeMax;
  final int freezePrice;
  final int userCoins;
  final bool isBuying;
  final VoidCallback onBuyFreeze;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 100);
  }
}
