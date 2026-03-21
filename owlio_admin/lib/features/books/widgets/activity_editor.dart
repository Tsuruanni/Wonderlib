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

  /// If editing, the existing inline_activities row (Map with keys: id, type, content, vocabulary_words, etc.)
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

  // Word Translation
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  List<String> _options = [];
  final _optionInputController = TextEditingController();

  // Find Words
  final _instructionController = TextEditingController();
  List<String> _fwOptions = [];
  Set<String> _fwCorrectAnswers = {};
  final _fwOptionInputController = TextEditingController();

  // Matching
  List<Map<String, String>> _pairs = [];
  List<TextEditingController> _leftControllers = [];
  List<TextEditingController> _rightControllers = [];

  // Vocabulary words (shared across word_translation, find_words, matching)
  List<String> _vocabularyWordIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingActivity != null) {
      final content =
          widget.existingActivity!['content'] as Map<String, dynamic>;
      switch (widget.activityType) {
        case 'true_false':
          _statementController.text = content['statement'] ?? '';
          _correctAnswer = content['correct_answer'] ?? true;
        case 'word_translation':
          _wordController.text = content['word'] ?? '';
          _translationController.text = content['correct_answer'] ?? '';
          _options = List<String>.from(content['options'] ?? []);
        case 'find_words':
          _instructionController.text = content['instruction'] ?? '';
          _fwOptions = List<String>.from(content['options'] ?? []);
          _fwCorrectAnswers =
              Set<String>.from(content['correct_answers'] ?? []);
        case 'matching':
          _instructionController.text = content['instruction'] ?? '';
          _pairs = (content['pairs'] as List<dynamic>? ?? [])
              .map(
                (p) => {
                  'left': p['left'] as String? ?? '',
                  'right': p['right'] as String? ?? '',
                },
              )
              .toList();
      }
      _vocabularyWordIds = List<String>.from(
        (widget.existingActivity!['vocabulary_words'] as List<dynamic>?)
                ?.map((e) => e.toString()) ??
            [],
      );
      if (widget.activityType == 'matching') {
        _syncMatchingControllers();
      }
    }
  }

  @override
  void dispose() {
    _statementController.dispose();
    _wordController.dispose();
    _translationController.dispose();
    _optionInputController.dispose();
    _instructionController.dispose();
    _fwOptionInputController.dispose();
    for (final c in _leftControllers) {
      c.dispose();
    }
    for (final c in _rightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncMatchingControllers() {
    for (final c in _leftControllers) {
      c.dispose();
    }
    for (final c in _rightControllers) {
      c.dispose();
    }
    _leftControllers =
        _pairs.map((p) => TextEditingController(text: p['left'])).toList();
    _rightControllers =
        _pairs.map((p) => TextEditingController(text: p['right'])).toList();
    for (int i = 0; i < _pairs.length; i++) {
      _leftControllers[i]
          .addListener(() => _pairs[i]['left'] = _leftControllers[i].text);
      _rightControllers[i]
          .addListener(() => _pairs[i]['right'] = _rightControllers[i].text);
    }
  }

  void _addPair() {
    setState(() {
      _pairs.add({'left': '', 'right': ''});
      _syncMatchingControllers();
    });
  }

  void _removePair(int index) {
    setState(() {
      _pairs.removeAt(index);
      _syncMatchingControllers();
    });
  }

  void _addOption() {
    final text = _optionInputController.text.trim();
    if (text.isEmpty || _options.contains(text)) return;
    setState(() {
      _options.add(text);
      _optionInputController.clear();
    });
  }

  void _addFwOption() {
    final text = _fwOptionInputController.text.trim();
    if (text.isEmpty || _fwOptions.contains(text)) return;
    setState(() {
      _fwOptions.add(text);
      _fwOptionInputController.clear();
    });
  }

  String? _validate() {
    switch (widget.activityType) {
      case 'true_false':
        if (_statementController.text.trim().isEmpty) {
          return 'Statement is required';
        }
      case 'word_translation':
        if (_wordController.text.trim().isEmpty) return 'Word is required';
        if (_translationController.text.trim().isEmpty) {
          return 'Translation is required';
        }
        final allOptions = {..._options, _translationController.text.trim()};
        if (allOptions.length < 2) {
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
        if (_pairs.length < 2) return 'At least 2 pairs required';
        for (final p in _pairs) {
          if ((p['left'] ?? '').trim().isEmpty ||
              (p['right'] ?? '').trim().isEmpty) {
            return 'All pair fields must be filled';
          }
        }
    }
    return null;
  }

  Map<String, dynamic> _buildContent() {
    switch (widget.activityType) {
      case 'true_false':
        return {
          'statement': _statementController.text.trim(),
          'correct_answer': _correctAnswer,
        };
      case 'word_translation':
        final opts = {..._options, _translationController.text.trim()}.toList();
        return {
          'word': _wordController.text.trim(),
          'correct_answer': _translationController.text.trim(),
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
          'pairs': _pairs
              .map(
                (p) => {
                  'left': (p['left'] ?? '').trim(),
                  'right': (p['right'] ?? '').trim(),
                },
              )
              .toList(),
        };
      default:
        return {};
    }
  }

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
    final isEdit = widget.existingActivity != null;
    String activityId = '';

    try {
      if (isEdit) {
        activityId = widget.existingActivity!['id'] as String;
        await supabase.from(DbTables.inlineActivities).update({
          'type': widget.activityType,
          'content': content,
          'vocabulary_words': _vocabularyWordIds,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', activityId);
      } else {
        activityId = const Uuid().v4();
        await supabase.from(DbTables.inlineActivities).insert({
          'id': activityId,
          'chapter_id': widget.chapterId,
          'type': widget.activityType,
          'content': content,
          'vocabulary_words': _vocabularyWordIds,
          'xp_reward': 5,
          'after_paragraph_index': 0,
        });
        // Link to content block
        await supabase.from(DbTables.contentBlocks).update({
          'activity_id': activityId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.blockId);
      }
      widget.onSaved();
    } catch (e) {
      // Rollback: if we inserted a new activity but the content_blocks update failed
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
        const Text('Correct Answer', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('True')),
            ButtonSegment(value: false, label: Text('False')),
          ],
          selected: {_correctAnswer},
          onSelectionChanged: (selection) {
            setState(() => _correctAnswer = selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildWordTranslationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _wordController,
          decoration: const InputDecoration(
            labelText: 'Word',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _translationController,
          decoration: const InputDecoration(
            labelText: 'Correct Answer (Translation)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Distractor Options',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _options.map((opt) {
            return Chip(
              label: Text(opt),
              onDeleted: () => setState(() => _options.remove(opt)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _optionInputController,
                decoration: const InputDecoration(
                  hintText: 'Add distractor option...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addOption(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              tooltip: 'Add option',
            ),
          ],
        ),
        const SizedBox(height: 16),
        VocabularyWordPicker(
          selectedWordIds: _vocabularyWordIds,
          onChanged: (ids) => setState(() => _vocabularyWordIds = ids),
        ),
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
        const SizedBox(height: 16),
        VocabularyWordPicker(
          selectedWordIds: _vocabularyWordIds,
          onChanged: (ids) => setState(() => _vocabularyWordIds = ids),
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
        const SizedBox(height: 12),
        const Text('Pairs', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...List.generate(_pairs.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _leftControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Left ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rightControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Right ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removePair(i),
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  tooltip: 'Remove pair',
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addPair,
          icon: const Icon(Icons.add),
          label: const Text('Add Pair'),
        ),
        const SizedBox(height: 16),
        VocabularyWordPicker(
          selectedWordIds: _vocabularyWordIds,
          onChanged: (ids) => setState(() => _vocabularyWordIds = ids),
        ),
      ],
    );
  }

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
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
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
