import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'vocabulary_word_picker.dart';

class ActivityEditor extends ConsumerStatefulWidget {
  const ActivityEditor({
    super.key,
    required this.chapterId,
    required this.blockId,
    required this.activityType,
    this.existingActivity,
    required this.onSaved,
    required this.onCancel,
  });

  final String chapterId;
  final String blockId;

  /// The InlineActivityType dbValue string: 'true_false', 'word_translation', 'find_words', 'matching'
  final String activityType;

  /// If editing, the existing inline_activities row
  final Map<String, dynamic>? existingActivity;

  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  ConsumerState<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends ConsumerState<ActivityEditor> {
  bool _isSaving = false;
  String? _error;

  // True/False
  final _statementController = TextEditingController();
  bool _correctAnswer = true;

  // Word Translation — driven by vocab word selection
  String? _wtWordId; // selected vocabulary word ID
  String _wtWord = ''; // word text (read-only, from vocab)
  final _wtTranslationController = TextEditingController(); // editable
  List<String> _wtOptions = []; // distractor options
  final _wtOptionInputController = TextEditingController();

  // Find Words — no vocabulary connection
  final _instructionController = TextEditingController();
  List<String> _fwOptions = [];
  Set<String> _fwCorrectAnswers = {};
  final _fwOptionInputController = TextEditingController();

  // Matching — driven by vocab word selection
  // Each entry: {id: vocabWordId, word: String, meaning: String (editable)}
  List<Map<String, String>> _matchingWords = [];
  List<TextEditingController> _matchingMeaningControllers = [];

  @override
  void initState() {
    super.initState();
    // Default instruction for new matching activities
    if (widget.existingActivity == null && widget.activityType == 'matching') {
      _instructionController.text = 'Match each word with its meaning.';
    }
    if (widget.existingActivity != null) {
      final content =
          widget.existingActivity!['content'] as Map<String, dynamic>;
      final vocabIds = List<String>.from(
        (widget.existingActivity!['vocabulary_words'] as List<dynamic>?)
                ?.map((e) => e.toString()) ??
            [],
      );
      switch (widget.activityType) {
        case 'true_false':
          _statementController.text = content['statement'] ?? '';
          _correctAnswer = content['correct_answer'] ?? true;
        case 'word_translation':
          _wtWord = content['word'] ?? '';
          _wtTranslationController.text = content['correct_answer'] ?? '';
          _wtOptions = List<String>.from(content['options'] ?? []);
          // Remove the correct answer from distractor options
          _wtOptions.remove(_wtTranslationController.text);
          _wtWordId = vocabIds.isNotEmpty ? vocabIds.first : null;
        case 'find_words':
          _instructionController.text = content['instruction'] ?? '';
          _fwOptions = List<String>.from(content['options'] ?? []);
          _fwCorrectAnswers =
              Set<String>.from(content['correct_answers'] ?? []);
        case 'matching':
          _instructionController.text = content['instruction'] ?? 'Match each word with its meaning.';
          final pairs = (content['pairs'] as List<dynamic>? ?? []);
          // Rebuild matching words from pairs + vocab IDs
          for (int i = 0; i < pairs.length; i++) {
            final p = pairs[i] as Map<String, dynamic>;
            _matchingWords.add({
              'id': i < vocabIds.length ? vocabIds[i] : '',
              'word': p['left'] as String? ?? '',
              'meaning': p['right'] as String? ?? '',
            });
          }
          _syncMatchingMeaningControllers();
      }
    }
  }

  @override
  void dispose() {
    _statementController.dispose();
    _wtTranslationController.dispose();
    _wtOptionInputController.dispose();
    _instructionController.dispose();
    _fwOptionInputController.dispose();
    for (final c in _matchingMeaningControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Matching helpers ---

  void _syncMatchingMeaningControllers() {
    for (final c in _matchingMeaningControllers) {
      c.dispose();
    }
    _matchingMeaningControllers = _matchingWords
        .map((w) => TextEditingController(text: w['meaning']))
        .toList();
    for (int i = 0; i < _matchingWords.length; i++) {
      _matchingMeaningControllers[i].addListener(
        () => _matchingWords[i]['meaning'] =
            _matchingMeaningControllers[i].text,
      );
    }
  }

  void _removeMatchingWord(int index) {
    setState(() {
      _matchingWords.removeAt(index);
      _syncMatchingMeaningControllers();
    });
  }

  // --- Word Translation helpers ---

  void _addWtOption() {
    final text = _wtOptionInputController.text.trim();
    if (text.isEmpty || _wtOptions.contains(text)) return;
    setState(() {
      _wtOptions.add(text);
      _wtOptionInputController.clear();
    });
  }

  // --- Find Words helpers ---

  void _addFwOption() {
    final text = _fwOptionInputController.text.trim();
    if (text.isEmpty || _fwOptions.contains(text)) return;
    setState(() {
      _fwOptions.add(text);
      _fwOptionInputController.clear();
    });
  }

  // --- Validation ---

  String? _validate() {
    switch (widget.activityType) {
      case 'true_false':
        if (_statementController.text.trim().isEmpty) {
          return 'Statement is required';
        }
      case 'word_translation':
        if (_wtWordId == null) return 'Select a vocabulary word';
        if (_wtTranslationController.text.trim().isEmpty) {
          return 'Translation is required';
        }
        if (_wtOptions.isEmpty) {
          return 'At least 1 distractor option required';
        }
      case 'find_words':
        if (_instructionController.text.trim().isEmpty) {
          return 'Instruction is required';
        }
        if (_fwOptions.isEmpty) return 'At least 1 option required';
        if (_fwCorrectAnswers.isEmpty) {
          return 'At least 1 correct answer required';
        }
        if (!_fwCorrectAnswers.every((a) => _fwOptions.contains(a))) {
          return 'Correct answers must be from options';
        }
      case 'matching':
        if (_instructionController.text.trim().isEmpty) {
          return 'Instruction is required';
        }
        if (_matchingWords.length < 2) return 'At least 2 words required';
        for (final w in _matchingWords) {
          if ((w['meaning'] ?? '').trim().isEmpty) {
            return 'All meaning fields must be filled';
          }
        }
    }
    return null;
  }

  // --- Build content JSONB ---

  Map<String, dynamic> _buildContent() {
    switch (widget.activityType) {
      case 'true_false':
        return {
          'statement': _statementController.text.trim(),
          'correct_answer': _correctAnswer,
        };
      case 'word_translation':
        final correctAnswer = _wtTranslationController.text.trim();
        final opts = {..._wtOptions, correctAnswer}.toList()..shuffle();
        return {
          'word': _wtWord,
          'correct_answer': correctAnswer,
          'options': opts,
        };
      case 'find_words':
        return {
          'instruction': _instructionController.text.trim(),
          'options': _fwOptions,
          'correct_answers': _fwCorrectAnswers.toList(),
        };
      case 'matching':
        return {
          'instruction': _instructionController.text.trim(),
          'pairs': _matchingWords
              .map((w) => {
                    'left': (w['word'] ?? '').trim(),
                    'right': (w['meaning'] ?? '').trim(),
                  })
              .toList(),
        };
      default:
        return {};
    }
  }

  // --- Vocabulary word IDs for save ---

  List<String> _getVocabularyWordIds() {
    switch (widget.activityType) {
      case 'word_translation':
        return _wtWordId != null ? [_wtWordId!] : [];
      case 'matching':
        return _matchingWords
            .where((w) => (w['id'] ?? '').isNotEmpty)
            .map((w) => w['id']!)
            .toList();
      default:
        return [];
    }
  }

  // --- Save ---

  Future<void> _handleSave() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });

    final supabase = ref.read(supabaseClientProvider);
    final content = _buildContent();
    final vocabIds = _getVocabularyWordIds();
    final isEdit = widget.existingActivity != null;
    String activityId = '';

    try {
      if (isEdit) {
        activityId = widget.existingActivity!['id'] as String;
        await supabase.from(DbTables.inlineActivities).update({
          'type': widget.activityType,
          'content': content,
          'vocabulary_words': vocabIds,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', activityId);
      } else {
        activityId = const Uuid().v4();
        await supabase.from(DbTables.inlineActivities).insert({
          'id': activityId,
          'chapter_id': widget.chapterId,
          'type': widget.activityType,
          'content': content,
          'vocabulary_words': vocabIds,
          'xp_reward': 5,
          'after_paragraph_index': 0,
        });
        await supabase.from(DbTables.contentBlocks).update({
          'activity_id': activityId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.blockId);
      }
      widget.onSaved();
    } catch (e) {
      if (!isEdit && activityId.isNotEmpty) {
        try {
          await supabase
              .from(DbTables.inlineActivities)
              .delete()
              .eq('id', activityId);
        } catch (_) {}
      }
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // =============================================
  // FORM BUILDERS
  // =============================================

  Widget _buildTrueFalseForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _statementController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Statement',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Correct Answer',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('True')),
            ButtonSegment(value: false, label: Text('False')),
          ],
          selected: {_correctAnswer},
          onSelectionChanged: (s) =>
              setState(() => _correctAnswer = s.first),
        ),
      ],
    );
  }

  Widget _buildWordTranslationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vocab word picker — single select
        const Text('Select Vocabulary Word',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        VocabularyWordPicker(
          selectedWordIds: _wtWordId != null ? [_wtWordId!] : [],
          onChanged: (ids) async {
            if (ids.isEmpty) {
              setState(() {
                _wtWordId = null;
                _wtWord = '';
                _wtTranslationController.clear();
              });
              return;
            }
            // Load word details for the newly selected word
            final newId = ids.last;
            if (newId == _wtWordId) return;
            final supabase = ref.read(supabaseClientProvider);
            final word = await supabase
                .from(DbTables.vocabularyWords)
                .select('id, word, meaning_tr')
                .eq('id', newId)
                .maybeSingle();
            if (word != null && mounted) {
              setState(() {
                _wtWordId = newId;
                _wtWord = word['word'] as String? ?? '';
                _wtTranslationController.text =
                    word['meaning_tr'] as String? ?? '';
              });
            }
          },
        ),
        if (_wtWord.isNotEmpty) ...[
          const SizedBox(height: 16),
          // Word (read-only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.abc, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_wtWord,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Translation (editable)
          TextField(
            controller: _wtTranslationController,
            decoration: const InputDecoration(
              labelText: 'Translation (editable)',
              helperText: 'Auto-filled from vocabulary. You can simplify it.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Distractor options
          const Text('Distractor Options',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _wtOptions.map((opt) {
              return Chip(
                label: Text(opt),
                onDeleted: () => setState(() => _wtOptions.remove(opt)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wtOptionInputController,
                  decoration: const InputDecoration(
                    hintText: 'Add distractor option...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addWtOption(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addWtOption,
                icon: const Icon(Icons.add),
                tooltip: 'Add option',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFindWordsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _instructionController,
          decoration: const InputDecoration(
            labelText: 'Instruction',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Options', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _fwOptions.map((opt) {
            final isCorrect = _fwCorrectAnswers.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isCorrect,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _fwCorrectAnswers.add(opt);
                  } else {
                    _fwCorrectAnswers.remove(opt);
                  }
                });
              },
              onDeleted: () {
                setState(() {
                  _fwOptions.remove(opt);
                  _fwCorrectAnswers.remove(opt);
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap chip to toggle as correct answer',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fwOptionInputController,
                decoration: const InputDecoration(
                  hintText: 'Add option...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addFwOption(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addFwOption,
              icon: const Icon(Icons.add),
              tooltip: 'Add option',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _instructionController,
          decoration: const InputDecoration(
            labelText: 'Instruction',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // Vocab word picker for adding words to matching
        const Text('Add Vocabulary Words',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        VocabularyWordPicker(
          selectedWordIds:
              _matchingWords.map((w) => w['id'] ?? '').where((id) => id.isNotEmpty).toList(),
          onChanged: (ids) async {
            // Find newly added IDs
            final currentIds =
                _matchingWords.map((w) => w['id']).toSet();
            final newIds =
                ids.where((id) => !currentIds.contains(id)).toList();
            // Find removed IDs
            final removedIds =
                currentIds.where((id) => id != null && id.isNotEmpty && !ids.contains(id)).toSet();

            if (removedIds.isNotEmpty) {
              setState(() {
                _matchingWords.removeWhere(
                    (w) => removedIds.contains(w['id']));
                _syncMatchingMeaningControllers();
              });
            }

            if (newIds.isNotEmpty) {
              final supabase = ref.read(supabaseClientProvider);
              final response = await supabase
                  .from(DbTables.vocabularyWords)
                  .select('id, word, meaning_tr')
                  .inFilter('id', newIds);
              final rows = List<Map<String, dynamic>>.from(response);
              if (mounted) {
                setState(() {
                  for (final row in rows) {
                    _matchingWords.add({
                      'id': row['id'] as String,
                      'word': row['word'] as String? ?? '',
                      'meaning': row['meaning_tr'] as String? ?? '',
                    });
                  }
                  _syncMatchingMeaningControllers();
                });
              }
            }
          },
        ),
        if (_matchingWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Pairs (meaning is editable)',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ...List.generate(_matchingWords.length, (i) {
            final w = _matchingWords[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Word (read-only)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(w['word'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  // Meaning (editable)
                  Expanded(
                    child: TextField(
                      controller: _matchingMeaningControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Meaning ${i + 1}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeMatchingWord(i),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // =============================================
  // BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (widget.activityType) {
          'true_false' => _buildTrueFalseForm(),
          'word_translation' => _buildWordTranslationForm(),
          'find_words' => _buildFindWordsForm(),
          'matching' => _buildMatchingForm(),
          _ => Text('Unknown type: ${widget.activityType}'),
        },
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('İptal'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ],
    );
  }
}
