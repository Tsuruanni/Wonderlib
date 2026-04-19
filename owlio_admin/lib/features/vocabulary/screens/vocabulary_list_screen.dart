import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

// ============================================
// VOCABULARY PROVIDERS
// ============================================

/// Search query for vocabulary words
final vocabularySearchProvider = StateProvider<String>((ref) => '');

/// Current page for vocabulary pagination
final vocabularyPageProvider = StateProvider<int>((ref) => 0);

/// Audio filter: null = all, true = has audio, false = no audio
final vocabularyAudioFilterProvider = StateProvider<bool?>((ref) => null);

/// Image filter: null = all, true = has image, false = no image
final vocabularyImageFilterProvider = StateProvider<bool?>((ref) => null);

/// Vocabulary words with pagination, search, and content filters
final vocabularyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final search = ref.watch(vocabularySearchProvider);
  final audioFilter = ref.watch(vocabularyAudioFilterProvider);
  final imageFilter = ref.watch(vocabularyImageFilterProvider);
  final page = ref.watch(vocabularyPageProvider);

  const pageSize = 50;
  final offset = page * pageSize;

  var query = supabase.from(DbTables.vocabularyWords).select();
  var countQuery = supabase.from(DbTables.vocabularyWords).select();

  // Search
  if (search.isNotEmpty) {
    query = query.ilike('word', '%$search%');
    countQuery = countQuery.ilike('word', '%$search%');
  }

  // Audio filter
  if (audioFilter == true) {
    query = query.not('audio_url', 'is', null).neq('audio_url', '');
    countQuery =
        countQuery.not('audio_url', 'is', null).neq('audio_url', '');
  } else if (audioFilter == false) {
    query = query.or('audio_url.is.null,audio_url.eq.');
    countQuery = countQuery.or('audio_url.is.null,audio_url.eq.');
  }

  // Image filter
  if (imageFilter == true) {
    query = query.not('image_url', 'is', null).neq('image_url', '');
    countQuery =
        countQuery.not('image_url', 'is', null).neq('image_url', '');
  } else if (imageFilter == false) {
    query = query.or('image_url.is.null,image_url.eq.');
    countQuery = countQuery.or('image_url.is.null,image_url.eq.');
  }

  final response =
      await query.order('created_at', ascending: false).range(offset, offset + pageSize - 1);
  final countResult = await countQuery.count(CountOption.exact);

  return {
    'data': List<Map<String, dynamic>>.from(response),
    'total': countResult.count,
    'page': page,
    'pageSize': pageSize,
  };
});

// ============================================
// WORDLIST PROVIDERS
// ============================================

/// All word lists with word details for content analysis
final wordlistsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase
      .from(DbTables.wordLists)
      .select('id, name, description, '
          'word_list_items(order_index, '
          'vocabulary_words(word, audio_url, image_url, example_sentences, meaning_en, phonetic))')
      .eq('is_system', true)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// ============================================
// SCREEN
// ============================================

class VocabularyListScreen extends ConsumerStatefulWidget {
  const VocabularyListScreen({super.key, this.initialTab = 0});

  /// 0 = Kelimeler, 1 = Kelime Listeleri
  final int initialTab;

  @override
  ConsumerState<VocabularyListScreen> createState() =>
      _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Havuzu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: _buildActions(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Kelimeler'),
            Tab(text: 'Kelime Listeleri'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VocabularyTab(searchController: _searchController),
          const _WordlistTab(),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (_tabController.index == 0) {
      return [
        OutlinedButton.icon(
          onPressed: () => context.go('/vocabulary/import'),
          icon: const Icon(Icons.upload, size: 18),
          label: const Text('CSV İçe Aktar'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => context.go('/vocabulary/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Kelime'),
        ),
        const SizedBox(width: 16),
      ];
    } else {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/wordlists/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Kelime Listesi'),
        ),
        const SizedBox(width: 16),
      ];
    }
  }
}

// ============================================
// TAB 0: KELIMELER
// ============================================

class _VocabularyTab extends ConsumerWidget {
  const _VocabularyTab({required this.searchController});

  final TextEditingController searchController;

