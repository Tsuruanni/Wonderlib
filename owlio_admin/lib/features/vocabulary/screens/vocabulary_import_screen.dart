import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../../core/widgets/csv_import_dialog.dart';
import 'vocabulary_list_screen.dart';

class VocabularyImportScreen extends ConsumerWidget {
  const VocabularyImportScreen({super.key});

  static const expectedHeaders = [
    'word',
    'phonetic',
    'part_of_speech',
    'meaning_tr',
    'meaning_en',
    'level',
  ];

  static const requiredHeaders = ['word', 'meaning_tr'];

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
        title: const Text('Kelime İçe Aktar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vocabulary'),
        ),
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
                'CSV\'den Kelime İçe Aktar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Kelimeleri toplu olarak içe aktarmak veya güncellemek için CSV dosyası yükleyin.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showImportDialog(context, ref),
                icon: const Icon(Icons.upload),
                label: const Text('CSV Dosyası Seç'),
              ),
              const SizedBox(height: 32),

              // Format info
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
                        Icon(Icons.info_outline, color: Colors.green.shade700),
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
                      'Zorunlu sütunlar: word, meaning_tr',
                      style: TextStyle(color: Colors.green.shade900),
                    ),
                    Text(
                      'Opsiyonel sütunlar: phonetic, part_of_speech, meaning_en, level',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'word,phonetic,part_of_speech,meaning_tr,meaning_en,level\n'
                        'apple,/ˈæp.əl/,noun,elma,a round fruit,A1\n'
                        'run,/rʌn/,verb,koşmak,to move fast,A1',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Geçerli seviyeler: ${validLevels.join(', ')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Geçerli sözcük türleri: ${validPartsOfSpeech.join(', ')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CsvImportDialog(
        title: 'Kelime İçe Aktar',
        expectedHeaders: expectedHeaders,
        requiredHeaders: requiredHeaders,
        processRow: (row) => _processRow(row, ref),
        onComplete: () {
          ref.invalidate(vocabularyProvider);
        },
      ),
    );
  }

  Future<String?> _processRow(Map<String, String> row, WidgetRef ref) async {
    final supabase = ref.read(supabaseClientProvider);

    final word = row['word']?.trim().toLowerCase();
    final meaningTr = row['meaning_tr']?.trim();
    final phonetic = row['phonetic']?.trim();
    final partOfSpeech = row['part_of_speech']?.trim().toLowerCase();
    final meaningEn = row['meaning_en']?.trim();
    final level = row['level']?.trim().toUpperCase();

    // Validate word
    if (word == null || word.isEmpty) {
      return 'Kelime zorunludur';
    }

    // Validate meaning_tr
    if (meaningTr == null || meaningTr.isEmpty) {
      return 'Türkçe anlam zorunludur';
    }

    // Validate level if provided
    if (level != null && level.isNotEmpty && !validLevels.contains(level)) {
      return 'Geçersiz seviye: $level (${validLevels.join(', ')} olmalıdır)';
    }

    // Validate part_of_speech if provided
    if (partOfSpeech != null &&
        partOfSpeech.isNotEmpty &&
        !validPartsOfSpeech.contains(partOfSpeech)) {
      return 'Geçersiz sözcük türü: $partOfSpeech';
    }

    // Check if word already exists
    final existing = await supabase
        .from(DbTables.vocabularyWords)
        .select('id')
        .eq('word', word)
        .maybeSingle();

    final data = <String, dynamic>{
      'word': word,
      'meaning_tr': meaningTr,
      if (phonetic != null && phonetic.isNotEmpty) 'phonetic': phonetic,
      if (partOfSpeech != null && partOfSpeech.isNotEmpty)
        'part_of_speech': partOfSpeech,
      if (meaningEn != null && meaningEn.isNotEmpty) 'meaning_en': meaningEn,
      if (level != null && level.isNotEmpty) 'level': level,
    };

    if (existing != null) {
      // Update existing word
      await supabase.from(DbTables.vocabularyWords).update(data).eq('id', existing['id']);
    } else {
      // Insert new word
      data['id'] = const Uuid().v4();
      await supabase.from(DbTables.vocabularyWords).insert(data);
    }

    return null; // Success
  }
}
