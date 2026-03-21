import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../vocabulary/screens/vocabulary_list_screen.dart';

/// Provider for loading a single word list with its items (full word details)
final wordlistDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, listId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.wordLists)
      .select('*, word_list_items(id, order_index, vocabulary_words(*))')
      .eq('id', listId)
      .maybeSingle();

  return response;
});

/// Provider for searching vocabulary words
final wordlistWordSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.isEmpty) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyWords)
      .select('id, word, meaning_tr, level')
      .ilike('word', '%$query%')
      .order('word')
      .limit(10);

  return List<Map<String, dynamic>>.from(response);
});

class WordlistEditScreen extends ConsumerStatefulWidget {
  const WordlistEditScreen({super.key, this.listId});

  final String? listId;

  @override
  ConsumerState<WordlistEditScreen> createState() => _WordlistEditScreenState();
}

class _WordlistEditScreenState extends ConsumerState<WordlistEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _wordItems = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isGeneratingAudio = false;

  bool get isNewList => widget.listId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewList) {
      _loadWordList();
    }
  }

  Future<void> _loadWordList() async {
    setState(() => _isLoading = true);

    final wordlist = await ref.read(wordlistDetailProvider(widget.listId!).future);
    if (wordlist != null && mounted) {
      _nameController.text = wordlist['name'] ?? '';
      _descriptionController.text = wordlist['description'] ?? '';

      // Parse word items
      final items = wordlist['word_list_items'] as List? ?? [];
      final wordItems = items
          .map((item) => {
                'item_id': item['id'],
                'order_index': item['order_index'] ?? 0,
                ...item['vocabulary_words'] as Map<String, dynamic>,
              })
          .toList();

      // Sort by order_index
      wordItems.sort(
          (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));

      setState(() {
        _wordItems = List<Map<String, dynamic>>.from(wordItems);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'is_system': true,
      };

      String listId;

      if (isNewList) {
        listId = const Uuid().v4();
        data['id'] = listId;
        await supabase.from(DbTables.wordLists).insert(data);
      } else {
        listId = widget.listId!;
        await supabase.from(DbTables.wordLists).update(data).eq('id', listId);
      }

      // Update word items
      // Delete existing items and re-insert
      await supabase.from(DbTables.wordListItems).delete().eq('word_list_id', listId);

      if (_wordItems.isNotEmpty) {
        final items = _wordItems.asMap().entries.map((entry) => {
              'id': const Uuid().v4(),
              'word_list_id': listId,
              'word_id': entry.value['id'],
              'order_index': entry.key,
            }).toList();

        await supabase.from(DbTables.wordListItems).insert(items);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNewList
                ? 'Kelime listesi oluşturuldu'
                : 'Kelime listesi kaydedildi'),
          ),
        );
        ref.invalidate(wordlistsProvider);
        if (isNewList) {
          context.go('/wordlists/$listId');
        } else {
          ref.invalidate(wordlistDetailProvider(widget.listId!));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _generateWordlistAudio() async {
    if (widget.listId == null || _wordItems.isEmpty) return;

    setState(() => _isGeneratingAudio = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'generate-wordlist-audio',
        body: {'wordListId': widget.listId},
      );

      if (response.status != 200) {
        throw Exception(
            response.data?['error'] ?? 'Failed to generate audio');
      }

      final wordsProcessed = response.data?['wordsProcessed'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$wordsProcessed kelime için ses üretildi!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(wordlistDetailProvider(widget.listId!));
        ref.invalidate(wordlistsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses üretme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAudio = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kelime Listesini Sil'),
        content: const Text(
          'Bu kelime listesini silmek istediğinizden emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.wordLists).delete().eq('id', widget.listId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kelime listesi silindi')),
        );
        ref.invalidate(wordlistsProvider);
        context.go('/vocabulary');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddWordDialog() {
    _searchController.clear();

    showDialog(
      context: context,
      builder: (context) => _AddWordDialog(
        searchController: _searchController,
        onWordSelected: (word) {
          // Check if word already exists
          if (_wordItems.any((item) => item['id'] == word['id'])) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kelime zaten listede')),
            );
            return;
          }

          setState(() {
            _wordItems.add(word);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeWord(int index) {
    setState(() {
      _wordItems.removeAt(index);
    });
  }

  void _moveWord(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _wordItems.removeAt(oldIndex);
      _wordItems.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewList ? 'Yeni Kelime Listesi' : 'Kelime Listesini Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vocabulary'),
        ),
        actions: [
          if (!isNewList && _wordItems.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _isGeneratingAudio ? null : _generateWordlistAudio,
              icon: _isGeneratingAudio
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_up, size: 18),
              label: Text(_isGeneratingAudio ? 'Üretiliyor...' : 'Sesleri Üret'),
            ),
          const SizedBox(width: 8),
          if (!isNewList)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: _handleDelete,
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isNewList ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top: Form + Word list side by side
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Liste Detayları',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 24),

                                // Name
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ad',
                                    hintText: 'ör. Yaygın A1 Kelimeler',
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Ad zorunludur';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Description
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Açıklama',
                                    hintText: 'Bu kelime listesini açıklayın',
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Word list
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border(
                              left:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Kelimeler (${_wordItems.length})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    TextButton.icon(
                                      onPressed: _showAddWordDialog,
                                      icon:
                                          const Icon(Icons.add, size: 18),
                                      label: const Text('Kelime Ekle'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),

                              // Word list
                              Expanded(
                                child: _wordItems.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.list,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Henüz kelime yok',
                                              style: TextStyle(
                                                color:
                                                    Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextButton.icon(
                                              onPressed:
                                                  _showAddWordDialog,
                                              icon:
                                                  const Icon(Icons.add),
                                              label:
                                                  const Text('Kelime Ekle'),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ReorderableListView.builder(
                                        padding:
                                            const EdgeInsets.all(8),
                                        itemCount: _wordItems.length,
                                        onReorder: _moveWord,
                                        itemBuilder: (context, index) {
                                          final word =
                                              _wordItems[index];
                                          return Card(
                                            key: ValueKey(word['id']),
                                            margin:
                                                const EdgeInsets
                                                    .symmetric(
                                              vertical: 4,
                                            ),
                                            child: ListTile(
                                              leading:
                                                  ReorderableDragStartListener(
                                                index: index,
                                                child: const Icon(
                                                  Icons.drag_handle,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              title: InkWell(
                                                onTap: () => context.go(
                                                    '/vocabulary/${word['id']}'),
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        word['word'] ??
                                                            '',
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight
                                                                  .w500,
                                                          color: Color(
                                                              0xFF4F46E5),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 4),
                                                    const Icon(
                                                      Icons.open_in_new,
                                                      size: 14,
                                                      color: Color(
                                                          0xFF4F46E5),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              subtitle: Text(
                                                word['meaning_tr'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                              ),
                                              trailing: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors
                                                          .grey.shade200,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  4),
                                                    ),
                                                    child: Text(
                                                      '${index + 1}',
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline,
                                                      size: 20,
                                                    ),
                                                    color: Colors.red,
                                                    onPressed: () =>
                                                        _removeWord(
                                                            index),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom: Content completeness table
                if (_wordItems.isNotEmpty)
                  _WordContentTable(
                    wordItems: _wordItems,
                    onWordTap: (wordId) => context.go('/vocabulary/$wordId'),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content completeness table
// ---------------------------------------------------------------------------

class _WordContentTable extends StatelessWidget {
  const _WordContentTable({
    required this.wordItems,
    required this.onWordTap,
  });

  final List<Map<String, dynamic>> wordItems;
  final void Function(String wordId) onWordTap;

  static bool _hasValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    const fieldKeys = [
      'meaning_tr',
      'meaning_en',
      'phonetic',
      'audio_url',
      'image_url',
      'example_sentences',
    ];
    int totalFilled = 0;
    final totalFields = wordItems.length * fieldKeys.length;
    final missingWords = <int>[];

    for (int i = 0; i < wordItems.length; i++) {
      final w = wordItems[i];
      int wordFilled = 0;
      for (final key in fieldKeys) {
        if (_hasValue(w[key])) wordFilled++;
      }
      totalFilled += wordFilled;
      if (wordFilled < fieldKeys.length) missingWords.add(i);
    }

    final pct = totalFields > 0 ? (totalFilled / totalFields * 100).round() : 0;
    final allComplete = missingWords.isEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: allComplete
                ? const Color(0xFF059669).withValues(alpha: 0.08)
                : const Color(0xFFEA580C).withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  allComplete
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 20,
                  color: allComplete
                      ? const Color(0xFF059669)
                      : const Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                Text(
                  'İçerik: $totalFilled/$totalFields alan ($pct%)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: allComplete
                        ? const Color(0xFF059669)
                        : const Color(0xFFEA580C),
                  ),
                ),
                if (!allComplete) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${missingWords.length} kelimede eksik alan var',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Table
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 36,
                  columnSpacing: 16,
                  horizontalMargin: 8,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Kelime')),
                    DataColumn(label: Text('TR')),
                    DataColumn(label: Text('EN')),
                    DataColumn(label: Text('Fonetik')),
                    DataColumn(label: Text('Ses')),
                    DataColumn(label: Text('Görsel')),
                    DataColumn(label: Text('Örnekler')),
                    DataColumn(label: Text('Puan')),
                  ],
                  rows: List.generate(wordItems.length, (i) {
                    final w = wordItems[i];
                    int filled = 0;
                    for (final key in fieldKeys) {
                      if (_hasValue(w[key])) filled++;
                    }
                    final isComplete = filled == fieldKeys.length;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith((states) {
                        if (isComplete) return null;
                        return const Color(0xFFFEF3C7); // light amber
                      }),
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(
                          InkWell(
                            onTap: () => onWordTap(w['id'] as String),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  w['word'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.open_in_new,
                                  size: 12,
                                  color: Color(0xFF4F46E5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(_fieldIcon(_hasValue(w['meaning_tr']))),
                        DataCell(_fieldIcon(_hasValue(w['meaning_en']))),
                        DataCell(_fieldIcon(_hasValue(w['phonetic']))),
                        DataCell(_fieldIcon(_hasValue(w['audio_url']))),
                        DataCell(_fieldIcon(_hasValue(w['image_url']))),
                        DataCell(_examplesCell(w['example_sentences'])),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? const Color(0xFF059669)
                                      .withValues(alpha: 0.1)
                                  : const Color(0xFFEA580C)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$filled/${fieldKeys.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isComplete
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFEA580C),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldIcon(bool hasValue) {
    return Icon(
      hasValue ? Icons.check_circle : Icons.cancel,
      size: 18,
      color: hasValue ? const Color(0xFF059669) : Colors.red.shade300,
    );
  }

  Widget _examplesCell(dynamic examples) {
    if (examples == null || (examples is List && examples.isEmpty)) {
      return Icon(Icons.cancel, size: 18, color: Colors.red.shade300);
    }
    final count = (examples as List).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 18, color: Color(0xFF059669)),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add word dialog
// ---------------------------------------------------------------------------

class _AddWordDialog extends ConsumerStatefulWidget {
  const _AddWordDialog({
    required this.searchController,
    required this.onWordSelected,
  });

  final TextEditingController searchController;
  final void Function(Map<String, dynamic> word) onWordSelected;

  @override
  ConsumerState<_AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends ConsumerState<_AddWordDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(wordlistWordSearchProvider(_searchQuery));

    return AlertDialog(
      title: const Text('Kelime Ekle'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: widget.searchController,
              decoration: const InputDecoration(
                labelText: 'Kelime ara',
                hintText: 'Aramak için yazın...',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: searchResults.when(
                data: (words) {
                  if (_searchQuery.isEmpty) {
                    return Center(
                      child: Text(
                        'Aramak için yazmaya başlayın',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  if (words.isEmpty) {
                    return Center(
                      child: Text(
                        'Kelime bulunamadı',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: words.length,
                    itemBuilder: (context, index) {
                      final word = words[index];
                      return ListTile(
                        title: Text(word['word'] ?? ''),
                        subtitle: Text(word['meaning_tr'] ?? ''),
                        trailing: Text(
                          word['level'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => widget.onWordSelected(word),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Hata: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
      ],
    );
  }
}
