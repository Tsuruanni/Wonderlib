import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase_client.dart';
import 'admin_nav_config.dart';
import 'admin_nav_list_item.dart';

/// Persistent left-hand navigation for the admin panel.
///
/// Width is fixed at 260px (admin is desktop-only). Renders nav entries from
/// [kAdminNavEntries], grouping them by their [AdminNavEntry.group] label.
/// Footer shows current user email + logout.
class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({
    super.key,
    required this.currentIndex,
    required this.onBranchSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onBranchSelected;

  static const double width = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAdminUserProvider);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const _Header(),
          Expanded(child: _NavList(currentIndex: currentIndex, onBranchSelected: onBranchSelected)),
          _Footer(
            email: userAsync.valueOrNull?.email,
            onLogout: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'O',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Owlio Admin',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.currentIndex, required this.onBranchSelected});

  final int currentIndex;
  final ValueChanged<int> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[const SizedBox(height: 8)];
    String? lastGroup;
    for (var i = 0; i < kAdminNavEntries.length; i++) {
      final entry = kAdminNavEntries[i];
      if (entry.group != lastGroup && entry.group != kStandaloneGroup) {
        children.add(const SizedBox(height: 16));
        children.add(_GroupHeader(label: entry.group));
        lastGroup = entry.group;
      } else if (entry.group == kStandaloneGroup && lastGroup != null) {
        // Standalone after groups — unusual; add spacing.
        children.add(const SizedBox(height: 8));
        lastGroup = null;
      }
      children.add(AdminNavListItem(
        icon: entry.icon,
        label: entry.label,
        isActive: i == currentIndex,
        onTap: () => onBranchSelected(i),
      ));
    }
    children.add(const SizedBox(height: 16));
    return SingleChildScrollView(child: Column(children: children));
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.email, required this.onLogout});
  final String? email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(
              (email?.substring(0, 1) ?? 'A').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email ?? 'Yönetici',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Çıkış Yap',
            onPressed: onLogout,
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }
}
