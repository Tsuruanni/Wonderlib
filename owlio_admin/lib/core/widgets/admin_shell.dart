import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_sidebar.dart';

/// Shell wrapper for all authenticated admin routes.
///
/// Receives a [StatefulNavigationShell] from go_router's
/// [StatefulShellRoute.indexedStack]. Renders the sidebar on the left and the
/// active branch's Navigator on the right.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            currentIndex: navigationShell.currentIndex,
            onBranchSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
