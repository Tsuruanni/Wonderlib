# Streak Sheet Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the basic streak status dialog with a Duolingo-inspired full-screen bottom sheet featuring gradient banner, toggleable weekly/monthly calendar, and compact stat cards.

**Architecture:** Single new widget file (`streak_sheet.dart`) replaces `streak_status_dialog.dart`. One new family provider (`monthlyLoginDatesProvider`) added to `user_provider.dart`. Two call sites updated (`top_navbar.dart`, `right_info_panel.dart`). No database or RPC changes.

**Tech Stack:** Flutter, Riverpod (FutureProvider.family), google_fonts, existing AppColors/theme

**Spec:** `docs/superpowers/specs/2026-03-31-streak-sheet-redesign.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/presentation/widgets/common/streak_sheet.dart` | CREATE | Full bottom sheet: `StreakSheet` (public), `_StreakBanner`, `_StreakCalendar`, `_StatsSection` |
| `lib/presentation/widgets/common/streak_status_dialog.dart` | DELETE | Replaced by streak_sheet.dart |
| `lib/presentation/providers/user_provider.dart` | MODIFY | Add `monthlyLoginDatesProvider` family provider |
| `lib/presentation/widgets/common/top_navbar.dart` | MODIFY | `showDialog` → `showModalBottomSheet`, add `userCreatedAt` param |
| `lib/presentation/widgets/shell/right_info_panel.dart` | MODIFY | Same change as top_navbar |

---

### Task 1: Add `monthlyLoginDatesProvider` to user_provider.dart

**Files:**
- Modify: `lib/presentation/providers/user_provider.dart:108` (after existing `loginDatesProvider`)

- [ ] **Step 1: Add the family provider**

Add after the closing of `loginDatesProvider` (after line 108):

```dart
/// Monthly login/freeze dates for streak calendar (from daily_logins table).
/// Keyed by (year, month) so each month is cached independently.
final monthlyLoginDatesProvider = FutureProvider.family<
    Map<DateTime, bool>,
    ({int year, int month})>((ref, params) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final from = DateTime(params.year, params.month, 1);
  final useCase = ref.watch(getLoginDatesUseCaseProvider);
  final result =
      await useCase(GetLoginDatesParams(userId: userId, from: from));
  return result.fold(
    (_) => <DateTime, bool>{},
    (dates) => dates,
  );
});
```

- [ ] **Step 2: Verify no compile errors**

Run: `dart analyze lib/presentation/providers/user_provider.dart`
Expected: No errors (warnings OK)

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/user_provider.dart
git commit -m "feat(provider): add monthlyLoginDatesProvider family for streak calendar"
```

---

### Task 2: Create `streak_sheet.dart` — Shell + Banner

**Files:**
- Create: `lib/presentation/widgets/common/streak_sheet.dart`

This task creates the file with the public `StreakSheet` widget, `showStreakSheet` helper, and `_StreakBanner`. Calendar and stats are stubbed as `SizedBox` placeholders to be filled in Tasks 3–4.

- [ ] **Step 1: Create the file with StreakSheet + _StreakBanner**

```dart
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
// _StreakCalendar — placeholder (Task 3)
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
    // Placeholder — implemented in Task 3
    return const SizedBox(height: 100);
  }
}

// ---------------------------------------------------------------------------
// _StatsSection — placeholder (Task 4)
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
    // Placeholder — implemented in Task 4
    return const SizedBox(height: 100);
  }
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `dart analyze lib/presentation/widgets/common/streak_sheet.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/streak_sheet.dart
git commit -m "feat(ui): create streak_sheet.dart with banner and shell structure"
```

---

### Task 3: Implement `_StreakCalendar` — Weekly + Monthly Toggle

**Files:**
- Modify: `lib/presentation/widgets/common/streak_sheet.dart` (replace `_StreakCalendar` placeholder)

- [ ] **Step 1: Replace `_StreakCalendar` and `_StreakCalendarState` with full implementation**

Replace everything from `class _StreakCalendar extends StatefulWidget` through the end of `_StreakCalendarState` with:

