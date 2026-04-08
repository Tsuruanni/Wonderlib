import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
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
  bool _isGeneratingImages = false;
  bool _isGeneratingContent = false;
  String _contentProgress = '';

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

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'is_system': true,
      };

      String listId;

      if (isNewList) {
        listId = const Uuid().v4();
        data['id'] = listId;
        data['category'] = 'thematic';
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

  bool _wordHasMissingContent(Map<String, dynamic> word) {
    final fields = ['meaning_tr', 'meaning_en', 'phonetic', 'example_sentences'];
    for (final field in fields) {
      final value = word[field];
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      if (value is List && value.isEmpty) return true;
    }
    return false;
  }

  Future<void> _generateBulkContent() async {
    final incompleteWords = _wordItems
        .where(_wordHasMissingContent)
        .toList();

    if (incompleteWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm kelimelerin içeriği tamamlanmış!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu İçerik Üretimi'),
        content: Text(
          '${incompleteWords.length} kelimenin eksik içeriği AI ile doldurulacak '
          '(phonetic, anlam, örnek cümleler).\n\n'
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Üret'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isGeneratingContent = true;
      _contentProgress = '0/${incompleteWords.length}';
    });

    int successCount = 0;
    int failCount = 0;
    final supabase = ref.read(supabaseClientProvider);

    // Process 3 at a time to avoid rate limits
    for (int i = 0; i < incompleteWords.length; i += 3) {
      final batch = incompleteWords.skip(i).take(3).toList();

      final futures = batch.map((word) async {
        final wordName = word['word'] as String? ?? '';
        try {
          final response = await supabase.functions.invoke(
            'generate-word-data',
            body: {'word': wordName},
          );

          if (response.status != 200) return false;

          final data = response.data as Map<String, dynamic>?;
          if (data == null) return false;

          // Only update fields that are currently empty
          final updates = <String, dynamic>{};
          if (_isEmpty(word['meaning_tr']) && data['meaning_tr'] != null) {
            updates['meaning_tr'] = data['meaning_tr'];
          }
          if (_isEmpty(word['meaning_en']) && data['meaning_en'] != null) {
            updates['meaning_en'] = data['meaning_en'];
          }
          if (_isEmpty(word['phonetic']) && data['phonetic'] != null) {
            updates['phonetic'] = data['phonetic'];
          }
          if (_isEmptyList(word['example_sentences']) &&
              data['example_sentences'] != null) {
            updates['example_sentences'] = data['example_sentences'];
          }
          if (_isEmpty(word['part_of_speech']) &&
              data['part_of_speech'] != null) {
            updates['part_of_speech'] = data['part_of_speech'];
          }

          if (updates.isNotEmpty) {
            await supabase
                .from(DbTables.vocabularyWords)
                .update(updates)
                .eq('id', word['id']);
          }
          return true;
        } catch (_) {
          return false;
        }
      });

      final results = await Future.wait(futures);
      successCount += results.where((r) => r).length;
      failCount += results.where((r) => !r).length;

      if (mounted) {
        setState(() {
          _contentProgress =
              '${successCount + failCount}/${incompleteWords.length}';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isGeneratingContent = false;
        _contentProgress = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount kelime güncellendi'
            '${failCount > 0 ? ', $failCount başarısız' : ''}',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
        ),
      );
      ref.invalidate(wordlistDetailProvider(widget.listId!));
      _loadWordList();
    }
  }

  bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  bool _isEmptyList(dynamic value) {
    if (value == null) return true;
    if (value is List) return value.isEmpty;
    return true;
  }

  Future<void> _showImageGenerationDialog() async {
    final promptController = TextEditingController(
      text:
          'A 2x3 grid of 6 separate illustrations for a children\'s '
          'English learning app. Each cell contains exactly one object/concept '
          'illustration. No borders, no frames, no dividing lines. '
          'Seamless white background. '
          'IMPORTANT: Do NOT include any text, letters, words or labels. Only illustrations.',
    );
    var selectedStyle = 'flat';
    var includeExamples = false;
    var overwrite = false;

    final wordsWithImages =
        _wordItems.where((w) {
          final url = w['image_url'] as String?;
          return url != null && url.isNotEmpty;
        }).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final wordsToProcess = overwrite
              ? _wordItems.length
              : _wordItems.length - wordsWithImages;
          final apiCalls = wordsToProcess > 0
              ? (wordsToProcess / 6).ceil()
              : 0;

          return AlertDialog(
            title: const Text('Görsel Üretimi'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Style selector
                  const Text(
                    'Stil',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'flat': 'Flat',
                        'cartoon': 'Cartoon',
                        'watercolor': 'Watercolor',
                        'realistic': 'Realistic',
                        'pixel': 'Pixel Art',
                        'clay': 'Clay 3D',
                        'sticker': 'Sticker',
                        'pencil': 'Pencil Sketch',
                        'isometric': 'Isometric',
                        'pop': 'Pop Art',
                        'minimal': 'Minimal Line',
                      }.entries)
                        _styleChip(entry.key, entry.value, selectedStyle, (v) {
                          setDialogState(() => selectedStyle = v);
                        }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Prompt editor
                  const Text(
                    'Prompt',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: promptController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Görsel üretim promptu...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Options
                  CheckboxListTile(
                    value: includeExamples,
                    onChanged: (v) =>
                        setDialogState(() => includeExamples = v ?? false),
                    title: const Text('Örnek cümle bağlamı ekle'),
                    subtitle: const Text(
                      'Çok anlamlı kelimelerde doğru görseli üretmek için',
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: overwrite,
                    onChanged: (v) =>
                        setDialogState(() => overwrite = v ?? false),
                    title: const Text('Mevcut görselleri yeniden üret'),
                    subtitle: Text(
                      '$wordsWithImages/${_wordItems.length} kelimenin görseli var',
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: wordsToProcess == 0
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: wordsToProcess == 0
                            ? Colors.orange.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          wordsToProcess == 0
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          size: 18,
                          color: wordsToProcess == 0
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            wordsToProcess == 0
                                ? 'Tüm kelimelerin görseli var. Yeniden üretmek için üstteki seçeneği işaretleyin.'
                                : '$wordsToProcess kelime için $apiCalls API çağrısı yapılacak',
                            style: TextStyle(
                              fontSize: 13,
                              color: wordsToProcess == 0
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              FilledButton.icon(
                onPressed: wordsToProcess > 0
                    ? () => Navigator.pop(context, true)
                    : null,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Üret'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) {
      promptController.dispose();
      return;
    }

    setState(() => _isGeneratingImages = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'generate-wordlist-images',
        body: {
          'wordListId': widget.listId,
          'style': selectedStyle,
          'prompt': promptController.text.trim(),
          'includeExamples': includeExamples,
          'overwrite': overwrite,
        },
      );

      if (response.status != 200) {
        throw Exception(
            response.data?['error'] ?? 'Failed to generate images');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görseller başarıyla üretildi!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(wordlistDetailProvider(widget.listId!));
        ref.invalidate(wordlistsProvider);
        _loadWordList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel üretme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingImages = false);
    }

    promptController.dispose();
  }

  Widget _styleChip(
    String value,
    String label,
    String selectedStyle,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = selectedStyle == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4F46E5) : null,
        fontWeight: isSelected ? FontWeight.w600 : null,
      ),
    );
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

  Future<void> _saveWordField(int index, String field, dynamic value) async {
    final word = _wordItems[index];
    final wordId = word['id'] as String;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.vocabularyWords)
          .update({field: value}).eq('id', wordId);

      setState(() {
        final updated = Map<String, dynamic>.from(word);
        updated[field] = value;
        _wordItems[index] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
              onPressed: _isGeneratingContent ? null : _generateBulkContent,
              icon: _isGeneratingContent
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 18),
              label: Text(_isGeneratingContent
                  ? 'İçerik ($_contentProgress)'
                  : 'İçerikleri Üret'),
            ),
          const SizedBox(width: 8),
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
          if (!isNewList && _wordItems.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _isGeneratingImages ? null : _showImageGenerationDialog,
              icon: _isGeneratingImages
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image, size: 18),
              label: Text(_isGeneratingImages ? 'Üretiliyor...' : 'Görselleri Üret'),
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
                // Top: Form (centered, compact)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Ad',
                                  hintText: 'ör. Yaygın A1 Kelimeler',
                                  isDense: true,
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Ad zorunludur';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Açıklama',
                                  hintText: 'Bu kelime listesini açıklayın',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Header bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Text(
                        'Kelimeler (${_wordItems.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showAddWordDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Kelime Ekle'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Word list (full height)
                Expanded(
                  child: _wordItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _showAddWordDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Kelime Ekle'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: List.generate(_wordItems.length, (index) {
                              final word = _wordItems[index];
                              return _WordCard(
                                key: ValueKey(word['id']),
                                word: word,
                                index: index,
                                total: _wordItems.length,
                                onRemove: () => _removeWord(index),
                                onMoveLeft: index > 0
                                    ? () => _moveWord(index, index - 1)
                                    : null,
                                onMoveRight: index < _wordItems.length - 1
                                    ? () => _moveWord(index, index + 2)
                                    : null,
                                onSaveField: (field, value) =>
                                    _saveWordField(index, field, value),
                                onTap: () =>
                                    context.go('/vocabulary/${word['id']}'),
                              );
                            }),
                          ),
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
// Word card with inline quick edit
// ---------------------------------------------------------------------------

class _WordCard extends ConsumerStatefulWidget {
  const _WordCard({
    super.key,
    required this.word,
    required this.index,
    required this.total,
    required this.onRemove,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSaveField,
    required this.onTap,
  });

  final Map<String, dynamic> word;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final Future<void> Function(String field, dynamic value) onSaveField;
  final VoidCallback onTap;

  @override
  ConsumerState<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends ConsumerState<_WordCard> {
  bool _isEditing = false;
  late final TextEditingController _meaningTrController;
  late final TextEditingController _meaningEnController;
  late final TextEditingController _exampleController;
  bool _isSaving = false;
  int _versionCount = 0;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadVersionCount();
  }

  void _initControllers() {
    _meaningTrController = TextEditingController(
      text: widget.word['meaning_tr'] as String? ?? '',
    );
    _meaningEnController = TextEditingController(
      text: widget.word['meaning_en'] as String? ?? '',
    );
    final examples = widget.word['example_sentences'] as List?;
    _exampleController = TextEditingController(
      text: examples != null && examples.isNotEmpty
          ? examples.first as String
          : '',
    );
  }

  Future<void> _loadVersionCount() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final wordId = widget.word['id'] as String;

      // New format: words/{word_id}/ folder with timestamped files
      final result = await supabase.storage
          .from('word-images')
          .list(path: 'words/$wordId');
      final count = result
          .where((f) =>
              f.name.endsWith('.png') || f.name.endsWith('.jpg'))
          .length;

      if (mounted) setState(() => _versionCount = count);
    } catch (e) {
      debugPrint('Version count error for ${widget.word['id']}: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word['id'] != widget.word['id']) {
      _meaningTrController.text =
          widget.word['meaning_tr'] as String? ?? '';
      _meaningEnController.text =
          widget.word['meaning_en'] as String? ?? '';
      final examples = widget.word['example_sentences'] as List?;
      _exampleController.text = examples != null && examples.isNotEmpty
          ? examples.first as String
          : '';
      _isEditing = false;
      _loadVersionCount();
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _meaningTrController.dispose();
    _meaningEnController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    final audioUrl = widget.word['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      _audioPlayer ??= AudioPlayer();
      final startMs = widget.word['audio_start_ms'] as int? ?? 0;
      final endMs = widget.word['audio_end_ms'] as int? ?? 0;

      // Strip query params to get the base URL
      final baseUrl = audioUrl.split('?').first;

      await _audioPlayer!.setUrl(baseUrl);

      if (startMs > 0 || endMs > 0) {
        await _audioPlayer!.setClip(
          start: Duration(milliseconds: startMs),
          end: endMs > 0 ? Duration(milliseconds: endMs) : null,
        );
      }

      setState(() => _isPlaying = true);
      await _audioPlayer!.play();
      if (mounted) setState(() => _isPlaying = false);
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
      debugPrint('Audio play error: $e');
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final oldTr = widget.word['meaning_tr'] as String? ?? '';
      final oldEn = widget.word['meaning_en'] as String? ?? '';
      final oldExamples = widget.word['example_sentences'] as List?;
      final oldExample = oldExamples != null && oldExamples.isNotEmpty
          ? oldExamples.first as String
          : '';

      if (_meaningTrController.text.trim() != oldTr) {
        await widget.onSaveField(
            'meaning_tr', _meaningTrController.text.trim());
      }
      if (_meaningEnController.text.trim() != oldEn) {
        await widget.onSaveField(
            'meaning_en', _meaningEnController.text.trim());
      }
      if (_exampleController.text.trim() != oldExample) {
        final newExamples = _exampleController.text.trim().isEmpty
            ? <String>[]
            : [_exampleController.text.trim()];
        await widget.onSaveField('example_sentences', newExamples);
      }

      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showImageVersions() {
    final wordId = widget.word['id'] as String;
    showDialog(
      context: context,
      builder: (_) => _ImageVersionDialog(
        wordId: wordId,
        currentImageUrl: widget.word['image_url'] as String?,
        onSelect: (url) async {
          await widget.onSaveField('image_url', url);
          if (mounted) {
            setState(() {});
            _loadVersionCount();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.word['image_url'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final meaningTr = widget.word['meaning_tr'] as String? ?? '';
    final meaningEn = widget.word['meaning_en'] as String? ?? '';
    final phonetic = widget.word['phonetic'] as String? ?? '';
    final hasAudio =
        (widget.word['audio_url'] as String?)?.isNotEmpty == true;
    final examples = widget.word['example_sentences'] as List?;

    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image area
            Stack(
              children: [
                Container(
                  height: 160,
                  color: Colors.grey.shade100,
                  width: double.infinity,
                  child: hasImage
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.grey.shade400, size: 40),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.image_outlined,
                              color: Colors.grey.shade300, size: 48),
                        ),
                ),
                // Index badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Reorder arrows
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onMoveLeft != null)
                        _miniButton(Icons.chevron_left, widget.onMoveLeft!),
                      if (widget.onMoveRight != null)
                        _miniButton(
                            Icons.chevron_right, widget.onMoveRight!),
                    ],
                  ),
                ),
              ],
            ),

            // Content area
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Word name row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: widget.onTap,
                          child: Text(
                            widget.word['word'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (hasAudio)
                        GestureDetector(
                          onTap: _isPlaying ? null : _playAudio,
                          child: Icon(
                            _isPlaying
                                ? Icons.volume_up
                                : Icons.volume_up_outlined,
                            size: 16,
                            color: _isPlaying
                                ? const Color(0xFF4F46E5)
                                : Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  if (phonetic.isNotEmpty)
                    Text(
                      '/$phonetic/',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const Divider(height: 12),

                  // Edit / View mode
                  if (_isEditing) ...[
                    _editField('TR', _meaningTrController),
                    const SizedBox(height: 6),
                    _editField('EN', _meaningEnController),
                    const SizedBox(height: 6),
                    _editField('Örnek', _exampleController),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _isEditing = false),
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                          child: const Text('İptal',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: _isSaving ? null : _saveAll,
                          style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Text('Kaydet',
                                  style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (meaningTr.isNotEmpty)
                      Text(
                        meaningTr,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (meaningEn.isNotEmpty)
                      Text(
                        meaningEn,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (examples != null && examples.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '"${examples.first}"',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Version count + action row
                    if (_versionCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: _showImageVersions,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_outlined,
                                  size: 13,
                                  color: const Color(0xFF4F46E5)),
                              const SizedBox(width: 4),
                              Text(
                                '$_versionCount versiyon',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _isEditing = true),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                'Düzenle',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: widget.onRemove,
                          child: Icon(Icons.delete_outline,
                              size: 16, color: Colors.red.shade300),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _editField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      style: const TextStyle(fontSize: 12),
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
  bool _isCreating = false;

  Future<void> _createAndAddWord(String wordText) async {
    setState(() => _isCreating = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final id = const Uuid().v4();
      final word = wordText.trim().toLowerCase();

      await supabase.from(DbTables.vocabularyWords).insert({
        'id': id,
        'word': word,
      });

      widget.onWordSelected({
        'id': id,
        'word': word,
        'meaning_tr': null,
        'meaning_en': null,
        'phonetic': null,
        'audio_url': null,
        'image_url': null,
        'example_sentences': null,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kelime oluşturulamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

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

                  // Check if exact match exists
                  final hasExactMatch = words.any((w) =>
                      (w['word'] as String?)?.toLowerCase() ==
                      _searchQuery.toLowerCase());

                  return Column(
                    children: [
                      // Results list
                      Expanded(
                        child: words.isEmpty
                            ? Center(
                                child: Text(
                                  'Sonuç bulunamadı',
                                  style: TextStyle(
                                      color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: words.length,
                                itemBuilder: (context, index) {
                                  final word = words[index];
                                  return ListTile(
                                    title: Text(word['word'] ?? ''),
                                    subtitle:
                                        Text(word['meaning_tr'] ?? ''),
                                    trailing: Text(
                                      word['level'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onTap: () =>
                                        widget.onWordSelected(word),
                                  );
                                },
                              ),
                      ),
                      // Always show "create new" if no exact match
                      if (!hasExactMatch) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8),
                          child: FilledButton.icon(
                            onPressed: _isCreating
                                ? null
                                : () => _createAndAddWord(
                                    _searchQuery),
                            icon: _isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add, size: 18),
                            label: Text(
                              _isCreating
                                  ? 'Ekleniyor...'
                                  : '"$_searchQuery" yeni kelime olarak ekle',
                            ),
                          ),
                        ),
                      ],
                    ],
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

// ---------------------------------------------------------------------------
// Image version picker dialog
// ---------------------------------------------------------------------------

class _ImageVersionDialog extends ConsumerStatefulWidget {
  const _ImageVersionDialog({
    required this.wordId,
    required this.currentImageUrl,
    required this.onSelect,
  });

  final String wordId;
  final String? currentImageUrl;
  final Future<void> Function(String url) onSelect;

  @override
  ConsumerState<_ImageVersionDialog> createState() =>
      _ImageVersionDialogState();
}

class _ImageVersionDialogState extends ConsumerState<_ImageVersionDialog> {
  List<String> _imageUrls = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase.storage
          .from('word-images')
          .list(path: 'words/${widget.wordId}');

      final urls = <String>[];
      for (final file in result) {
        if (file.name.endsWith('.png') || file.name.endsWith('.jpg')) {
          final publicUrl = supabase.storage
              .from('word-images')
              .getPublicUrl('words/${widget.wordId}/${file.name}');
          urls.add(publicUrl);
        }
      }

      // En yenisi önce
      urls.sort((a, b) => b.compareTo(a));

      setState(() {
        _imageUrls = urls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Görsel Versiyonları'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Hata: $_error'))
                : _imageUrls.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz görsel versiyonu yok',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _imageUrls.length,
                        itemBuilder: (context, index) {
                          final url = _imageUrls[index];
                          final isCurrent = widget.currentImageUrl == url;

                          return GestureDetector(
                            onTap: isCurrent
                                ? null
                                : () async {
                                    await widget.onSelect(url);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xFF4F46E5)
                                      : Colors.grey.shade300,
                                  width: isCurrent ? 3 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey.shade400),
                                    ),
                                  ),
                                  if (isCurrent)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Aktif',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
