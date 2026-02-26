import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Gallery screen showing all admin panel screens for quick reference
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  static const _widgetbookUrl = 'http://localhost:8081';

  @override
  Widget build(BuildContext context) {
    final screens = [
      _ScreenItem(
        title: 'Dashboard',
        description: 'Main dashboard with quick actions',
        icon: Icons.dashboard,
        route: '/',
        color: const Color(0xFF4F46E5),
      ),
      _ScreenItem(
        title: 'Books',
        description: 'Book list and management',
        icon: Icons.menu_book,
        route: '/books',
        color: const Color(0xFF4F46E5),
      ),
      _ScreenItem(
        title: 'Book Edit',
        description: 'Create/Edit book details',
        icon: Icons.edit_note,
        route: '/books/new',
        color: const Color(0xFF4F46E5),
      ),
      _ScreenItem(
        title: 'Schools',
        description: 'School management',
        icon: Icons.school,
        route: '/schools',
        color: const Color(0xFFE11D48),
      ),
      _ScreenItem(
        title: 'School Edit',
        description: 'Create/Edit school',
        icon: Icons.edit,
        route: '/schools/new',
        color: const Color(0xFFE11D48),
      ),
      _ScreenItem(
        title: 'Users',
        description: 'User list and management',
        icon: Icons.people,
        route: '/users',
        color: const Color(0xFF7C3AED),
      ),
      _ScreenItem(
        title: 'User Import',
        description: 'Bulk import users from CSV',
        icon: Icons.upload_file,
        route: '/users/import',
        color: const Color(0xFF7C3AED),
      ),
      _ScreenItem(
        title: 'Classes',
        description: 'Class management',
        icon: Icons.class_,
        route: '/classes',
        color: const Color(0xFF0891B2),
      ),
      _ScreenItem(
        title: 'Class Edit',
        description: 'Create/Edit class',
        icon: Icons.edit,
        route: '/classes/new',
        color: const Color(0xFF0891B2),
      ),
      _ScreenItem(
        title: 'Badges',
        description: 'Achievement badges',
        icon: Icons.emoji_events,
        route: '/badges',
        color: const Color(0xFFF59E0B),
      ),
      _ScreenItem(
        title: 'Badge Edit',
        description: 'Create/Edit badge',
        icon: Icons.edit,
        route: '/badges/new',
        color: const Color(0xFFF59E0B),
      ),
      _ScreenItem(
        title: 'Vocabulary',
        description: 'Word dictionary',
        icon: Icons.abc,
        route: '/vocabulary',
        color: const Color(0xFF059669),
      ),
      _ScreenItem(
        title: 'Vocabulary Import',
        description: 'Bulk import words',
        icon: Icons.upload_file,
        route: '/vocabulary/import',
        color: const Color(0xFF059669),
      ),
      _ScreenItem(
        title: 'Vocabulary Edit',
        description: 'Create/Edit word',
        icon: Icons.edit,
        route: '/vocabulary/new',
        color: const Color(0xFF059669),
      ),
      _ScreenItem(
        title: 'Word Lists',
        description: 'Word collections',
        icon: Icons.list_alt,
        route: '/wordlists',
        color: const Color(0xFF0D9488),
      ),
      _ScreenItem(
        title: 'Word List Edit',
        description: 'Create/Edit word list',
        icon: Icons.edit,
        route: '/wordlists/new',
        color: const Color(0xFF0D9488),
      ),
      _ScreenItem(
        title: 'Settings',
        description: 'App configuration',
        icon: Icons.settings,
        route: '/settings',
        color: const Color(0xFF6B7280),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Widgetbook Card - Special external link
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            color: const Color(0xFF1E1E2E),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBA6F7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.widgets,
                          color: Color(0xFFCBA6F7),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Widget Catalog',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Owlio mobile app UI components',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openWidgetbook(context),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Widgetbook'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBA6F7),
                            side: const BorderSide(color: Color(0xFFCBA6F7)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Run: widgetbook/serve.command',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Admin Panel Screens',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
            ),
          ),

          // Screen list
          ...screens.map((screen) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: screen.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(screen.icon, color: screen.color),
                  ),
                  title: Text(
                    screen.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(screen.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(screen.route),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _openWidgetbook(BuildContext context) async {
    final uri = Uri.parse(_widgetbookUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Widgetbook not running. Double-click widgetbook/serve.command to start.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _ScreenItem {
  const _ScreenItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
  final Color color;
}
