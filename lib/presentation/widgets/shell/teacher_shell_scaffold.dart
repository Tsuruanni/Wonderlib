import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../reader/grammar_profile_widget.dart';
import '../reader/reader_sidebar.dart';

/// Teacher shell scaffold that provides persistent navigation.
/// Mobile: bottom navigation bar.
/// Tablet/Desktop: custom playful sidebar.
class TeacherShellScaffold extends StatelessWidget {
  const TeacherShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_NavItem>[
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      color: AppColors.primary,
    ),
    _NavItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Classes',
      color: AppColors.secondary,
    ),
    _NavItem(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Assignments',
      color: AppColors.wasp,
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Reports',
      color: Color(0xFF9B59B6),
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: 'Library',
      color: AppColors.primaryDark,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;
    final location = GoRouterState.of(context).uri.path;
    final isReaderRoute = location.startsWith('/teacher/reader') ||
        location.startsWith('/teacher/quiz');
    final showReaderSidebar = isReaderRoute && screenWidth >= 1000;
    final showGrammarProfile = isReaderRoute && screenWidth >= 1400;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            // Custom playful sidebar
            Container(
              width: 100,
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  right: BorderSide(color: AppColors.neutral, width: 2),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Logo / brand
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryDark,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.primaryDark,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'O',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nav items
                    for (int i = 0; i < _destinations.length; i++) ...[
                      _SidebarItem(
                        item: _destinations[i],
                        isSelected: navigationShell.currentIndex == i,
                        onTap: () => _onTap(context, i),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Spacer(),

                    // Profile button at bottom
                    _SidebarItem(
                      item: const _NavItem(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Profile',
                        color: AppColors.neutralDark,
                      ),
                      isSelected: false,
                      onTap: () => context.push(AppRoutes.teacherProfile),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (showReaderSidebar) const ReaderSidebar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(navigationShell.currentIndex),
                  child: navigationShell,
                ),
              ),
            ),
            if (showGrammarProfile) const GrammarProfileWidget(),
          ],
        ),
      );
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(navigationShell.currentIndex),
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: [
          for (final dest in _destinations)
            NavigationDestination(
              icon: Icon(dest.icon),
              selectedIcon: Icon(dest.selectedIcon),
              label: dest.label,
            ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: item.label,
        preferBelow: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 72,
          height: 52,
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? item.color.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? item.color : AppColors.neutralDark,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? item.color : AppColors.neutralText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