```dart
class _StreakCalendar extends ConsumerStatefulWidget {
  const _StreakCalendar({
    required this.weeklyDays,
    required this.userCreatedAt,
  });

  final Map<DateTime, bool> weeklyDays;
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

  // Navigation bounds
  bool get _canGoBack {
    final created = widget.userCreatedAt;
    return _displayYear > created.year ||
        (_displayYear == created.year && _displayMonth > created.month);
  }

  bool get _canGoForward {
    final today = AppClock.today();
    return _displayYear < today.year ||
        (_displayYear == today.year && _displayMonth < today.month);
  }

  void _goBack() {
    if (!_canGoBack) return;
    setState(() {
      _displayMonth--;
      if (_displayMonth < 1) {
        _displayMonth = 12;
        _displayYear--;
      }
    });
  }

  void _goForward() {
    if (!_canGoForward) return;
    setState(() {
      _displayMonth++;
      if (_displayMonth > 12) {
        _displayMonth = 1;
        _displayYear++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedCrossFade(
          firstChild: _buildWeekly(),
          secondChild: _buildMonthly(),
          crossFadeState:
              _isMonthly ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _isMonthly = !_isMonthly),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isMonthly ? 'Show weekly' : 'Show monthly',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gemBlue,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isMonthly
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.gemBlue,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Weekly View ──

  Widget _buildWeekly() {
    final today = AppClock.today();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = days[i];
        final isToday = date == today;
        return Column(
          children: [
            Text(
              labels[i],
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isToday ? AppColors.streakOrange : AppColors.gray500,
              ),
            ),
            const SizedBox(height: 2),
            if (isToday)
              Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.streakOrange, size: 14)
            else
              const SizedBox(height: 14),
            _DayCell(
              date: date,
              loginData: widget.weeklyDays,
              userCreatedAt: widget.userCreatedAt,
              size: 36,
            ),
          ],
        );
      }),
    );
  }

  // ── Monthly View ──

  Widget _buildMonthly() {
    final monthlyAsync = ref.watch(
      monthlyLoginDatesProvider((year: _displayYear, month: _displayMonth)),
    );
    final monthlyDays = monthlyAsync.valueOrNull ?? {};

    final monthName = _monthNames[_displayMonth - 1];

    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _canGoBack ? _goBack : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.gray600,
              disabledColor: AppColors.gray300,
              iconSize: 28,
            ),
            Text(
              '$monthName $_displayYear'.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.gray700,
                letterSpacing: 1,
              ),
            ),
            IconButton(
              onPressed: _canGoForward ? _goForward : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: AppColors.gray600,
              disabledColor: AppColors.gray300,
              iconSize: 28,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Day-of-week header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        ..._buildMonthGrid(monthlyDays),
      ],
    );
  }

  List<Widget> _buildMonthGrid(Map<DateTime, bool> monthlyDays) {
    final firstDay = DateTime(_displayYear, _displayMonth, 1);
    final daysInMonth = DateTime(_displayYear, _displayMonth + 1, 0).day;
    // Sunday = 0 start (firstDay.weekday: Mon=1 .. Sun=7)
    final startWeekday = firstDay.weekday % 7; // Sun=0, Mon=1 ... Sat=6

    final cells = <Widget>[];

    // Leading empty cells
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox(width: 36, height: 36));
    }

    // Day cells
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayYear, _displayMonth, day);
      cells.add(
        _DayCell(
          date: date,
          loginData: monthlyDays,
          userCreatedAt: widget.userCreatedAt,
          size: 36,
        ),
      );
    }

    // Split into rows of 7
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final rowCells = cells.sublist(i, (i + 7).clamp(0, cells.length));
      // Pad last row
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox(width: 36, height: 36));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowCells,
          ),
        ),
      );
    }

    return rows;
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}

// ---------------------------------------------------------------------------
// _DayCell — individual day icon (login ✅ / freeze 🧊 / empty ⚪)
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.loginData,
    required this.userCreatedAt,
    required this.size,
  });

  final DateTime date;
  final Map<DateTime, bool> loginData;
  final DateTime userCreatedAt;
  final double size;

  @override
  Widget build(BuildContext context) {
    final today = AppClock.today();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final isToday = normalizedDate == today;
    final isFuture = normalizedDate.isAfter(today);
    final isBeforeCreated = normalizedDate.isBefore(
      DateTime(userCreatedAt.year, userCreatedAt.month, userCreatedAt.day),
    );

    final isFreeze = loginData[normalizedDate] == true;
    final isLogin = loginData[normalizedDate] == false;

    // Determine visual
    if (isLogin || (isToday && loginData.containsKey(normalizedDate))) {
      // Orange circle + white check
      return _circle(
        color: AppColors.streakOrange,
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      );
    }
    if (isFreeze) {
      // Blue circle + white snowflake
      return _circle(
        color: AppColors.gemBlue,
        child: const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 16),
      );
    }
    if (isToday) {
      // Orange outline circle with day number
      return _circle(
        color: Colors.transparent,
        border: AppColors.streakOrange,
        child: Text(
          '${date.day}',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.streakOrange,
          ),
        ),
      );
    }
    if (isFuture || isBeforeCreated) {
      // Very faded
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '${date.day}',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.gray300,
            ),
          ),
        ),
      );
    }
    // Missed day — plain grey number
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          '${date.day}',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.gray400,
          ),
        ),
      ),
    );
  }

  Widget _circle({
    required Color color,
    Color? border,
    required Widget child,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border != null ? Border.all(color: border, width: 2) : null,
      ),
      child: Center(child: child),
    );
  }
}
```

