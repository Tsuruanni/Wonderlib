import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

// ============================================
// PROVIDER
// ============================================

final recentActivityProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc();
  final todayStart =
      DateTime.utc(now.year, now.month, now.day).toIso8601String();
  final weekAgo = now.subtract(const Duration(days: 7)).toIso8601String();

  final results = await Future.wait([
    // 0: summary - today's active users
    supabase
        .from(DbTables.xpLogs)
        .select('user_id')
        .gte('created_at', todayStart)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 1: summary - week's total XP
    supabase
        .from(DbTables.xpLogs)
        .select('amount')
        .gte('created_at', weekAgo)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 2: Son Eklenen Kitaplar
    supabase
        .from(DbTables.books)
        .select('id, title, level, created_at')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 3: Son Eklenen Bölümler
    supabase
        .from(DbTables.chapters)
        .select('id, title, created_at, books(title)')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 4: Son Eklenen Kelimeler
    supabase
        .from(DbTables.vocabularyWords)
        .select('id, word, meaning_tr, source, created_at')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 5: Son Eklenen Aktiviteler
    supabase
        .from(DbTables.inlineActivities)
        .select('id, type, created_at, chapters(title)')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 6: Son Ödevler
    supabase
        .from(DbTables.scopeLearningPaths)
        .select('id, created_at, learning_path_templates(name)')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 7: Son Eklenen Kullanıcılar
    supabase
        .from(DbTables.profiles)
        .select('id, first_name, last_name, role, created_at')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 8: Son Aktif Kullanıcılar
    supabase
        .from(DbTables.profiles)
        .select('id, first_name, last_name, last_activity_date')
        .not('last_activity_date', 'is', null)
        .order('last_activity_date', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 9: Son Tamamlanan Aktiviteler
    supabase
        .from(DbTables.inlineActivityResults)
        .select(
            'id, is_correct, answered_at, profiles(first_name, last_name), inline_activities(type)')
        .order('answered_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 10: Son Okuma İlerlemeleri
    supabase
        .from(DbTables.readingProgress)
        .select('id, updated_at, profiles(first_name, last_name), chapters(title)')
        .order('updated_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
    // 11: Son XP Kazanımları
    supabase
        .from(DbTables.xpLogs)
        .select('id, amount, source, created_at, profiles(first_name, last_name)')
        .order('created_at', ascending: false)
        .limit(10)
        .then<List<dynamic>>((v) => v, onError: (e) { debugPrint('RECENT_ACTIVITY_ERROR: $e'); return <dynamic>[]; }),
  ]);

  // Process summaries
  final todayUsers =
      results[0].map((r) => r['user_id']).toSet().length;
  final weeklyXp = results[1]
      .fold<int>(0, (sum, r) => sum + (r['amount'] as int? ?? 0));

  return {
    'todayUsers': todayUsers,
    'weeklyXp': weeklyXp,
    'books': results[2],
    'chapters': results[3],
    'words': results[4],
    'activities': results[5],
    'assignments': results[6],
    'newUsers': results[7],
    'activeUsers': results[8],
    'activityResults': results[9],
    'readingProgress': results[10],
    'xpLogs': results[11],
  };
});

// ============================================
// SCREEN
// ============================================

class RecentActivityScreen extends ConsumerWidget {
  const RecentActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Son Etkinlikler'),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Hata: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(recentActivityProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (data) => _buildBody(context, ref, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef _, Map<String, dynamic> data) {
    final todayUsers = data['todayUsers'] as int? ?? 0;
    final weeklyXp = data['weeklyXp'] as int? ?? 0;
    final books = data['books'] as List? ?? [];
    final chapters = data['chapters'] as List? ?? [];
    final words = data['words'] as List? ?? [];
    final activities = data['activities'] as List? ?? [];
    final assignments = data['assignments'] as List? ?? [];
    final newUsers = data['newUsers'] as List? ?? [];
    final activeUsers = data['activeUsers'] as List? ?? [];
    final activityResults = data['activityResults'] as List? ?? [];
    final readingProgress = data['readingProgress'] as List? ?? [];
    final xpLogs = data['xpLogs'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Summary Cards ----
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.people,
                  color: const Color(0xFF4F46E5),
                  value: todayUsers.toString(),
                  label: 'Bugün Aktif Kullanıcı',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.bolt,
                  color: const Color(0xFFF59E0B),
                  value: formatNumber(weeklyXp),
                  label: 'Bu Hafta Toplam XP',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ---- Two-Column Grid ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column — Content
              Expanded(
                child: Column(
                  children: [
                    _SectionCard(title: 'Son Eklenen Kitaplar', icon: Icons.menu_book, color: const Color(0xFF4F46E5), items: books, itemBuilder: (item) => BookRow(item: item), sectionKey: 'books'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Eklenen Bölümler', icon: Icons.article, color: const Color(0xFF0EA5E9), items: chapters, itemBuilder: (item) => ChapterRow(item: item), sectionKey: 'chapters'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Eklenen Kelimeler', icon: Icons.abc, color: const Color(0xFF059669), items: words, itemBuilder: (item) => WordRow(item: item), sectionKey: 'words'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Eklenen Aktiviteler', icon: Icons.quiz, color: const Color(0xFF7C3AED), items: activities, itemBuilder: (item) => ActivityRow(item: item), sectionKey: 'activities'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Ödevler', icon: Icons.route, color: const Color(0xFFEA580C), items: assignments, itemBuilder: (item) => AssignmentRow(item: item), sectionKey: 'assignments'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Column — Users & Progress
              Expanded(
                child: Column(
                  children: [
                    _SectionCard(title: 'Son Eklenen Kullanıcılar', icon: Icons.person_add, color: const Color(0xFF7C3AED), items: newUsers, itemBuilder: (item) => NewUserRow(item: item), sectionKey: 'newUsers'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Aktif Kullanıcılar', icon: Icons.people, color: const Color(0xFF0EA5E9), items: activeUsers, itemBuilder: (item) => ActiveUserRow(item: item), sectionKey: 'activeUsers'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Tamamlanan Aktiviteler', icon: Icons.check_circle, color: const Color(0xFF059669), items: activityResults, itemBuilder: (item) => ActivityResultRow(item: item), sectionKey: 'activityResults'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son Okuma İlerlemeleri', icon: Icons.auto_stories, color: const Color(0xFF4F46E5), items: readingProgress, itemBuilder: (item) => ReadingProgressRow(item: item), sectionKey: 'readingProgress'),
                    const SizedBox(height: 16),
                    _SectionCard(title: 'Son XP Kazanımları', icon: Icons.bolt, color: const Color(0xFFF59E0B), items: xpLogs, itemBuilder: (item) => XpLogRow(item: item), sectionKey: 'xpLogs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// SUMMARY CARD
// ============================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SECTION CARD
// ============================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.itemBuilder,
    this.sectionKey,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<dynamic> items;
  final Widget Function(dynamic item) itemBuilder;
  /// When provided, "Tümünü Gör" navigates to detail page with pagination.
  final String? sectionKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (sectionKey != null)
                  TextButton(
                    onPressed: () =>
                        context.go('/recent-activity/$sectionKey'),
                    child: const Text('Tümünü Gör'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Henüz veri yok',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) => itemBuilder(items[index]),
            ),
        ],
      ),
    );
  }
}

// ============================================
// ROW WIDGETS
// ============================================

class BookRow extends StatelessWidget {
  const BookRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        item['title'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          levelBadge(item['level']),
          const SizedBox(width: 8),
          Text(
            relativeDate(item['created_at']),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class ChapterRow extends StatelessWidget {
  const ChapterRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final bookTitle = item['books']?['title'] ?? '';
    return ListTile(
      dense: true,
      title: Text(
        item['title'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: bookTitle.isNotEmpty
          ? Text(bookTitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
          : null,
      trailing: Text(
        relativeDate(item['created_at']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

class WordRow extends StatelessWidget {
  const WordRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              item['word'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              item['meaning_tr'] ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sourceBadge(item['source']),
          const SizedBox(width: 8),
          Text(
            relativeDate(item['created_at']),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final chapterTitle = item['chapters']?['title'] ?? '';
    return ListTile(
      dense: true,
      title: Row(
        children: [
          activityTypeBadge(item['type']),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chapterTitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Text(
        relativeDate(item['created_at']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

class AssignmentRow extends StatelessWidget {
  const AssignmentRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final templateName =
        item['learning_path_templates']?['name'] ?? 'Bilinmeyen Şablon';
    return ListTile(
      dense: true,
      title: Text(
        templateName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      trailing: Text(
        relativeDate(item['created_at']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

class NewUserRow extends StatelessWidget {
  const NewUserRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        fullName(item),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          roleBadge(item['role']),
          const SizedBox(width: 8),
          Text(
            relativeDate(item['created_at']),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class ActiveUserRow extends StatelessWidget {
  const ActiveUserRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        fullName(item),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      trailing: Text(
        relativeDate(item['last_activity_date']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

class ActivityResultRow extends StatelessWidget {
  const ActivityResultRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final studentName = fullName(item['profiles']);
    final activityType = item['inline_activities']?['type'];
    final isCorrect = item['is_correct'] == true;
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              studentName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          activityTypeBadge(activityType),
          const SizedBox(width: 6),
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isCorrect ? Colors.green : Colors.red,
          ),
        ],
      ),
      trailing: Text(
        relativeDate(item['answered_at']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

class ReadingProgressRow extends StatelessWidget {
  const ReadingProgressRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final studentName = fullName(item['profiles']);
    final chapterTitle = item['chapters']?['title'] ?? '';
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              studentName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              chapterTitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Text(
        relativeDate(item['updated_at']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

class XpLogRow extends StatelessWidget {
  const XpLogRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final studentName = fullName(item['profiles']);
    final xpAmount = item['amount'] as int? ?? 0;
    final source = item['source'] ?? '';
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              studentName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$xpAmount XP',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              source.toString(),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Text(
        relativeDate(item['created_at']),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }
}

// ============================================
// HELPERS
// ============================================

String fullName(dynamic item) {
  if (item == null) return '';
  final first = item['first_name'] as String? ?? '';
  final last = item['last_name'] as String? ?? '';
  return '$first $last'.trim();
}

String relativeDate(String? dateStr) {
  if (dateStr == null) return '';
  final date = DateTime.tryParse(dateStr);
  if (date == null) return '';
  final diff = DateTime.now().toUtc().difference(date);
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
  if (diff.inDays < 1) return '${diff.inHours}sa önce';
  if (diff.inDays < 7) return '${diff.inDays}g önce';
  return '${date.day}.${date.month}.${date.year}';
}

String formatNumber(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

Widget levelBadge(String? level) {
  final color = switch (level) {
    'A1' => Colors.green,
    'A2' => Colors.teal,
    'B1' => Colors.blue,
    'B2' => Colors.indigo,
    'C1' => Colors.purple,
    'C2' => Colors.deepPurple,
    _ => Colors.grey,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      level ?? '?',
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget sourceBadge(String? source) {
  final isActivity = source == 'activity';
  final color = isActivity ? Colors.purple : Colors.blue;
  final label = isActivity ? 'AKTİVİTE' : 'CSV';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget activityTypeBadge(String? type) {
  final label = switch (type) {
    'true_false' => 'True/False',
    'word_translation' => 'Word Translation',
    'find_words' => 'Select Multiple',
    'matching' => 'Matching',
    _ => type ?? 'Unknown',
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.purple.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.purple,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget roleBadge(String? role) {
  final color = switch (role) {
    'admin' => Colors.red,
    'teacher' => Colors.blue,
    _ => Colors.green, // student
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      role ?? 'student',
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
