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
// _StreakCalendar — weekly / monthly toggle calendar
// ---------------------------------------------------------------------------

const _kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _kWeekDayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

class _StreakCalendar extends ConsumerStatefulWidget {
  const _StreakCalendar({
    required this.userCreatedAt,
  });

  final DateTime userCreatedAt;

  @override
  ConsumerState<_StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends ConsumerState<_StreakCalendar> {
  bool _isMonthly = false;
  late int _displayYear;
  late int _displayMonth;

  @override
  void initState() {
    super.initState();
    final today = AppClock.today();
    _displayYear = today.year;
    _displayMonth = today.month;
  }

  // --- helpers --------------------------------------------------------------

  bool _canGoBack() {
    final created = widget.userCreatedAt;
    return _displayYear > created.year ||
        (_displayYear == created.year && _displayMonth > created.month);
  }

  bool _canGoForward() {
    final today = AppClock.today();
    return _displayYear < today.year ||
        (_displayYear == today.year && _displayMonth < today.month);
  }

  void _prevMonth() {
    if (!_canGoBack()) return;
    setState(() {
      _displayMonth--;
      if (_displayMonth < 1) {
        _displayMonth = 12;
        _displayYear--;
      }
    });
  }

  void _nextMonth() {
    if (!_canGoForward()) return;
    setState(() {
      _displayMonth++;
      if (_displayMonth > 12) {
        _displayMonth = 1;
        _displayYear++;
      }
    });
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState:
              _isMonthly ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _buildWeeklyView(),
          secondChild: _buildMonthlyView(),
        ),
        const SizedBox(height: 8),
        _buildToggleButton(),
      ],
    );
  }

  // --- weekly view ----------------------------------------------------------

  Widget _buildWeeklyView() {
    final today = AppClock.today();
    // Monday of current week
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    // Collect all months the week spans (e.g. week crosses month boundary)
    final monthKeys = <({int year, int month})>{};
    for (final d in days) {
      monthKeys.add((year: d.year, month: d.month));
    }
    // Merge login data from all spanned months
    final weekData = <DateTime, bool>{};
    for (final key in monthKeys) {
      final data = ref.watch(monthlyLoginDatesProvider(key)).valueOrNull ?? {};
      weekData.addAll(data);
    }

    final createdDate = DateTime(
      widget.userCreatedAt.year,
      widget.userCreatedAt.month,
      widget.userCreatedAt.day,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((date) {
        final dayLabel = _kWeekDayLabels[(date.weekday % 7)];
        return _DayCell(
          day: date.day,
          label: dayLabel,
          isToday: date.year == today.year && date.month == today.month && date.day == today.day,
          isLogin: _isLoginDay(weekData, date),
          isFreeze: _isFreezeDay(weekData, date),
          isFaded: date.isAfter(today) || date.isBefore(createdDate),
        );
      }).toList(),
    );
  }

  // --- monthly view ---------------------------------------------------------

  Widget _buildMonthlyView() {
    final monthData = ref
            .watch(
              monthlyLoginDatesProvider(
                (year: _displayYear, month: _displayMonth),
              ),
            )
            .valueOrNull ??
        {};
    final today = AppClock.today();
    final daysInMonth =
        DateTime(_displayYear, _displayMonth + 1, 0).day;
    // weekday of 1st: DateTime weekday is 1=Mon..7=Sun → convert to Sun=0
    final firstWeekday = DateTime(_displayYear, _displayMonth, 1).weekday % 7;
    final createdDate = DateTime(
      widget.userCreatedAt.year,
      widget.userCreatedAt.month,
      widget.userCreatedAt.day,
    );

    // Build grid cells
    final cells = <Widget>[];
    // Leading empty cells
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    // Day cells
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_displayYear, _displayMonth, d);
      final isFuture = date.isAfter(today);
      final isBeforeCreated = date.isBefore(createdDate);
      cells.add(
        _DayCell(
          day: d,
          isToday: date.year == today.year && date.month == today.month && date.day == today.day,
          isLogin: _isLoginDay(monthData, date),
          isFreeze: _isFreezeDay(monthData, date),
          isFaded: isFuture || isBeforeCreated,
          compact: true,
        ),
      );
    }
    // Pad last row to multiple of 7
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _canGoBack() ? _prevMonth : null,
              icon: Icon(
                Icons.chevron_left_rounded,
                color: _canGoBack() ? AppColors.gray700 : AppColors.gray300,
              ),
            ),
            Text(
              '${_kMonthNames[_displayMonth - 1].toUpperCase()} $_displayYear',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.gray700,
              ),
            ),
            IconButton(
              onPressed: _canGoForward() ? _nextMonth : null,
              icon: Icon(
                Icons.chevron_right_rounded,
                color:
                    _canGoForward() ? AppColors.gray700 : AppColors.gray300,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _kWeekDayLabels
              .map(
                (l) => SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(
                      l,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray400,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Grid rows
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: cells.sublist(row * 7, row * 7 + 7).map((cell) {
                return SizedBox(width: 36, height: 36, child: cell);
              }).toList(),
            ),
          ),
      ],
    );
  }

  // --- toggle button --------------------------------------------------------

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _isMonthly = !_isMonthly;
        if (_isMonthly) {
          final today = AppClock.today();
          _displayYear = today.year;
          _displayMonth = today.month;
        }
      }),
      child: Text(
        _isMonthly ? 'Show weekly \u25B2' : 'Show monthly \u25BC',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  // --- date lookup helpers --------------------------------------------------

  static bool _isLoginDay(Map<DateTime, bool> map, DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return map.containsKey(key) && !(map[key] ?? true);
  }

  static bool _isFreezeDay(Map<DateTime, bool> map, DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return map.containsKey(key) && (map[key] ?? false);
  }
}

