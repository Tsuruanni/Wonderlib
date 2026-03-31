import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/book_quiz_provider.dart';
import '../../screens/cards/card_collection_screen.dart';
import '../../screens/library/library_screen.dart';
import '../common/game_button.dart';
import '../reader/reader_sidebar.dart';
import 'right_info_panel.dart';

/// Main shell scaffold that provides persistent navigation.
/// Mobile: bottom navigation bar.
/// Tablet/Desktop (≥600px): Duolingo-style sidebar with icon + label.
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_NavItem>[
    _NavItem(
      icon: Icons.route_outlined,
      selectedIcon: Icons.route_rounded,
      label: 'Learning Path',
      color: AppColors.wasp,
    ),
    _NavItem(
      icon: Icons.local_library_outlined,
      selectedIcon: Icons.local_library_rounded,
      label: 'Library',
      color: AppColors.secondary,
    ),
    _NavItem(
      icon: Icons.military_tech_outlined,
      selectedIcon: Icons.military_tech_rounded,
      label: 'Quests',
      color: AppColors.streakOrange,
    ),
    _NavItem(
      icon: Icons.collections_bookmark_outlined,
      selectedIcon: Icons.collections_bookmark_rounded,
      label: 'Card Collection',
      color: AppColors.cardEpic,
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded,
      label: 'Leaderboards',
      color: AppColors.streakOrange,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // Duolingo-style sidebar
            Container(
              width: 250,
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  right: BorderSide(color: AppColors.neutral, width: 2),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Logo / brand
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'OWLIO',
                        style: GoogleFonts.boogaloo(
                          fontSize: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nav items
                    for (int i = 0; i < _destinations.length; i++)
                      _SidebarItem(
                        item: _destinations[i],
                        isSelected: navigationShell.currentIndex == i,
                        onTap: () => _onTap(context, ref, i),
                      ),

                    const Spacer(),

                    // Profile button at bottom
                    _SidebarItem(
                      item: const _NavItem(
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        color: AppColors.neutralDark,
                      ),
                      isSelected: false,
                      onTap: () {
                        final isQuizActive = ref.read(quizActiveProvider);
                        if (isQuizActive) {
                          _showQuizExitConfirmation(context, ref, () => context.go(AppRoutes.profile));
                          return;
                        }
                        context.go(AppRoutes.profile);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Content + optional reader sidebar + optional right panel
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final location = GoRouterState.of(context).uri.path;
                  final isFullWidth = location.startsWith(AppRoutes.vocabulary);
                  final isReader = location.startsWith('/reader') ||
                      location.startsWith('/quiz');
                  final showReaderSidebar = isReader && screenWidth >= 1000;
                  // Reader: right panel only at ≥1400px. Others: at ≥1000px.
                  final showRightPanel = isReader
                      ? screenWidth >= 1400
                      : screenWidth >= 1000;

                  final shell = ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: navigationShell,
                  );

                  if (showReaderSidebar) {
                    // Reader with sidebar — full width
                    return Row(
                      children: [
                        const ReaderSidebar(),
                        Expanded(child: shell),
                        if (showRightPanel) const RightInfoPanel(),
                      ],
                    );
                  }

                  final maxW = showRightPanel ? 1060.0 : 800.0;

                  if (isFullWidth) {
                    // Vocabulary: map fills from left edge, right panel
                    // stays at same absolute position as centered pages.
                    final available = constraints.maxWidth;
                    final sideGap = ((available - maxW) / 2).clamp(0.0, available);
                    return Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.neutral,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: shell,
                            ),
                          ),
                        ),
                        if (showRightPanel) const RightInfoPanel(),
                        SizedBox(width: sideGap),
                      ],
                    );
                  }

                  // Other pages: constrained center layout
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: Row(
                        children: [
                          Expanded(child: shell),
                          if (showRightPanel) const RightInfoPanel(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: bottom navigation bar (unchanged)
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              top: BorderSide(color: AppColors.neutral, width: 2),
            ),
          ),
          child: SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < _destinations.length; i++)
                  _BottomNavButton(
                    item: _destinations[i],
                    isSelected: navigationShell.currentIndex == i,
                    onTap: () => _onTap(context, ref, i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    // Block navigation if quiz is active
    final isQuizActive = ref.read(quizActiveProvider);
    if (isQuizActive) {
      _showQuizExitConfirmation(context, ref, () => _navigateToTab(context, ref, index));
      return;
    }

    _navigateToTab(context, ref, index);
  }

  void _navigateToTab(BuildContext context, WidgetRef ref, int index) {
    // Reset expanded states when navigating away
    if (index != navigationShell.currentIndex) {
      ref.read(expandedLevelsProvider.notifier).state = {};
      ref.read(expandedCardCategoriesProvider.notifier).state = {};
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _showQuizExitConfirmation(BuildContext context, WidgetRef ref, VoidCallback onLeave) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: AppColors.danger, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Leave Quiz?',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress will be lost.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: AppColors.neutralText,
                ),
              ),
              const SizedBox(height: 24),
              GameButton(
                label: 'Keep going',
                onPressed: () => Navigator.of(ctx).pop(),
                variant: GameButtonVariant.primary,
                fullWidth: true,
              ),
              const SizedBox(height: 8),
              GameButton(
                label: 'Leave',
                onPressed: () {
                  ref.read(quizActiveProvider.notifier).state = false;
                  Navigator.of(ctx).pop();
                  onLeave();
                },
                variant: GameButtonVariant.danger,
                fullWidth: true,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Item (Duolingo-style: icon + label in a Row, with hover) ───

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? item.color.withValues(alpha: 0.12)
                  : _isHovered
                      ? AppColors.neutral.withValues(alpha: 0.4)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? item.color.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: item.color,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? item.color : AppColors.neutralText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Nav Button (mobile, unchanged) ───

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? item.color.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                        color: item.color.withValues(alpha: 0.5), width: 2,)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 32,
                color: item.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav Item Data ───

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;
}