  void _resetPage(WidgetRef ref) {
    ref.read(vocabularyPageProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabularyProvider);
    final currentPage = ref.watch(vocabularyPageProvider);
    final audioFilter = ref.watch(vocabularyAudioFilterProvider);
    final imageFilter = ref.watch(vocabularyImageFilterProvider);

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border:
                Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Kelime ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              ref
                                  .read(
                                      vocabularySearchProvider.notifier)
                                  .state = '';
                              _resetPage(ref);
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (value) {
                    ref.read(vocabularySearchProvider.notifier).state =
                        value;
                    _resetPage(ref);
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Audio filter
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<bool?>(
                  value: audioFilter,
                  decoration: const InputDecoration(
                    labelText: 'Ses',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tümü')),
                    DropdownMenuItem(
                        value: true, child: Text('Ses Var')),
                    DropdownMenuItem(
                        value: false, child: Text('Ses Yok')),
                  ],
                  onChanged: (value) {
                    ref
                        .read(vocabularyAudioFilterProvider.notifier)
                        .state = value;
                    _resetPage(ref);
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Image filter
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<bool?>(
                  value: imageFilter,
                  decoration: const InputDecoration(
                    labelText: 'Görsel',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tümü')),
                    DropdownMenuItem(
                        value: true, child: Text('Görsel Var')),
                    DropdownMenuItem(
                        value: false, child: Text('Görsel Yok')),
                  ],
                  onChanged: (value) {
                    ref
                        .read(vocabularyImageFilterProvider.notifier)
                        .state = value;
                    _resetPage(ref);
                  },
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: vocabAsync.when(
            data: (result) {
              final words =
                  result['data'] as List<Map<String, dynamic>>;
              final total = result['total'] as int;
              final pageSize = result['pageSize'] as int;
              final totalPages =
                  total == 0 ? 1 : (total / pageSize).ceil();

              if (words.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.abc,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Kelime bulunamadı',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            context.go('/vocabulary/new'),
                        icon: const Icon(Icons.add),
                        label:
                            const Text('İlk kelimenizi ekleyin'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Results info
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$total kelimeden ${words.length} tanesi',
                          style: TextStyle(
                              color: Colors.grey.shade600),
                        ),
                        Text(
                          'Sayfa ${currentPage + 1} / $totalPages',
                          style: TextStyle(
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Table
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.3), // Kelime
                          1: FlexColumnWidth(0.8), // Fonetik
                          2: FlexColumnWidth(1.5), // Anlam TR
                          3: FlexColumnWidth(1.5), // Anlam EN
                          4: FlexColumnWidth(2),   // Örnek Cümle
                          5: FixedColumnWidth(40),  // Ses
                          6: FixedColumnWidth(40),  // Görsel
                          7: FixedColumnWidth(36),  // >
                        },
                        border: TableBorder.all(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius:
                                  const BorderRadius.vertical(
                                      top: Radius.circular(8)),
                            ),
                            children: const [
                              _HeaderCell('Kelime'),
                              _HeaderCell('Fonetik'),
                              _HeaderCell('Anlam (TR)'),
                              _HeaderCell('Anlam (EN)'),
                              _HeaderCell('Örnek Cümle'),
                              _HeaderIconCell(Icons.volume_up),
                              _HeaderIconCell(Icons.image),
                              SizedBox(),
                            ],
                          ),
                          ...words.map((w) =>
                              _buildRow(context, w)),
                        ],
                      ),
                    ),
                  ),

                  // Pagination
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: currentPage > 0
                              ? () => ref
                                  .read(vocabularyPageProvider
                                      .notifier)
                                  .state = currentPage - 1
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 16),
                        Text(
                            'Sayfa ${currentPage + 1} / $totalPages'),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed:
                              currentPage < totalPages - 1
                                  ? () => ref
                                      .read(vocabularyPageProvider
                                          .notifier)
                                      .state = currentPage + 1
                                  : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text('Hata: $error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(vocabularyProvider),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildRow(BuildContext context, Map<String, dynamic> w) {
    final phonetic = w['phonetic'] as String? ?? '';
    final meaningTr = w['meaning_tr'] as String? ?? '';
    final meaningEn = w['meaning_en'] as String? ?? '';
    final examples = w['example_sentences'] as List<dynamic>? ?? [];
    final firstExample =
        examples.isNotEmpty ? examples.first.toString() : '';
    final hasAudio =
        (w['audio_url'] as String?)?.isNotEmpty ?? false;
    final hasImage =
        (w['image_url'] as String?)?.isNotEmpty ?? false;

    return TableRow(
      children: [
        // Kelime
        InkWell(
          onTap: () => context.push('/vocabulary/${w['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w['word'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                ),
                if (w['source'] == 'activity') ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'AKTİVİTEDEN EKLENDİ',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.purple),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Fonetik
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            phonetic,
            style: TextStyle(
              color: phonetic.isEmpty
                  ? Colors.grey.shade300
                  : Colors.grey.shade500,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        // Anlam TR
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            meaningTr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        // Anlam EN
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            meaningEn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: meaningEn.isEmpty
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
            ),
          ),
        ),
        // Örnek Cümle
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            firstExample,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: firstExample.isEmpty
                  ? Colors.grey.shade300
                  : Colors.grey.shade600,
              fontStyle: firstExample.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
        // Ses
        Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            hasAudio ? Icons.check_circle : Icons.cancel,
            size: 18,
            color:
                hasAudio ? Colors.green.shade600 : Colors.grey.shade300,
          ),
        ),
        // Görsel
        Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            hasImage ? Icons.check_circle : Icons.cancel,
            size: 18,
            color:
                hasImage ? Colors.green.shade600 : Colors.grey.shade300,
          ),
        ),
        // Chevron
        InkWell(
          onTap: () => context.push('/vocabulary/${w['id']}'),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child:
                Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ),
        ),
      ],
    );
  }
}

