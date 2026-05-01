import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../../core/widgets/csv_import_dialog.dart';
import '../../../core/widgets/template_download_button.dart';
import '../../vocabulary/screens/vocabulary_import_screen.dart'
    show VocabularyImportScreen;
import '../../vocabulary/screens/vocabulary_list_screen.dart';
import 'wordlist_edit_screen.dart' show wordlistDetailProvider;

/// CSV import for a specific wordlist. Each row creates the vocabulary word
/// (if missing) and links it to this wordlist via `word_list_items`.
///
/// Behavior:
/// - Word matching is case-insensitive on the `word` column.
/// - If the word already exists, optional fields (meaning, phonetic, etc.)
///   are NOT overwritten — the row is treated as a "link existing" op.
/// - Duplicates within the same wordlist (already linked) are skipped.
class WordlistImportScreen extends ConsumerWidget {
  const WordlistImportScreen({super.key, required this.listId});

  final String listId;

  static const expectedHeaders = [
    'word',
    'meaning_tr',
    'meaning_en',
    'phonetic',
    'part_of_speech',
    'level',
    'example_sentences',
  ];

  static const requiredHeaders = ['word'];

  static final validLevels = CEFRLevel.allValues;

  static const validPartsOfSpeech = [
    'noun',
    'verb',
    'adjective',
    'adverb',
    'pronoun',
    'preposition',
    'conjunction',
    'interjection',
    'article',
    'determiner',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listeye CSV ile Kelime Ekle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/wordlists/$listId'),
        ),
        actions: const [
          TemplateDownloadButton(
            assetPath: 'assets/import_templates/wordlist_template.csv',
            downloadFilename: 'kelime_listesi_sablonu.csv',
            contentType: 'text/csv;charset=utf-8;',
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'CSV\'den Kelime Listesine Ekle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Sadece "word" kolonu zorunlu. Veritabanında olmayan kelimeler '
                  'otomatik oluşturulur, var olanlar bu listeye linklenir. '
                  'Listede zaten olan kelimeler atlanır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showImportDialog(context, ref),
                icon: const Icon(Icons.upload),
                label: const Text('CSV Dosyası Seç'),
              ),
              const SizedBox(height: 32),
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'CSV Formatı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Zorunlu sütun: word',
                      style: TextStyle(color: Colors.green.shade900),
                    ),
                    Text(
                      'Opsiyonel sütunlar: ${expectedHeaders.where((h) => h != 'word').join(', ')}',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'example_sentences için: birden çok örneği " | " ile ayır.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'word,meaning_tr,meaning_en,phonetic,part_of_speech,level,example_sentences\n'
                        'cat,kedi,a small furry animal,/kæt/,noun,A1,The cat is sleeping. | I have a cat.\n'
                        'happy,mutlu,feeling pleasure,/ˈhæp.i/,adjective,A1,She is happy.',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CsvImportDialog(
        title: 'Listeye Kelime Ekle',
        expectedHeaders: expectedHeaders,
        requiredHeaders: requiredHeaders,
        processRow: (row) => _processRow(row, ref),
        onComplete: () {
          ref.invalidate(wordlistDetailProvider(listId));
          ref.invalidate(wordlistsProvider);
        },
      ),
    );
  }

  Future<String?> _processRow(
      Map<String, String> row, WidgetRef ref) async {
    final supabase = ref.read(supabaseClientProvider);

    final word = row['word']?.trim().toLowerCase();
    if (word == null || word.isEmpty) return 'Kelime zorunludur';

    final meaningTr = row['meaning_tr']?.trim();
    final meaningEn = row['meaning_en']?.trim();
    final phonetic = row['phonetic']?.trim();
    final partOfSpeech = row['part_of_speech']?.trim().toLowerCase();
    final level = row['level']?.trim().toUpperCase();
    final examples = VocabularyImportScreen.parseExamples(row['example_sentences']);

    if (level != null && level.isNotEmpty && !validLevels.contains(level)) {
      return 'Geçersiz seviye: $level';
    }
    if (partOfSpeech != null &&
        partOfSpeech.isNotEmpty &&
        !VocabularyImportScreen.isValidPartOfSpeech(partOfSpeech)) {
      return 'Geçersiz sözcük türü: $partOfSpeech';
    }

    // 1. Check if word exists in vocabulary_words
    final existing = await supabase
        .from(DbTables.vocabularyWords)
        .select('id')
        .eq('word', word)
        .maybeSingle();

    String wordId;
    if (existing == null) {
      // Create new vocabulary word with whatever optional fields were provided
      wordId = const Uuid().v4();
      final newWord = <String, dynamic>{
        'id': wordId,
        'word': word,
        if (meaningTr != null && meaningTr.isNotEmpty)
          'meaning_tr': meaningTr,
        if (meaningEn != null && meaningEn.isNotEmpty)
          'meaning_en': meaningEn,
        if (phonetic != null && phonetic.isNotEmpty) 'phonetic': phonetic,
        if (partOfSpeech != null && partOfSpeech.isNotEmpty)
          'part_of_speech': partOfSpeech,
        if (level != null && level.isNotEmpty) 'level': level,
        if (examples.isNotEmpty) 'example_sentences': examples,
      };
      await supabase.from(DbTables.vocabularyWords).insert(newWord);
    } else {
      wordId = existing['id'] as String;
    }

    // 2. Check if word is already in this wordlist
    final alreadyLinked = await supabase
        .from(DbTables.wordListItems)
        .select('id')
        .eq('word_list_id', listId)
        .eq('word_id', wordId)
        .maybeSingle();

    if (alreadyLinked != null) {
      // Not an error — silently skip (or count as "already in list")
      return null;
    }

    // 3. Determine next order_index for this list
    final maxRow = await supabase
        .from(DbTables.wordListItems)
        .select('order_index')
        .eq('word_list_id', listId)
        .order('order_index', ascending: false)
        .limit(1)
        .maybeSingle();
    final nextOrder = ((maxRow?['order_index'] as int?) ?? -1) + 1;

    // 4. Link to wordlist
    await supabase.from(DbTables.wordListItems).insert({
      'id': const Uuid().v4(),
      'word_list_id': listId,
      'word_id': wordId,
      'order_index': nextOrder,
    });

    return null;
  }
}
