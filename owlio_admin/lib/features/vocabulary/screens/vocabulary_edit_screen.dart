import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:owlio_shared/owlio_shared.dart';
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
    'phrase',
  ];

  static final _levels = CEFRLevel.allValues;

  String _partOfSpeech = 'noun';
  String _level = 'B1';
  List<String> _exampleSentences = [];
  int? _audioStartMs;
  int? _audioEndMs;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPlaying = false;
  bool _isGenerating = false;
  String _source = 'manual';
  bool _isPhrase = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool get isNewWord => widget.wordId == null;

  void _checkPhrase() {
    final isPhrase = _wordController.text.trim().contains(' ');
    if (isPhrase != _isPhrase) {
      setState(() => _isPhrase = isPhrase);
    }
  }

  @override
  void initState() {
    super.initState();
    _wordController.addListener(_checkPhrase);
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
        _audioStartMs = word['audio_start_ms'] as int?;
        _audioEndMs = word['audio_end_ms'] as int?;
        _source = word['source'] as String? ?? 'manual';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _wordController.removeListener(_checkPhrase);
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
            const SnackBar(content: Text('Kelime başarıyla oluşturuldu')),
          );
          ref.invalidate(vocabularyProvider);
          context.go('/vocabulary/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.vocabularyWords).update(data).eq('id', widget.wordId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kelime başarıyla kaydedildi')),
          );
          ref.invalidate(wordDetailProvider(widget.wordId!));
          ref.invalidate(vocabularyProvider);
          _loadWord();
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

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kelimeyi Sil'),
        content: const Text(
          'Bu kelimeyi silmek istediğinizden emin misiniz? '
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
      await supabase.from(DbTables.vocabularyWords).delete().eq('id', widget.wordId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kelime silindi')),
        );
        ref.invalidate(vocabularyProvider);
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

  Future<void> _playAudio() async {
    if (_audioUrlController.text.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);

        final uri = Uri.parse(_audioUrlController.text);

        // Use ClippingAudioSource for segment playback
        if (_audioStartMs != null && _audioEndMs != null) {
          await _audioPlayer.setAudioSource(
            ClippingAudioSource(
              child: AudioSource.uri(uri),
              start: Duration(milliseconds: _audioStartMs!),
              end: Duration(milliseconds: _audioEndMs! + 200),
            ),
          );
        } else {
          await _audioPlayer.setUrl(_audioUrlController.text);
        }

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
          SnackBar(content: Text('Ses çalma hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateWithAI() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce kelimeyi girin')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'generate-word-data',
        body: {'word': word},
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Bilinmeyen hata';
        throw Exception(error);
      }

      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _phoneticController.text = data['phonetic'] as String? ?? '';
          _meaningTrController.text = data['meaning_tr'] as String? ?? '';
          _meaningEnController.text = data['meaning_en'] as String? ?? '';

          final pos = data['part_of_speech'] as String? ?? '';
          if (_partsOfSpeech.contains(pos)) {
            _partOfSpeech = pos;
          }

          final sentences = data['example_sentences'] as List<dynamic>? ?? [];
          _exampleSentences = sentences
              .map((s) => s.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI ile dolduruldu — kontrol edip kaydedin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _addExampleSentence() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Örnek Cümle Ekle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Örnek cümle girin',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Ekle'),
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
        title: Text(isNewWord ? 'Yeni Kelime' : 'Kelime Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/vocabulary'),
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
                : Text(isNewWord ? 'Oluştur' : 'Kaydet'),
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
                      'Kelime Bilgileri',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    if (!isNewWord && _source != 'manual') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _source == 'activity' ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _source == 'activity' ? Icons.quiz : Icons.upload,
                              size: 16,
                              color: _source == 'activity' ? Colors.purple : Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _source == 'activity' ? 'Aktiviteden eklendi' : 'CSV\'den içe aktarıldı',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _source == 'activity' ? Colors.purple : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Word
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _wordController,
                            decoration: const InputDecoration(
                              labelText: 'Kelime',
                              hintText: 'Kelimeyi girin',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kelime zorunludur';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // AI fill button
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.tonalIcon(
                            onPressed: _isGenerating ? null : _generateWithAI,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(_isGenerating
                                ? 'Oluşturuluyor...'
                                : 'AI ile Doldur'),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Phonetic
                        Expanded(
                          child: TextFormField(
                            controller: _phoneticController,
                            decoration: const InputDecoration(
                              labelText: 'Fonetik',
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
                              labelText: 'Sözcük Türü',
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
                              labelText: 'CEFR Seviyesi',
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
                    if (_isPhrase) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bu bir phrase olarak algılanacak. Harf karıştırma yerine '
                                'kelime karıştırma egzersizi uygulanır.',
                                style: TextStyle(fontSize: 13, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    Text(
                      'Anlamlar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Meaning TR
                    TextFormField(
                      controller: _meaningTrController,
                      decoration: const InputDecoration(
                        labelText: 'Anlam (Türkçe)',
                        hintText: 'Türkçe anlamını girin',
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Türkçe anlam zorunludur';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Meaning EN
                    TextFormField(
                      controller: _meaningEnController,
                      decoration: const InputDecoration(
                        labelText: 'Anlam (İngilizce)',
                        hintText: 'İngilizce anlamını girin (opsiyonel)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Example sentences
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Örnek Cümleler',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton.icon(
                          onPressed: _addExampleSentence,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ekle'),
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
                              'Henüz örnek cümle yok',
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
                      'Medya',
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
                              labelText: 'Ses URL',
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
                        labelText: 'Görsel URL',
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