// ============================================
// TAB 1: KELIME LISTELERI
// ============================================

class _WordlistTab extends ConsumerWidget {
  const _WordlistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordlistsAsync = ref.watch(wordlistsProvider);

    return wordlistsAsync.when(
      data: (wordlists) {
        if (wordlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Kelime listesi bulunamadı',
                    style: TextStyle(
                        fontSize: 18, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.go('/wordlists/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('İlk kelime listenizi oluşturun'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: wordlists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _WordlistCard(wordlist: wordlists[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text('Hata: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(wordlistsProvider),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordlistCard extends StatelessWidget {
  const _WordlistCard({required this.wordlist});

  final Map<String, dynamic> wordlist;

  @override
  Widget build(BuildContext context) {
    final name = wordlist['name'] as String? ?? '';
    final description = wordlist['description'] as String? ?? '';
    final items = List<Map<String, dynamic>>.from(
        wordlist['word_list_items'] ?? []);

    // Extract words and content stats
    final words = <String>[];
    int missingAudio = 0;
    int missingImage = 0;
    int missingExamples = 0;
    int missingMeaningEn = 0;
    int missingPhonetic = 0;

    for (final item in items) {
      final vocab = item['vocabulary_words'] as Map<String, dynamic>?;
      if (vocab == null) continue;

      words.add(vocab['word'] as String? ?? '');

      final audioUrl = vocab['audio_url'] as String? ?? '';
      final imageUrl = vocab['image_url'] as String? ?? '';
      final examples =
          vocab['example_sentences'] as List<dynamic>? ?? [];
      final meaningEn = vocab['meaning_en'] as String? ?? '';
      final phonetic = vocab['phonetic'] as String? ?? '';

      if (audioUrl.isEmpty) missingAudio++;
      if (imageUrl.isEmpty) missingImage++;
      if (examples.isEmpty) missingExamples++;
      if (meaningEn.isEmpty) missingMeaningEn++;
      if (phonetic.isEmpty) missingPhonetic++;
    }

    final wordCount = words.length;
    final wordsText = words.join(', ');
    final hasWarnings = missingAudio > 0 ||
        missingImage > 0 ||
        missingExamples > 0 ||
        missingMeaningEn > 0 ||
        missingPhonetic > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/wordlists/${wordlist['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name + word count
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$wordCount kelime',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              // Row 2: Description
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              ],

              // Row 3: Words list
              if (words.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  wordsText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
              ],

              // Row 4: Content warnings
              if (hasWarnings && wordCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (missingAudio > 0)
                      _WarningChip(
                        icon: Icons.volume_off,
                        label: '$missingAudio ses eksik',
                        severe: missingAudio == wordCount,
                      ),
                    if (missingImage > 0)
                      _WarningChip(
                        icon: Icons.hide_image,
                        label: '$missingImage görsel eksik',
                        severe: missingImage == wordCount,
                      ),
                    if (missingExamples > 0)
                      _WarningChip(
                        icon: Icons.format_quote,
                        label: '$missingExamples örnek eksik',
                        severe: missingExamples == wordCount,
                      ),
                    if (missingMeaningEn > 0)
                      _WarningChip(
                        icon: Icons.translate,
                        label: '$missingMeaningEn EN anlam eksik',
                        severe: missingMeaningEn == wordCount,
                      ),
                    if (missingPhonetic > 0)
                      _WarningChip(
                        icon: Icons.record_voice_over,
                        label: '$missingPhonetic fonetik eksik',
                        severe: missingPhonetic == wordCount,
                      ),
                  ],
                ),
              ],

              // All complete badge
              if (!hasWarnings && wordCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Tüm içerik tamamlanmış',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningChip extends StatelessWidget {
  const _WarningChip({
    required this.icon,
    required this.label,
    required this.severe,
  });

  final IconData icon;
  final String label;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final color = severe ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// SHARED WIDGETS
// ============================================

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _HeaderIconCell extends StatelessWidget {
  const _HeaderIconCell(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(icon, size: 16, color: Colors.grey.shade700),
    );
  }
}
