import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:universal_html/html.dart' as html;
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

/// Provider for searching vocabulary words. With an empty query it returns
/// the most-recently-added words (ordered by created_at DESC) so the picker
/// dialog has something useful to show before the operator types anything.
final wordlistWordSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  final supabase = ref.watch(supabaseClientProvider);
  var q = supabase
      .from(DbTables.vocabularyWords)
      .select('id, word, meaning_tr, level, created_at');
  if (query.isNotEmpty) {
    q = q.ilike('word', '%$query%');
  }
  // Primary sort: created_at DESC (microsecond precision — distinguishes even
  // rapid-fire CSV inserts). Secondary: id DESC as a stable tiebreaker for
  // the rare case two rows share the exact same timestamp.
  final response = await q
      .order('created_at', ascending: false)
      .order('id', ascending: false)
      .limit(query.isEmpty ? 30 : 20);

  return List<Map<String, dynamic>>.from(response);
});

enum _WordlistSortMode {
  manual('Manuel sıra'),
  alphabetic('Alfabetik (A→Z)'),
  mostIncomplete('En eksik önce'),
  recentlyAdded('En yeni eklenen');

  const _WordlistSortMode(this.label);
  final String label;
}

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
  final _searchController = TextEditingController(); // used by _AddWordDialog
  final _listSearchController = TextEditingController(); // filters _wordItems display

  List<Map<String, dynamic>> _wordItems = [];
  String _listSearchQuery = '';
  // Active "missing X" filters — keys: audio, image, tr, en, example.
  // Multiple selections combine with OR (a word matches if it's missing any
  // of the selected fields), since the typical workflow is "find anything
  // that needs work" rather than "find words missing both X and Y".
  final Set<String> _missingFilters = {};
  _WordlistSortMode _sortMode = _WordlistSortMode.manual;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isGeneratingAudio = false;
  bool _isGeneratingImages = false;
  bool _isGeneratingContent = false;
  String _contentProgress = '';

  bool get isNewList => widget.listId == null;

  bool get _isAnyGenerationActive =>
      _isGeneratingAudio || _isGeneratingImages || _isGeneratingContent;

  /// Items filtered by [_listSearchQuery] + [_missingFilters], then sorted
  /// per [_sortMode]. Stats are still computed against the full [_wordItems]
  /// so completion percentages don't lie when filters are active.
  List<Map<String, dynamic>> get _filteredWordItems {
    Iterable<Map<String, dynamic>> items = _wordItems;

    // 1. Text search
    if (_listSearchQuery.isNotEmpty) {
      final q = _listSearchQuery.toLowerCase();
      items = items.where((w) {
        final word = (w['word'] as String? ?? '').toLowerCase();
        final tr = (w['meaning_tr'] as String? ?? '').toLowerCase();
        final en = (w['meaning_en'] as String? ?? '').toLowerCase();
        return word.contains(q) || tr.contains(q) || en.contains(q);
      });
    }

    // 2. Missing-content filters (OR — match if missing any selected field)
    if (_missingFilters.isNotEmpty) {
      items = items.where((w) {
        for (final filter in _missingFilters) {
          switch (filter) {
            case 'audio':
              if (_isEmpty(w['audio_url'])) return true;
            case 'image':
              if (_isEmpty(w['image_url'])) return true;
            case 'tr':
              if (_isEmpty(w['meaning_tr'])) return true;
            case 'en':
              if (_isEmpty(w['meaning_en'])) return true;
            case 'example':
              if (_isEmptyList(w['example_sentences'])) return true;
          }
        }
        return false;
      });
    }

    // 3. Sort
    final list = items.toList();
    switch (_sortMode) {
      case _WordlistSortMode.manual:
        // Already in order_index order from _loadWordList; nothing to do.
        break;
      case _WordlistSortMode.alphabetic:
        list.sort((a, b) => (a['word'] as String? ?? '')
            .toLowerCase()
            .compareTo((b['word'] as String? ?? '').toLowerCase()));
      case _WordlistSortMode.mostIncomplete:
        int missingCount(Map<String, dynamic> w) {
          var n = 0;
          if (_isEmpty(w['audio_url'])) n++;
          if (_isEmpty(w['image_url'])) n++;
          if (_isEmpty(w['meaning_tr'])) n++;
          if (_isEmpty(w['meaning_en'])) n++;
          if (_isEmpty(w['phonetic'])) n++;
          if (_isEmptyList(w['example_sentences'])) n++;
          return n;
        }

        list.sort((a, b) => missingCount(b).compareTo(missingCount(a)));
      case _WordlistSortMode.recentlyAdded:
        list.sort((a, b) {
          final aDate = a['created_at'] as String? ?? '';
          final bDate = b['created_at'] as String? ?? '';
          return bDate.compareTo(aDate); // newest first
        });
    }

    return list;
  }

  /// Returns aggregated content-completion stats for the full word list.
  ({int total, int audio, int image, int complete}) _computeStats() {
    int audio = 0;
    int image = 0;
    int complete = 0;
    for (final w in _wordItems) {
      final hasAudio = !_isEmpty(w['audio_url']);
      final hasImage = !_isEmpty(w['image_url']);
      final hasMeaningEn = !_isEmpty(w['meaning_en']);
      final hasPhonetic = !_isEmpty(w['phonetic']);
      final hasExamples = !_isEmptyList(w['example_sentences']);
      if (hasAudio) audio++;
      if (hasImage) image++;
      if (hasAudio && hasImage && hasMeaningEn && hasPhonetic && hasExamples) {
        complete++;
      }
    }
    return (total: _wordItems.length, audio: audio, image: image, complete: complete);
  }

  @override
  void initState() {
    super.initState();
    if (!isNewList) {
      _loadWordList();
    }
  }

  Future<void> _loadWordList() async {
    setState(() => _isLoading = true);

    // Fetch directly from Supabase to avoid stale provider cache
    final supabase = ref.read(supabaseClientProvider);
    final wordlist = await supabase
        .from(DbTables.wordLists)
        .select('*, word_list_items(id, order_index, vocabulary_words(*))')
        .eq('id', widget.listId!)
        .maybeSingle();

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
    _listSearchController.dispose();
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

      // Update word items — only sync if we have items loaded
      // Guard: never delete all items when _wordItems is empty (prevents data loss from stale state)
      if (_wordItems.isNotEmpty) {
        await supabase.from(DbTables.wordListItems).delete().eq('word_list_id', listId);

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
      _contentProgress = 'AI üretiyor...';
    });

    int successCount = 0;
    int failCount = 0;
    final failedWords = <String>[];
    final supabase = ref.read(supabaseClientProvider);

    try {
      // Single batch call with all incomplete words
      final wordNames = incompleteWords
          .map((w) => w['word'] as String? ?? '')
          .where((w) => w.isNotEmpty)
          .toList();

      final response = await supabase.functions.invoke(
        'generate-word-data',
        body: {'words': wordNames},
      );

      if (response.status != 200) {
        final errMsg = response.data is Map
            ? (response.data as Map)['error'] ?? 'status ${response.status}'
            : 'status ${response.status}';
        debugPrint('generate-word-data batch FAIL: $errMsg');
        failCount = incompleteWords.length;
        failedWords.add('Toplu üretim hatası: $errMsg');
      } else {
        final data = response.data as Map<String, dynamic>?;
        final results = (data?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Match results back to words by the 'word' field
        for (final word in incompleteWords) {
          final wordName = (word['word'] as String? ?? '').trim().toLowerCase();
          final result = results.firstWhere(
            (r) => (r['word'] as String? ?? '').trim().toLowerCase() == wordName,
            orElse: () => <String, dynamic>{},
          );

          if (result.isEmpty) {
            failedWords.add('$wordName (AI sonucu bulunamadı)');
            failCount++;
            continue;
          }

          final updates = <String, dynamic>{};
          if (_isEmpty(word['meaning_tr']) && result['meaning_tr'] != null) {
            updates['meaning_tr'] = result['meaning_tr'];
          }
          if (_isEmpty(word['meaning_en']) && result['meaning_en'] != null) {
            updates['meaning_en'] = result['meaning_en'];
          }
          if (_isEmpty(word['phonetic']) && result['phonetic'] != null) {
            updates['phonetic'] = result['phonetic'];
          }
          if (_isEmptyList(word['example_sentences']) &&
              result['example_sentences'] != null) {
            updates['example_sentences'] = result['example_sentences'];
          }
          if (_isEmpty(word['part_of_speech']) &&
              result['part_of_speech'] != null) {
            updates['part_of_speech'] = result['part_of_speech'];
          }

          if (updates.isNotEmpty) {
            await supabase
                .from(DbTables.vocabularyWords)
                .update(updates)
                .eq('id', word['id']);
          }
          successCount++;

          if (mounted) {
            setState(() {
              _contentProgress =
                  '$successCount/${incompleteWords.length}';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('generate-word-data batch EXCEPTION: $e');
      failedWords.add('$e');
      failCount = incompleteWords.length - successCount;
    }

    if (mounted) {
      setState(() {
        _isGeneratingContent = false;
        _contentProgress = '';
      });
      // Always surface a brief snackbar; if there were failures, also show
      // a dialog so the operator can copy the failed-word list.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount > 0
                ? '$successCount güncellendi · $failCount başarısız'
                : '$successCount kelime güncellendi',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      if (failCount > 0 && failedWords.isNotEmpty) {
        _showFailedWordsDialog(failedWords);
      }
      ref.invalidate(wordlistDetailProvider(widget.listId!));
      _loadWordList();
    }
  }

  /// Exports the current wordlist as a CSV file via browser download.
  /// Includes one row per word with all primary content fields.
  void _exportCsv() {
    if (_wordItems.isEmpty) return;

    final rows = <List<dynamic>>[
      ['word', 'meaning_tr', 'meaning_en', 'phonetic', 'audio_url',
        'image_url', 'example_sentences', 'part_of_speech'],
      ..._wordItems.map((w) => [
            w['word'] ?? '',
            w['meaning_tr'] ?? '',
            w['meaning_en'] ?? '',
            w['phonetic'] ?? '',
            w['audio_url'] ?? '',
            w['image_url'] ?? '',
            // Example sentences as pipe-separated single cell
            (w['example_sentences'] as List?)
                    ?.map((e) => e.toString())
                    .join(' | ') ??
                '',
            w['part_of_speech'] ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode('﻿$csv'); // BOM for Excel UTF-8

    final listName = _nameController.text.trim().isNotEmpty
        ? _nameController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        : 'wordlist';
    final filename = '${listName}_${_wordItems.length}_kelime.csv';

    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_wordItems.length} kelime CSV olarak indirildi'),
        ),
      );
    }
  }

  /// Regenerates AI content for a single word (phonetic / meaning / examples)
  /// without touching other words. Uses the same `generate-word-data` edge
  /// function as bulk gen but with a 1-element word array.
  Future<void> _regenerateWordContent(int index) async {
    final word = _wordItems[index];
    final wordName = (word['word'] as String? ?? '').trim();
    if (wordName.isEmpty) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$wordName" için AI içerik üretiliyor…'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'generate-word-data',
        body: {
          'words': [wordName]
        },
      );

      if (response.status != 200) {
        throw Exception(
            'Edge function status ${response.status}: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>?;
      final results =
          (data?['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (results.isEmpty) {
        throw Exception('AI sonucu yok');
      }

      final result = results.first;
      final updates = <String, dynamic>{};
      if (_isEmpty(word['meaning_tr']) && result['meaning_tr'] != null) {
        updates['meaning_tr'] = result['meaning_tr'];
      }
      if (_isEmpty(word['meaning_en']) && result['meaning_en'] != null) {
        updates['meaning_en'] = result['meaning_en'];
      }
      if (_isEmpty(word['phonetic']) && result['phonetic'] != null) {
        updates['phonetic'] = result['phonetic'];
      }
      if (_isEmptyList(word['example_sentences']) &&
          result['example_sentences'] != null) {
        updates['example_sentences'] = result['example_sentences'];
      }
      if (_isEmpty(word['part_of_speech']) &&
          result['part_of_speech'] != null) {
        updates['part_of_speech'] = result['part_of_speech'];
      }

      if (updates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$wordName" için doldurulacak alan yok'),
            ),
          );
        }
        return;
      }

      await supabase
          .from(DbTables.vocabularyWords)
          .update(updates)
          .eq('id', word['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"$wordName" güncellendi (${updates.length} alan)',
            ),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(wordlistDetailProvider(widget.listId!));
        _loadWordList();
      }
    } catch (e) {
      debugPrint('Per-word regen FAIL ($wordName): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İçerik üretilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFailedWordsDialog(List<String> failedWords) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Başarısız Kelimeler'),
          ],
        ),
        content: ConstrainedBox(
          constraints:
              const BoxConstraints(maxHeight: 360, maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${failedWords.length} kelime AI ile doldurulamadı. '
                'Manuel olarak düzenleyebilirsin:',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    failedWords.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
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

  Future<void> _clearAllContent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İçerikleri Temizle'),
        content: Text(
          '${_wordItems.length} kelimenin tüm içerikleri (anlam, phonetic, örnek cümleler) '
          'temizlenecek. Ses ve görsel korunur.\n\n'
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final wordIds = _wordItems
          .map((w) => w['id'] as String)
          .toList();

      await supabase
          .from(DbTables.vocabularyWords)
          .update({
            'meaning_tr': null,
            'meaning_en': null,
            'phonetic': null,
            'part_of_speech': null,
            'example_sentences': null,
          })
          .inFilter('id', wordIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${wordIds.length} kelimenin içeriği temizlendi'),
            backgroundColor: Colors.orange,
          ),
        );
        ref.invalidate(wordlistDetailProvider(widget.listId!));
        _loadWordList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  Future<void> _handleClone() async {
    if (widget.listId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kelime Listesini Klonla'),
        content: const Text(
          'Bu kelime listesi tüm kelimeleriyle birlikte kopyalanacak. '
          'Kopya, "(Kopya)" eki ile yeni bir liste olarak oluşturulacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Klonla'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Fetch original wordlist row
      final original = await supabase
          .from(DbTables.wordLists)
          .select()
          .eq('id', widget.listId!)
          .single();

      // Insert clone with new id, suffixed name, fresh timestamps
      final newId = const Uuid().v4();
      final cloneData = Map<String, dynamic>.from(original);
      cloneData['id'] = newId;
      cloneData['name'] = '${original['name']} (Kopya)';
      cloneData.remove('created_at');
      cloneData.remove('updated_at');
      await supabase.from(DbTables.wordLists).insert(cloneData);

      // Fetch and copy word_list_items
      final items = await supabase
          .from(DbTables.wordListItems)
          .select('word_id, order_index')
          .eq('word_list_id', widget.listId!);

      if (items.isNotEmpty) {
        final itemRows = (items as List<dynamic>)
            .map((it) => {
                  'id': const Uuid().v4(),
                  'word_list_id': newId,
                  'word_id': (it as Map<String, dynamic>)['word_id'],
                  'order_index': it['order_index'],
                })
            .toList();
        await supabase.from(DbTables.wordListItems).insert(itemRows);
      }

      ref.invalidate(wordlistsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste klonlandı')),
        );
        context.go('/wordlists/$newId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klonlama başarısız: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddWordDialog() {
    _searchController.clear();

    showDialog(
      context: context,
      builder: (context) => _AddWordDialog(
        searchController: _searchController,
        existingWordIds:
            _wordItems.map((w) => w['id'] as String).toSet(),
        onWordsSelected: (words) {
          if (words.isEmpty) return;
          final existingIds =
              _wordItems.map((w) => w['id'] as String).toSet();
          final fresh = words
              .where((w) => !existingIds.contains(w['id']))
              .toList();
          if (fresh.isEmpty) return;
          setState(() => _wordItems.addAll(fresh));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                fresh.length == 1
                    ? '1 kelime eklendi'
                    : '${fresh.length} kelime eklendi',
              ),
            ),
          );
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

  Widget _missingChip(String label, String key, IconData icon) {
    final selected = _missingFilters.contains(key);
    return FilterChip(
      avatar: Icon(
        icon,
        size: 14,
        color: selected ? Colors.red.shade700 : Colors.grey.shade600,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (s) {
        setState(() {
          if (s) {
            _missingFilters.add(key);
          } else {
            _missingFilters.remove(key);
          }
        });
      },
    );
  }

  Widget _buildStatsBadges() {
    final s = _computeStats();
    if (s.total == 0) return const SizedBox.shrink();
    int pct(int n) => ((n / s.total) * 100).round();

    Widget badge(String label, int n, Color color) {
      final percent = pct(n);
      return Tooltip(
        message: '$n / ${s.total}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '$label %$percent',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        badge('Ses', s.audio, Colors.blue.shade700),
        badge('Görsel', s.image, Colors.green.shade700),
        badge('Tamam', s.complete, Colors.indigo.shade700),
      ],
    );
  }

  Widget _buildGenerateMenu() {
    // Active-job label override — keep operator informed of in-flight work.
    String? activeLabel;
    if (_isGeneratingAudio) {
      activeLabel = 'Ses üretiliyor…';
    } else if (_isGeneratingContent) {
      activeLabel = _contentProgress.isEmpty
          ? 'İçerik üretiliyor…'
          : 'İçerik $_contentProgress';
    } else if (_isGeneratingImages) {
      activeLabel = 'Görsel üretiliyor…';
    }

    final disabled = _isAnyGenerationActive;

    return PopupMenuButton<String>(
      tooltip: 'Üret menüsü',
      enabled: !disabled,
      onSelected: (value) {
        switch (value) {
          case 'audio':
            _generateWordlistAudio();
          case 'images':
            _showImageGenerationDialog();
          case 'content':
            _generateBulkContent();
          case 'clear':
            _clearAllContent();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'audio',
          child: ListTile(
            leading: Icon(Icons.volume_up),
            title: Text('Sesleri Üret'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'images',
          child: ListTile(
            leading: Icon(Icons.image),
            title: Text('Görselleri Üret'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'content',
          child: ListTile(
            leading: Icon(Icons.auto_fix_high),
            title: Text('İçerikleri Üret'),
            subtitle: Text(
              'Phonetic + anlam + örnekler',
              style: TextStyle(fontSize: 11),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          child: ListTile(
            leading: Icon(Icons.cleaning_services,
                color: Colors.orange.shade700),
            title: Text(
              'İçerikleri Temizle',
              style: TextStyle(color: Colors.orange.shade700),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.indigo.shade50
              : Colors.indigo.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (disabled)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.auto_fix_high,
                  size: 18, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              activeLabel ?? 'Üret',
              style: const TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!disabled) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down,
                  size: 18, color: Colors.indigo),
            ],
          ],
        ),
      ),
    );
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
    return EditScreenShortcuts(
      onSave: _isSaving ? null : _handleSave,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewList ? 'Yeni Kelime Listesi' : 'Kelime Listesini Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vocabulary'),
        ),
        actions: [
          if (!isNewList && _wordItems.isNotEmpty) _buildGenerateMenu(),
          const SizedBox(width: 8),
          if (!isNewList)
            IconButton(
              tooltip: 'CSV Yükle',
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: () =>
                  context.go('/wordlists/${widget.listId}/import'),
            ),
          if (!isNewList && _wordItems.isNotEmpty)
            IconButton(
              tooltip: 'CSV İndir',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _exportCsv,
            ),
          if (!isNewList)
            IconButton(
              tooltip: 'Klonla',
              icon: const Icon(Icons.content_copy_outlined),
              onPressed: _isSaving ? null : _handleClone,
            ),
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

                // Header bar (title + add) + stats + search row
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  color: Colors.grey.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Kelimeler (${_wordItems.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 16),
                          if (_wordItems.isNotEmpty) _buildStatsBadges(),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _showAddWordDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Kelime Ekle'),
                          ),
                        ],
                      ),
                      if (_wordItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _listSearchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Kelimelerde ara (kelime / TR / EN anlamı)…',
                                    prefixIcon:
                                        const Icon(Icons.search, size: 18),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: _listSearchQuery.isEmpty
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 18),
                                            onPressed: () {
                                              _listSearchController.clear();
                                              setState(() =>
                                                  _listSearchQuery = '');
                                            },
                                          ),
                                  ),
                                  onChanged: (v) => setState(
                                      () => _listSearchQuery = v.trim()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Sort selector
                            SizedBox(
                              width: 200,
                              child:
                                  DropdownButtonFormField<_WordlistSortMode>(
                                value: _sortMode,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Sıralama',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: _WordlistSortMode.values
                                    .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m.label),
                                        ))
                                    .toList(),
                                onChanged: (m) => setState(() =>
                                    _sortMode =
                                        m ?? _WordlistSortMode.manual),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Missing-content filter chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _missingChip(
                                'Ses eksik', 'audio', Icons.volume_off),
                            _missingChip('Görsel eksik', 'image',
                                Icons.hide_image),
                            _missingChip(
                                'TR eksik', 'tr', Icons.language),
                            _missingChip(
                                'EN eksik', 'en', Icons.translate),
                            _missingChip('Örnek eksik', 'example',
                                Icons.format_quote),
                            if (_missingFilters.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => setState(
                                    () => _missingFilters.clear()),
                                icon: const Icon(Icons.clear, size: 14),
                                label: const Text('Filtreleri temizle',
                                    style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                      ],
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
                      : Builder(builder: (_) {
                          final filtered = _filteredWordItems;
                          if (filtered.isEmpty && _listSearchQuery.isNotEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    '"$_listSearchQuery" için kelime bulunamadı',
                                    style: TextStyle(
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          }
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: filtered.map((word) {
                                final index = _wordItems.indexOf(word);
                                return _WordCard(
                                  key: ValueKey(word['id']),
                                  word: word,
                                  index: index,
                                  total: _wordItems.length,
                                  onRemove: () => _removeWord(index),
                                  onMoveLeft: index > 0
                                      ? () => _moveWord(index, index - 1)
                                      : null,
                                  onMoveRight:
                                      index < _wordItems.length - 1
                                          ? () =>
                                              _moveWord(index, index + 2)
                                          : null,
                                  onSaveField: (field, value) =>
                                      _saveWordField(index, field, value),
                                  onTap: () => context
                                      .push('/vocabulary/${word['id']}')
                                      .then((_) {
                                    ref.invalidate(wordlistDetailProvider(
                                        widget.listId!));
                                    _loadWordList();
                                  }),
                                  onRegenerateContent: () =>
                                      _regenerateWordContent(index),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                ),

                // Bottom: Content completeness table
                if (_wordItems.isNotEmpty)
                  _WordContentTable(
                    wordItems: _wordItems,
                    onWordTap: (wordId) => context.push('/vocabulary/$wordId').then((_) {
                      ref.invalidate(wordlistDetailProvider(widget.listId!));
                      _loadWordList();
                    }),
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
    required this.onRegenerateContent,
  });

  final Map<String, dynamic> word;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final Future<void> Function(String field, dynamic value) onSaveField;
  final VoidCallback onTap;
  final Future<void> Function() onRegenerateContent;

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
                // Completeness ribbon — at-a-glance field-fill state
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ribbonIcon(Icons.volume_up, hasAudio),
                        _ribbonIcon(Icons.image, hasImage),
                        _ribbonText('TR', meaningTr.isNotEmpty),
                        _ribbonText('EN', meaningEn.isNotEmpty),
                        _ribbonIcon(
                          Icons.format_quote,
                          examples != null && examples.isNotEmpty,
                        ),
                      ],
                    ),
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
                        // Per-word actions menu
                        PopupMenuButton<String>(
                          tooltip: 'Eylemler',
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: Icon(Icons.more_vert,
                              size: 16, color: Colors.grey.shade500),
                          onSelected: (value) {
                            if (value == 'regenerate') {
                              widget.onRegenerateContent();
                            } else if (value == 'open') {
                              widget.onTap();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'regenerate',
                              child: ListTile(
                                leading: Icon(Icons.auto_fix_high,
                                    size: 18),
                                title: Text(
                                  'AI ile içerik tamamla',
                                  style: TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  'Sadece bu kelime',
                                  style: TextStyle(fontSize: 11),
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'open',
                              child: ListTile(
                                leading: Icon(Icons.open_in_new, size: 18),
                                title: Text(
                                  'Detayda aç',
                                  style: TextStyle(fontSize: 13),
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
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

  Widget _ribbonIcon(IconData icon, bool hasValue) {
    return Tooltip(
      message: hasValue ? 'Var' : 'Eksik',
      child: Icon(
        icon,
        size: 12,
        color: hasValue
            ? Colors.greenAccent.shade400
            : Colors.redAccent.shade100,
      ),
    );
  }

  Widget _ribbonText(String label, bool hasValue) {
    return Tooltip(
      message: hasValue ? '$label var' : '$label eksik',
      child: SizedBox(
        width: 18,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: hasValue
                ? Colors.greenAccent.shade400
                : Colors.redAccent.shade100,
          ),
        ),
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
    required this.existingWordIds,
    required this.onWordsSelected,
  });

  final TextEditingController searchController;

  /// Word IDs already in the parent wordlist — these are shown as
  /// "Zaten listede" and can't be selected.
  final Set<String> existingWordIds;

  /// Called once with all selected words when the operator commits via
  /// "N kelime ekle". Empty list means cancelled / nothing to add.
  final void Function(List<Map<String, dynamic>> words) onWordsSelected;

  @override
  ConsumerState<_AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends ConsumerState<_AddWordDialog> {
  String _searchQuery = '';
  bool _isCreating = false;

  /// Words selected for batch add. Insertion-ordered list keyed implicitly
  /// by `id`; checks use [_isSelected].
  final List<Map<String, dynamic>> _selected = [];

  bool _isSelected(String id) =>
      _selected.any((w) => w['id'] == id);

  void _toggle(Map<String, dynamic> word) {
    final id = word['id'] as String;
    setState(() {
      if (_isSelected(id)) {
        _selected.removeWhere((w) => w['id'] == id);
      } else {
        _selected.add(word);
      }
    });
  }

  Future<void> _createAndSelect(String wordText) async {
    setState(() => _isCreating = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final id = const Uuid().v4();
      final word = wordText.trim().toLowerCase();

      await supabase.from(DbTables.vocabularyWords).insert({
        'id': id,
        'word': word,
      });

      final created = <String, dynamic>{
        'id': id,
        'word': word,
        'meaning_tr': null,
        'meaning_en': null,
        'phonetic': null,
        'audio_url': null,
        'image_url': null,
        'example_sentences': null,
      };

      // Add to selection + clear search so the user can keep adding more.
      setState(() {
        _selected.add(created);
        widget.searchController.clear();
        _searchQuery = '';
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
      title: Row(
        children: [
          const Text('Kelime Ekle'),
          const Spacer(),
          if (_selected.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selected.length} seçili',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.indigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: widget.searchController,
              decoration: const InputDecoration(
                labelText: 'Kelime ara',
                hintText: 'Aramak için yazın…',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
            ),
            const SizedBox(height: 12),
            // Selected chips strip — quick at-a-glance + remove
            if (_selected.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final w = _selected[i];
                    return InputChip(
                      label: Text(
                        w['word'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () => _toggle(w),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: searchResults.when(
                data: (words) {
                  final hasExactMatch = _searchQuery.isNotEmpty &&
                      words.any((w) =>
                          (w['word'] as String?)?.toLowerCase() ==
                          _searchQuery.toLowerCase());

                  return Column(
                    children: [
                      // Header label: "Son eklenenler" or "X sonuç"
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 4, right: 4, bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              _searchQuery.isEmpty
                                  ? Icons.history
                                  : Icons.search,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Son eklenen kelimeler'
                                  : '${words.length} sonuç',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: words.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isEmpty
                                      ? 'Henüz kelime yok'
                                      : 'Sonuç bulunamadı',
                                  style: TextStyle(
                                      color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: words.length,
                                itemBuilder: (context, index) {
                                  final word = words[index];
                                  final id = word['id'] as String;
                                  final alreadyInList =
                                      widget.existingWordIds.contains(id);
                                  final isChecked = _isSelected(id);
                                  return ListTile(
                                    leading: Checkbox(
                                      value: alreadyInList || isChecked,
                                      onChanged: alreadyInList
                                          ? null
                                          : (_) => _toggle(word),
                                    ),
                                    title: Text(word['word'] ?? ''),
                                    subtitle: alreadyInList
                                        ? Text(
                                            'Zaten listede',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.grey.shade500,
                                              fontStyle:
                                                  FontStyle.italic,
                                            ),
                                          )
                                        : Text(
                                            (word['meaning_tr'] as String?) ??
                                                '',
                                          ),
                                    trailing: Text(
                                      (word['level'] as String?) ?? '',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    enabled: !alreadyInList,
                                    onTap: alreadyInList
                                        ? null
                                        : () => _toggle(word),
                                  );
                                },
                              ),
                      ),
                      if (!hasExactMatch) ...[
                        const Divider(height: 1),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: FilledButton.icon(
                            onPressed: _isCreating
                                ? null
                                : () => _createAndSelect(_searchQuery),
                            icon: _isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add, size: 18),
                            label: Text(
                              _isCreating
                                  ? 'Oluşturuluyor…'
                                  : '"$_searchQuery" oluştur ve seç',
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Hata: $error')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onWordsSelected(const []);
            Navigator.pop(context);
          },
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  widget.onWordsSelected(List.of(_selected));
                  Navigator.pop(context);
                },
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            _selected.isEmpty
                ? 'Kelime ekle'
                : '${_selected.length} kelime ekle',
          ),
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
