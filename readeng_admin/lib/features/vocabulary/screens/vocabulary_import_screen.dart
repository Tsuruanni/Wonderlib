import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  static const validLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

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
        title: const Text('Import Vocabulary'),
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
                'Import Vocabulary from CSV',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a CSV file to bulk import or update vocabulary words.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showImportDialog(context, ref),
                icon: const Icon(Icons.upload),
                label: const Text('Select CSV File'),
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
                          'CSV Format',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Required columns: word, meaning_tr',
                      style: TextStyle(color: Colors.green.shade900),
                    ),
                    Text(
                      'Optional columns: phonetic, part_of_speech, meaning_en, level',
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
                      'Valid levels: ${validLevels.join(', ')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valid parts of speech: ${validPartsOfSpeech.join(', ')}',
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
        title: 'Import Vocabulary',
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
      return 'Word is required';
    }

    // Validate meaning_tr
    if (meaningTr == null || meaningTr.isEmpty) {
      return 'Turkish meaning is required';
    }

    // Validate level if provided
    if (level != null && level.isNotEmpty && !validLevels.contains(level)) {
      return 'Invalid level: $level (must be one of ${validLevels.join(', ')})';
    }

    // Validate part_of_speech if provided
    if (partOfSpeech != null &&
        partOfSpeech.isNotEmpty &&
        !validPartsOfSpeech.contains(partOfSpeech)) {
      return 'Invalid part of speech: $partOfSpeech';
    }

    // Check if word already exists
    final existing = await supabase
        .from('vocabulary_words')
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
      await supabase.from('vocabulary_words').update(data).eq('id', existing['id']);
    } else {
      // Insert new word
      data['id'] = const Uuid().v4();
      await supabase.from('vocabulary_words').insert(data);
    }

    return null; // Success
  }
}