// ---------------------------------------------------------------------------
// _DayCell — single day in the streak calendar
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.label,
    this.isToday = false,
    this.isLogin = false,
    this.isFreeze = false,
    this.isFaded = false,
    this.compact = false,
  });

  final int day;
  final String? label;
  final bool isToday;
  final bool isLogin;
  final bool isFreeze;
  final bool isFaded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 38.0;

    Widget dayContent;

    if (isLogin || (isToday && isLogin)) {
      // Login day (or today + logged in): orange circle with white checkmark
      dayContent = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.streakOrange,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      );
    } else if (isFreeze) {
      // Freeze day: blue circle with white snowflake
      dayContent = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.gemBlue,
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 16),
      );
    } else if (isToday) {
      // Today (not logged in): orange outline circle with day number
      dayContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.streakOrange, width: 2),
        ),
        child: Center(
          child: Text(
            '$day',
            style: GoogleFonts.nunito(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w800,
              color: AppColors.streakOrange,
            ),
          ),
        ),
      );
    } else if (isFaded) {
      // Before created_at or future: very faded
      dayContent = SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '$day',
            style: GoogleFonts.nunito(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.gray300,
            ),
          ),
        ),
      );
    } else {
      // Missed day (past, after created_at): plain grey
      dayContent = SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '$day',
            style: GoogleFonts.nunito(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gray400,
            ),
          ),
        ),
      );
    }

    // In weekly mode, show a label above and possibly a today marker below
    if (!compact && label != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.streakOrange : AppColors.gray400,
            ),
          ),
          const SizedBox(height: 4),
          dayContent,
          const SizedBox(height: 2),
          if (isToday)
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: AppColors.streakOrange,
            )
          else
            const SizedBox(height: 16),
        ],
      );
    }

    return dayContent;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stat cards row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.streakOrange,
                label: 'Longest',
                value: '$longestStreak days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.ac_unit_rounded,
                iconColor: AppColors.gemBlue,
                label: 'Freezes',
                value: '$freezeCount / $freezeMax',
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Buy Freeze button or max message
        if (freezeCount < freezeMax)
          OutlinedButton.icon(
            onPressed: (isBuying || userCoins < freezePrice) ? null : onBuyFreeze,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gemBlue,
              side: const BorderSide(color: AppColors.gemBlue),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: isBuying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gemBlue,
                    ),
                  )
                : const Icon(Icons.ac_unit_rounded),
            label: Text(
              'Buy Freeze — $freezePrice coins',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Center(
            child: Text(
              'Max freezes reached',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.gray500,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _StatCard — small info card used in _StatsSection
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