Also update the import to add `flutter_riverpod` for `ConsumerStatefulWidget` (already imported at top, so only need to change `StatefulWidget` → `ConsumerStatefulWidget` which is done above).

- [ ] **Step 2: Verify no compile errors**

Run: `dart analyze lib/presentation/widgets/common/streak_sheet.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/streak_sheet.dart
git commit -m "feat(ui): implement streak calendar with weekly/monthly toggle"
```

---

### Task 4: Implement `_StatsSection` — Stat Cards + Buy Freeze

**Files:**
- Modify: `lib/presentation/widgets/common/streak_sheet.dart` (replace `_StatsSection` placeholder)

- [ ] **Step 1: Replace `_StatsSection` build method with full implementation**

Replace the `_StatsSection` class entirely (keep all constructor fields, replace `build`):

```dart
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
        // Buy freeze button
        if (freezeCount < freezeMax)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBuying
                  ? null
                  : (userCoins >= freezePrice ? onBuyFreeze : null),
              icon: isBuying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ac_unit_rounded, size: 18),
              label: Text(
                isBuying ? 'Buying...' : 'Buy Freeze — $freezePrice coins',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gemBlue,
                side: BorderSide(color: AppColors.gemBlue.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else
          Text(
            'Max freezes reached',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.gray400,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _StatCard — compact stat display
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 14,
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
```

- [ ] **Step 2: Verify no compile errors**

Run: `dart analyze lib/presentation/widgets/common/streak_sheet.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/streak_sheet.dart
git commit -m "feat(ui): implement streak stats section with stat cards and buy freeze"
```

---

### Task 5: Update Call Sites + Delete Old Dialog

**Files:**
- Modify: `lib/presentation/widgets/common/top_navbar.dart`
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart`
- Delete: `lib/presentation/widgets/common/streak_status_dialog.dart`

- [ ] **Step 1: Update `top_navbar.dart`**

Change import (line 12):
```dart
// Old:
import 'streak_status_dialog.dart';
// New:
import 'streak_sheet.dart';
```

Replace the `showDialog` block (lines 62–73):
```dart
// Old:
                showDialog(
                  context: context,
                  builder: (context) => StreakStatusDialog(
                    currentStreak: user.currentStreak,
                    longestStreak: user.longestStreak,
                    calendarDays: calendarDays,
                    streakFreezeCount: user.streakFreezeCount,
                    streakFreezeMax: settings.streakFreezeMax,
                    streakFreezePrice: settings.streakFreezePrice,
                    userCoins: user.coins,
                  ),
                );
// New:
                showStreakSheet(context);
