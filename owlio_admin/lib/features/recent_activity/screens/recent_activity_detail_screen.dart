import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import 'recent_activity_screen.dart';

/// Generic detail page for any recent activity section.
/// Shows paginated list with the same row widgets used in the main screen.
class RecentActivityDetailScreen extends ConsumerStatefulWidget {
  const RecentActivityDetailScreen({super.key, required this.sectionKey});

  final String sectionKey;

  @override
  ConsumerState<RecentActivityDetailScreen> createState() =>
      _RecentActivityDetailScreenState();
}

class _RecentActivityDetailScreenState
    extends ConsumerState<RecentActivityDetailScreen> {
  static const _pageSize = 50;

  List<dynamic> _items = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  late final _SectionConfig _config;

  @override
  void initState() {
    super.initState();
    _config = _sectionConfigs[widget.sectionKey] ??
        _SectionConfig(
          title: 'Unknown',
          icon: Icons.help,
          color: Colors.grey,
          buildRow: (item) => ListTile(title: Text('$item')),
        );
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final offset = _page * _pageSize;
      final rows = await _queryForSection(supabase, offset);
      setState(() {
        if (_page == 0) {
          _items = rows;
        } else {
          _items = [..._items, ...rows];
        }
        _hasMore = rows.length == _pageSize;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _queryForSection(dynamic supabase, int offset) async {
    switch (widget.sectionKey) {
      case 'books':
        return await supabase
            .from(DbTables.books)
            .select('id, title, level, created_at')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'chapters':
        return await supabase
            .from(DbTables.chapters)
            .select('id, title, created_at, books(title)')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'words':
        return await supabase
            .from(DbTables.vocabularyWords)
            .select('id, word, meaning_tr, source, created_at')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'activities':
        return await supabase
            .from(DbTables.inlineActivities)
            .select('id, type, created_at, chapters(title)')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'assignments':
        return await supabase
            .from(DbTables.scopeLearningPaths)
            .select('id, created_at, learning_path_templates(name)')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'newUsers':
        return await supabase
            .from(DbTables.profiles)
            .select('id, first_name, last_name, role, created_at')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'activeUsers':
        return await supabase
            .from(DbTables.profiles)
            .select('id, first_name, last_name, last_activity_date')
            .not('last_activity_date', 'is', null)
            .order('last_activity_date', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'activityResults':
        return await supabase
            .from(DbTables.inlineActivityResults)
            .select(
                'id, is_correct, answered_at, profiles(first_name, last_name), inline_activities(type)')
            .order('answered_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'readingProgress':
        return await supabase
            .from(DbTables.readingProgress)
            .select(
                'id, updated_at, profiles(first_name, last_name), chapters(title)')
            .order('updated_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      case 'xpLogs':
        return await supabase
            .from(DbTables.xpLogs)
            .select(
                'id, amount, source, created_at, profiles(first_name, last_name)')
            .order('created_at', ascending: false)
            .range(offset, offset + _pageSize - 1);
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/recent-activity'),
        ),
        title: Row(
          children: [
            Icon(_config.icon, color: _config.color, size: 22),
            const SizedBox(width: 8),
            Text(_config.title),
          ],
        ),
      ),
      body: _error != null && _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Hata: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _page = 0;
                      _loadPage();
                    },
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Count bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Text(
                        '${_items.length} kayıt${_hasMore ? '+' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Sayfa ${_page + 1}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // List
                Expanded(
                  child: _items.isEmpty && _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? const Center(
                              child: Text('Henüz veri yok',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _items.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                if (index == _items.length) {
                                  // Load more button
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: _isLoading
                                          ? const CircularProgressIndicator()
                                          : OutlinedButton(
                                              onPressed: () {
                                                _page++;
                                                _loadPage();
                                              },
                                              child: const Text(
                                                  'Daha Fazla Yükle'),
                                            ),
                                    ),
                                  );
                                }
                                return _config.buildRow(_items[index]);
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

// ============================================
// SECTION CONFIGS
// ============================================

class _SectionConfig {
  const _SectionConfig({
    required this.title,
    required this.icon,
    required this.color,
    required this.buildRow,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget Function(dynamic item) buildRow;
}

/// Uses the same row widgets from recent_activity_screen.dart
/// Those are package-private (no underscore prefix needed since same package)
final _sectionConfigs = <String, _SectionConfig>{
  'books': _SectionConfig(
    title: 'Son Eklenen Kitaplar',
    icon: Icons.menu_book,
    color: const Color(0xFF4F46E5),
    buildRow: (item) => BookRow(item: item),
  ),
  'chapters': _SectionConfig(
    title: 'Son Eklenen Bölümler',
    icon: Icons.article,
    color: const Color(0xFF0EA5E9),
    buildRow: (item) => ChapterRow(item: item),
  ),
  'words': _SectionConfig(
    title: 'Son Eklenen Kelimeler',
    icon: Icons.abc,
    color: const Color(0xFF059669),
    buildRow: (item) => WordRow(item: item),
  ),
  'activities': _SectionConfig(
    title: 'Son Eklenen Aktiviteler',
    icon: Icons.quiz,
    color: const Color(0xFF7C3AED),
    buildRow: (item) => ActivityRow(item: item),
  ),
  'assignments': _SectionConfig(
    title: 'Son Ödevler',
    icon: Icons.route,
    color: const Color(0xFFEA580C),
    buildRow: (item) => AssignmentRow(item: item),
  ),
  'newUsers': _SectionConfig(
    title: 'Son Eklenen Kullanıcılar',
    icon: Icons.person_add,
    color: const Color(0xFF7C3AED),
    buildRow: (item) => NewUserRow(item: item),
  ),
  'activeUsers': _SectionConfig(
    title: 'Son Aktif Kullanıcılar',
    icon: Icons.people,
    color: const Color(0xFF0EA5E9),
    buildRow: (item) => ActiveUserRow(item: item),
  ),
  'activityResults': _SectionConfig(
    title: 'Son Tamamlanan Aktiviteler',
    icon: Icons.check_circle,
    color: const Color(0xFF059669),
    buildRow: (item) => ActivityResultRow(item: item),
  ),
  'readingProgress': _SectionConfig(
    title: 'Son Okuma İlerlemeleri',
    icon: Icons.auto_stories,
    color: const Color(0xFF4F46E5),
    buildRow: (item) => ReadingProgressRow(item: item),
  ),
  'xpLogs': _SectionConfig(
    title: 'Son XP Kazanımları',
    icon: Icons.bolt,
    color: const Color(0xFFF59E0B),
    buildRow: (item) => XpLogRow(item: item),
  ),
};
