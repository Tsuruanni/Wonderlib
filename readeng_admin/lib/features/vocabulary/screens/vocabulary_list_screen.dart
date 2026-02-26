import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readeng_shared/readeng_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

/// Provider for search query
final vocabularySearchProvider = StateProvider<String>((ref) => '');

/// Provider for level filter
final vocabularyLevelFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for current page
final vocabularyPageProvider = StateProvider<int>((ref) => 0);

/// Provider for loading vocabulary with pagination
final vocabularyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final search = ref.watch(vocabularySearchProvider);
  final levelFilter = ref.watch(vocabularyLevelFilterProvider);
  final page = ref.watch(vocabularyPageProvider);

  const pageSize = 50;
  final offset = page * pageSize;

  var query = supabase.from(DbTables.vocabularyWords).select();

  if (search.isNotEmpty) {
    query = query.ilike('word', '%$search%');
  }
  if (levelFilter != null) {
    query = query.eq('level', levelFilter);
  }

  final response = await query
      .order('word')
      .range(offset, offset + pageSize - 1);

  // Get total count efficiently
  var countQuery = supabase.from(DbTables.vocabularyWords).select();
  if (search.isNotEmpty) {
    countQuery = countQuery.ilike('word', '%$search%');
  }
  if (levelFilter != null) {
    countQuery = countQuery.eq('level', levelFilter);
  }
  final countResult = await countQuery.count(CountOption.exact);
  final totalCount = countResult.count;

  return {
    'data': List<Map<String, dynamic>>.from(response),
    'total': totalCount,
    'page': page,
    'pageSize': pageSize,
  };
});

class VocabularyListScreen extends ConsumerStatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  ConsumerState<VocabularyListScreen> createState() => _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabAsync = ref.watch(vocabularyProvider);
    final currentPage = ref.watch(vocabularyPageProvider);
    final levelFilter = ref.watch(vocabularyLevelFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/vocabulary/import'),
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Import CSV'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.go('/vocabulary/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Word'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                // Search
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search words...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(vocabularySearchProvider.notifier).state = '';
                                ref.read(vocabularyPageProvider.notifier).state = 0;
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      ref.read(vocabularySearchProvider.notifier).state = value;
                      ref.read(vocabularyPageProvider.notifier).state = 0;
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Level filter
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    value: levelFilter,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Levels')),
                      ...CEFRLevel.allValues.map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          )),
                    ],
                    onChanged: (value) {
                      ref.read(vocabularyLevelFilterProvider.notifier).state = value;
                      ref.read(vocabularyPageProvider.notifier).state = 0;
                    },
                  ),
                ),
              ],
            ),
          ),

          // Vocabulary list
          Expanded(
            child: vocabAsync.when(
              data: (result) {
                final words = result['data'] as List<Map<String, dynamic>>;
                final total = result['total'] as int;
                final pageSize = result['pageSize'] as int;
                final totalPages = (total / pageSize).ceil();

                if (words.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.abc,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No words found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/vocabulary/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add your first word'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Results info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${words.length} of $total words',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Page ${currentPage + 1} of $totalPages',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),

                    // Table
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(3),
                            3: FlexColumnWidth(1),
                            4: FixedColumnWidth(50),
                          },
                          border: TableBorder.all(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          children: [
                            // Header
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Word',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Type',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Meaning (TR)',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Level',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(),
                              ],
                            ),
                            // Data rows
                            ...words.map((word) => TableRow(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/vocabulary/${word['id']}'),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          word['word'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        word['part_of_speech'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        word['meaning_tr'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: _LevelBadge(level: word['level'] ?? 'B1'),
                                    ),
                                    InkWell(
                                      onTap: () => context.go('/vocabulary/${word['id']}'),
                                      child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ),

                    // Pagination
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: currentPage > 0
                                ? () {
                                    ref.read(vocabularyPageProvider.notifier).state =
                                        currentPage - 1;
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 16),
                          Text('Page ${currentPage + 1} of $totalPages'),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: currentPage < totalPages - 1
                                ? () {
                                    ref.read(vocabularyPageProvider.notifier).state =
                                        currentPage + 1;
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(vocabularyProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 12,
          color: _getColor(),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (level) {
      case 'A1':
        return Colors.green;
      case 'A2':
        return Colors.lightGreen;
      case 'B1':
        return Colors.orange;
      case 'B2':
        return Colors.deepOrange;
      case 'C1':
        return Colors.red;
      case 'C2':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