```

Since `showStreakSheet` reads all data from providers internally, the `calendarDaysAsync` variable, `settings`, and user fields are no longer needed at the call site for the streak tap. However, `settings` and `user` are still used for the coins display and other parts, so keep them. Remove only `calendarDaysAsync` (line 27) since it was only for pre-warming streak dialog data — the sheet reads providers internally.

Actually, keep the `calendarDaysAsync` line: `ref.watch(loginDatesProvider)`. It pre-warms the data so the sheet opens instantly. This is a good pattern. Just simplify the onTap:

```dart
          GestureDetector(
            onTap: () {
              if (user != null) showStreakSheet(context);
            },
```

- [ ] **Step 2: Update `right_info_panel.dart`**

Change import (line 19):
```dart
// Old:
import '../common/streak_status_dialog.dart';
// New:
import '../common/streak_sheet.dart';
```

Replace the `showDialog` block (lines 103–114):
```dart
// Old:
              showDialog(
                context: context,
                builder: (context) => StreakStatusDialog(
                  currentStreak: user.currentStreak,
                  longestStreak: user.longestStreak,
                  calendarDays: calendarDays,
                  streakFreezeCount: user.streakFreezeCount,
                  streakFreezeMax: settings.streakFreezeMax,
                  streakFreezePrice: settings.streakFreezePrice,
                  userCoins: user.coins,
                ),
              );
// New:
              showStreakSheet(context);
```

- [ ] **Step 3: Delete the old dialog file**

```bash
git rm lib/presentation/widgets/common/streak_status_dialog.dart
```

- [ ] **Step 4: Verify no compile errors**

Run: `dart analyze lib/`
Expected: No errors related to streak. Warnings OK.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/common/top_navbar.dart lib/presentation/widgets/shell/right_info_panel.dart
git commit -m "feat(ui): wire streak sheet to navbar and right panel, delete old dialog"
```

---

### Task 6: Visual Polish + Manual Test

**Files:**
- Modify: `lib/presentation/widgets/common/streak_sheet.dart` (if visual tweaks needed)

- [ ] **Step 1: Run the app and test streak sheet**

Run: `flutter run -d chrome`

Test checklist:
1. Tap fire icon in navbar → sheet opens from bottom (85% height)
2. Banner shows correct streak count + contextual message
3. Weekly calendar shows correct icons (✅ login, 🧊 freeze, ⚪ missed)
4. "Show monthly" toggles to monthly grid with smooth animation
5. Month navigation arrows work (< > ), left bound at account creation month
6. Right arrow disabled on current month
7. Stat cards show longest streak + freeze count
8. Buy Freeze button works (if coins sufficient) or disabled (if not)
9. On wide screen (≥1000px), fire icon in right panel also opens the sheet
10. Drag handle works — can drag sheet up/down

- [ ] **Step 2: Fix any visual issues found during testing**

Common things to adjust:
- Padding/spacing between sections
- Font sizes on different screen sizes
- Monthly grid alignment if cells don't line up
- DraggableScrollableSheet snap behavior

- [ ] **Step 3: Commit any fixes**

```bash
git add lib/presentation/widgets/common/streak_sheet.dart
git commit -m "fix(ui): streak sheet visual polish after manual testing"
```

---

### Task 7: Update Docs + Final Commit

**Files:**
- Modify: `docs/changelog.md`
- Modify: `docs/project_status.md`
- Modify: `docs/specs/10-streak-system.md` (Key Files section)

- [ ] **Step 1: Update changelog.md**

Add under `## [Unreleased]` at the top of the section:

```markdown
### Streak Sheet Redesign (2026-03-31)

#### Added
- **Full-screen bottom sheet** — Replaces small centered dialog. Opened via `showModalBottomSheet` with drag handle, scrollable content.
- **Gradient banner** — Orange gradient header with streak count + contextual messages (5 tiers of rotating messages, milestone proximity override).
- **Monthly calendar** — Full month grid with `< MONTH YEAR >` navigation. Login days (orange ✅), freeze days (blue 🧊), missed days (grey number). Navigable back to account creation month.
- **Weekly/monthly toggle** — Single calendar area, "Show monthly ▼" / "Show weekly ▲" with animated transition.
- **Compact stat cards** — Side-by-side Longest Streak and Freeze cards replacing plain text list.
- **`monthlyLoginDatesProvider`** — New `FutureProvider.family` keyed by `(year, month)` for monthly calendar data.

#### Changed
- **Day cell icons** — Distinct visuals per status: orange circle + checkmark (login), blue circle + snowflake (freeze), orange outline (today), grey number (missed). Replaces same-icon-different-color approach.

#### Removed
- **`streak_status_dialog.dart`** — Replaced entirely by `streak_sheet.dart`.
```

- [ ] **Step 2: Update project_status.md**

Add to roadmap (Faz 4+ section):
```markdown
- [x] Streak Sheet Redesign (Duolingo-style bottom sheet, gradient banner, weekly/monthly calendar toggle, stat cards)
```

Update "Son güncelleme" date line.

Add to "Recently Completed" table:
```markdown
| Streak Sheet Redesign | 2026-03-31 | Duolingo-inspired full-screen bottom sheet replacing streak dialog. Gradient banner, toggleable weekly/monthly calendar, distinct day icons, compact stat cards, monthly login provider. |
```

- [ ] **Step 3: Update streak spec Key Files section**

In `docs/specs/10-streak-system.md`, update the Presentation Layer key files:
```markdown
- `lib/presentation/widgets/common/streak_sheet.dart` — full-screen bottom sheet with banner, calendar (weekly/monthly), stats, freeze purchase
```
Remove the old `streak_status_dialog.dart` reference.

- [ ] **Step 4: Commit docs**

```bash
git add docs/changelog.md docs/project_status.md docs/specs/10-streak-system.md
git commit -m "docs: update changelog, status, and streak spec for sheet redesign"
```
