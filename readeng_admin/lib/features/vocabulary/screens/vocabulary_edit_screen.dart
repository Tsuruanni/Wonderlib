import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:readeng_shared/readeng_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'vocabulary_list_screen.dart';

/// Provider for loading a single vocabulary word
final wordDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, wordId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyWords)
      .select()
      .eq('id', wordId)
      .maybeSingle();

  return response;
});

class VocabularyEditScreen extends ConsumerStatefulWidget {
  const VocabularyEditScreen({super.key, this.wordId});

  final String? wordId;

  @override
  ConsumerState<VocabularyEditScreen> createState() => _VocabularyEditScreenState();
}

class _VocabularyEditScreenState extends ConsumerState<VocabularyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _phoneticController = TextEditingController();
  final _meaningTrController = TextEditingController();
  final _meaningEnController = TextEditingController();
  final _audioUrlController = TextEditingController();
  final _imageUrlController = TextEditingController();

  static const _partsOfSpeech = [
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

  static final _levels = CEFRLevel.allValues;

  String _partOfSpeech = 'noun';
  String _level = 'B1';
  List<String> _exampleSentences = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPlaying = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool get isNewWord => widget.wordId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewWord) {
      _loadWord();
    }
  }

  Future<void> _loadWord() async {
    setState(() => _isLoading = true);

    final word = await ref.read(wordDetailProvider(widget.wordId!).future);
    if (word != null && mounted) {
      _wordController.text = word['word'] ?? '';
      _phoneticController.text = word['phonetic'] ?? '';
      _meaningTrController.text = word['meaning_tr'] ?? '';
      _meaningEnController.text = word['meaning_en'] ?? '';
      _audioUrlController.text = word['audio_url'] ?? '';
      _imageUrlController.text = word['image_url'] ?? '';
      setState(() {
        _partOfSpeech = word['part_of_speech'] ?? 'noun';
        _level = word['level'] ?? 'B1';
        _exampleSentences = List<String>.from(word['example_sentences'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _phoneticController.dispose();
    _meaningTrController.dispose();
    _meaningEnController.dispose();
    _audioUrlController.dispose();
    _imageUrlController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'word': _wordController.text.trim().toLowerCase(),
        'phonetic': _phoneticController.text.trim(),
        'part_of_speech': _partOfSpeech,
        'meaning_tr': _meaningTrController.text.trim(),
        'meaning_en': _meaningEnController.text.trim(),
        'audio_url': _audioUrlController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'level': _level,
        'example_sentences': _exampleSentences,
      };

      if (isNewWord) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.vocabularyWords).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word created successfully')),
          );
          ref.invalidate(vocabularyProvider);
          context.go('/vocabulary/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.vocabularyWords).update(data).eq('id', widget.wordId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Word saved successfully')),
          );
          ref.invalidate(wordDetailProvider(widget.wordId!));
          ref.invalidate(vocabularyProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: const Text(
          'Are you sure you want to delete this word? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.vocabularyWords).delete().eq('id', widget.wordId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Word deleted')),
        );
        ref.invalidate(vocabularyProvider);
        context.go('/vocabulary');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _playAudio() async {
    if (_audioUrlController.text.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);
        await _audioPlayer.setUrl(_audioUrlController.text);
        await _audioPlayer.play();
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isPlaying = false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addExampleSentence() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Example Sentence'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter example sentence',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _exampleSentences.add(result.trim());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewWord ? 'New Word' : 'Edit Word'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vocabulary'),
        ),
        actions: [
          if (!isNewWord)
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
                : Text(isNewWord ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Word Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Word
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _wordController,
                            decoration: const InputDecoration(
                              labelText: 'Word',
                              hintText: 'Enter the word',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Word is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Phonetic
                        Expanded(
                          child: TextFormField(
                            controller: _phoneticController,
                            decoration: const InputDecoration(
                              labelText: 'Phonetic',
                              hintText: '/fəˈnetɪk/',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Part of speech
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _partOfSpeech,
                            decoration: const InputDecoration(
                              labelText: 'Part of Speech',
                            ),
                            items: _partsOfSpeech.map((pos) {
                              return DropdownMenuItem(
                                value: pos,
                                child: Text(pos[0].toUpperCase() + pos.substring(1)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _partOfSpeech = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Level
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _level,
                            decoration: const InputDecoration(
                              labelText: 'CEFR Level',
                            ),
                            items: _levels.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(level),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _level = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Meanings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Meaning TR
                    TextFormField(
                      controller: _meaningTrController,
                      decoration: const InputDecoration(
                        labelText: 'Meaning (Turkish)',
                        hintText: 'Enter Turkish meaning',
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Turkish meaning is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Meaning EN
                    TextFormField(
                      controller: _meaningEnController,
                      decoration: const InputDecoration(
                        labelText: 'Meaning (English)',
                        hintText: 'Enter English meaning (optional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Example sentences
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Example Sentences',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton.icon(
                          onPressed: _addExampleSentence,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_exampleSentences.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Text(
                              'No example sentences yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_exampleSentences.length, (index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(_exampleSentences[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              onPressed: () {
                                setState(() {
                                  _exampleSentences.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    Text(
                      'Media',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Audio URL
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _audioUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Audio URL',
                              hintText: 'https://...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed:
                              _audioUrlController.text.isEmpty ? null : _playAudio,
                          icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                          color: const Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Image URL
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL',
                        hintText: 'https://...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
