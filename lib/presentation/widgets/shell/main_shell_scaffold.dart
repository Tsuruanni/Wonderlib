import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../screens/cards/card_collection_screen.dart';
import '../../screens/library/library_screen.dart';
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
      label: 'LEARNING PATH',
      color: AppColors.wasp,
    ),
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'HOME',
      color: AppColors.primary,
    ),
    _NavItem(
      icon: Icons.local_library_outlined,
      selectedIcon: Icons.local_library_rounded,
      label: 'LIBRARY',
      color: AppColors.secondary,
    ),
    _NavItem(
      icon: Icons.collections_bookmark_outlined,
      selectedIcon: Icons.collections_bookmark_rounded,
      label: 'CARD COLLECTION',
      color: AppColors.cardEpic,
    ),
    _NavItem(
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded,
      label: 'LEADERBOARDS',
      color: AppColors.streakOrange,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;
    final showRightPanel = screenWidth >= 1000;

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
                        label: 'PROFILE',
                        color: AppColors.neutralDark,
                      ),
                      isSelected: false,
                      onTap: () => context.go(AppRoutes.profile),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Content + right panel
            Expanded(
              child: Builder(
                builder: (context) {
                  final location = GoRouterState.of(context).uri.path;
                  final isFullWidth = location.startsWith(AppRoutes.vocabulary);

                  if (isFullWidth) {
                    // Full-width screens (e.g. Learning Path with terrain bg)
                    return Row(
                      children: [
                        Expanded(child: navigationShell),
                        if (showRightPanel) const RightInfoPanel(),
                      ],
                    );
                  }

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: showRightPanel ? 1060 : 800,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: navigationShell),
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
                    style: GoogleFonts.boogaloo(
                      fontSize: 15,
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
