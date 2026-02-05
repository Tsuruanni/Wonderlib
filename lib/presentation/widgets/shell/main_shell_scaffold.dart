import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';

/// Main shell scaffold that provides persistent bottom navigation
/// for the app's main sections: Home, Library, Vocabulary
class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.neutral, width: 2),
          ),
        ),
        child: SafeArea( // Handle iPhone bottom safe area
          child: SizedBox(
            height: 80, // Taller bar
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavButton(
                  icon: Icons.home_rounded,
                  label: 'HOME', // Labels are semantic/accessibility primarily here or subtle
                  isSelected: navigationShell.currentIndex == 0,
                  onTap: () => _onTap(context, 0),
                  color: AppColors.primary,
                ),
                _NavButton(
                  icon: Icons.local_library_rounded,
                  label: 'LIBRARY',
                  isSelected: navigationShell.currentIndex == 1,
                  onTap: () => _onTap(context, 1),
                  color: AppColors.secondary, // Different color for varying sections? Or uniform? Let's use uniform for now via argument or defaults
                ),
                _NavButton(
                  icon: Icons.sort_by_alpha_rounded,
                  label: 'VOCAB',
                  isSelected: navigationShell.currentIndex == 2,
                  onTap: () => _onTap(context, 2),
                  color: AppColors.wasp,
                ),
                _NavButton(
                  icon: Icons.person_rounded,
                  label: 'PROFILE',
                  isSelected: navigationShell.currentIndex == 3,
                  onTap: () => _onTap(context, 3),
                  color: AppColors.neutral,
                ),
              ],
            ),
          ),
        ),
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isVisible;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color = AppColors.primary,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    // When selected: Icon is colored, has a subtle border?
    // Duolingo style: Just icon, colored when active, grey when inactive.
    // Sometimes has a border box.

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
                color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected 
                  ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? color : AppColors.neutralDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
