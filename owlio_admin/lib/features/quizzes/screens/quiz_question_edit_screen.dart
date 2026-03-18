import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading a single quiz question
final quizQuestionProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, questionId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.bookQuizQuestions)
      .select()
      .eq('id', questionId)
      .maybeSingle();

  return response;
});

/// The five supported question types
final _questionTypes =
    BookQuizQuestionType.values.map((t) => t.dbValue).toList();

class QuizQuestionEditScreen extends ConsumerStatefulWidget {
  const QuizQuestionEditScreen({
    super.key,
    required this.quizId,
    this.questionId,
  });

  final String quizId;
  final String? questionId;

  @override
  ConsumerState<QuizQuestionEditScreen> createState() =>
      _QuizQuestionEditScreenState();
}

class _QuizQuestionEditScreenState
    extends ConsumerState<QuizQuestionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointsController = TextEditingController(text: '1');

  String _selectedType = BookQuizQuestionType.multipleChoice.dbValue;
  bool _isLoading = false;
  bool _isSaving = false;

  // Multiple choice state
  final List<TextEditingController> _mcOptionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String _mcCorrectAnswer = 'A';

  // Fill in the blank state
  final _fillSentenceController = TextEditingController();
  final _fillCorrectController = TextEditingController();
  final _fillAlternativesController = TextEditingController();

  // Event sequencing state
  final List<TextEditingController> _eventControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  List<int> _correctOrder = [0, 1, 2];

  // Matching state
  final List<TextEditingController> _matchLeftControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _matchRightControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Who says what state
  final List<TextEditingController> _characterControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _quoteControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool get isNewQuestion => widget.questionId == null;

  String? _bookId;

  @override
  void initState() {
    super.initState();
    _resolveBookId();
    if (!isNewQuestion) {
      _loadQuestion();
    }
  }

  Future<void> _resolveBookId() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final quiz = await supabase
          .from(DbTables.bookQuizzes)
          .select('book_id')
          .eq('id', widget.quizId)
          .maybeSingle();
      if (quiz != null && mounted) {
        setState(() => _bookId = quiz['book_id'] as String);
      }
    } catch (_) {}
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);

    try {
      final question =
          await ref.read(quizQuestionProvider(widget.questionId!).future);
      if (question != null && mounted) {
        _questionController.text = question['question'] ?? '';
        _explanationController.text = question['explanation'] ?? '';
        _pointsController.text = (question['points'] ?? 1).toString();
        _selectedType = question['type'] ?? BookQuizQuestionType.multipleChoice.dbValue;

        final content = question['content'] as Map<String, dynamic>? ?? {};
        _populateContentFields(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soru yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateContentFields(Map<String, dynamic> content) {
    switch (_selectedType) {
      case 'multiple_choice':
        final options = (content['options'] as List?)?.cast<String>() ?? [];
        for (int i = 0; i < _mcOptionControllers.length && i < options.length; i++) {
          _mcOptionControllers[i].text = options[i];
        }
        _mcCorrectAnswer = content['correct_answer'] as String? ?? 'A';
        break;

      case 'fill_blank':
        _fillSentenceController.text = content['sentence'] as String? ?? '';
        _fillCorrectController.text = content['correct_answer'] as String? ?? '';
        final alternatives =
            (content['accept_alternatives'] as List?)?.cast<String>() ?? [];
        _fillAlternativesController.text = alternatives.join(', ');
        break;

      case 'event_sequencing':
        final events = (content['events'] as List?)?.cast<String>() ?? [];
        final order = (content['correct_order'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            [];
        // Clear existing and rebuild
        for (final c in _eventControllers) {
          c.dispose();
        }
        _eventControllers.clear();
        for (final event in events) {
          _eventControllers.add(TextEditingController(text: event));
        }
        if (_eventControllers.isEmpty) {
          _eventControllers.addAll([
            TextEditingController(),
            TextEditingController(),
            TextEditingController(),
          ]);
        }
        _correctOrder =
            order.isNotEmpty ? order : List.generate(events.length, (i) => i);
        break;

      case 'matching':
        final left = (content['left'] as List?)?.cast<String>() ?? [];
        final right = (content['right'] as List?)?.cast<String>() ?? [];
        for (final c in _matchLeftControllers) {
          c.dispose();
        }
        for (final c in _matchRightControllers) {
          c.dispose();
        }
        _matchLeftControllers.clear();
        _matchRightControllers.clear();
        for (int i = 0; i < left.length; i++) {
          _matchLeftControllers.add(TextEditingController(text: left[i]));
          _matchRightControllers.add(TextEditingController(
              text: i < right.length ? right[i] : ''));
        }
        if (_matchLeftControllers.isEmpty) {
          _matchLeftControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
          _matchRightControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
        }
        break;

      case 'who_says_what':
        final characters =
            (content['characters'] as List?)?.cast<String>() ?? [];
        final quotes = (content['quotes'] as List?)?.cast<String>() ?? [];
        for (final c in _characterControllers) {
          c.dispose();
        }
        for (final c in _quoteControllers) {
          c.dispose();
        }
        _characterControllers.clear();
        _quoteControllers.clear();
        for (int i = 0; i < characters.length; i++) {
          _characterControllers
              .add(TextEditingController(text: characters[i]));
          _quoteControllers.add(
              TextEditingController(text: i < quotes.length ? quotes[i] : ''));
        }
        if (_characterControllers.isEmpty) {
          _characterControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
          _quoteControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
        }
        break;
    }
  }

  Map<String, dynamic> _buildContentJson() {
    switch (_selectedType) {
      case 'multiple_choice':
        return {
          'options':
              _mcOptionControllers.map((c) => c.text.trim()).toList(),
          'correct_answer': _mcCorrectAnswer,
        };

      case 'fill_blank':
        final alternatives = _fillAlternativesController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return {
          'sentence': _fillSentenceController.text.trim(),
          'correct_answer': _fillCorrectController.text.trim(),
          'accept_alternatives': alternatives,
        };

      case 'event_sequencing':
        return {
          'events': _eventControllers.map((c) => c.text.trim()).toList(),
          'correct_order': _correctOrder,
        };

      case 'matching':
        final pairs = <String, String>{};
        for (int i = 0; i < _matchLeftControllers.length; i++) {
          pairs[i.toString()] = i.toString();
        }
        return {
          'left': _matchLeftControllers.map((c) => c.text.trim()).toList(),
          'right': _matchRightControllers.map((c) => c.text.trim()).toList(),
          'correct_pairs': pairs,
        };

      case 'who_says_what':
        final pairs = <String, String>{};
        for (int i = 0; i < _characterControllers.length; i++) {
          pairs[i.toString()] = i.toString();
        }
        return {
          'characters':
              _characterControllers.map((c) => c.text.trim()).toList(),
          'quotes': _quoteControllers.map((c) => c.text.trim()).toList(),
          'correct_pairs': pairs,
        };

      default:
        return {};
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final content = _buildContentJson();

      final data = {
        'quiz_id': widget.quizId,
        'type': _selectedType,
        'question': _questionController.text.trim(),
        'content': content,
        'explanation': _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        'points': int.tryParse(_pointsController.text.trim()) ?? 1,
      };

      if (isNewQuestion) {
        data['id'] = const Uuid().v4();
        // Get next order_index
        final existing = await supabase
            .from(DbTables.bookQuizQuestions)
            .select('order_index')
            .eq('quiz_id', widget.quizId)
            .order('order_index', ascending: false)
            .limit(1);
        final maxIndex = (existing as List).isNotEmpty
            ? (existing[0]['order_index'] as int) + 1
            : 0;
        data['order_index'] = maxIndex;

        await supabase.from(DbTables.bookQuizQuestions).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Soru başarıyla oluşturuldu')),
          );
          // Navigate back to quiz
          if (_bookId != null) {
            context.go('/books/$_bookId/quiz');
          } else {
            context.pop();
          }
        }
      } else {
        await supabase
            .from(DbTables.bookQuizQuestions)
            .update(data)
            .eq('id', widget.questionId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Soru başarıyla kaydedildi')),
          );
          if (_bookId != null) {
            context.go('/books/$_bookId/quiz');
          } else {
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    for (final c in _mcOptionControllers) {
      c.dispose();
    }
    _fillSentenceController.dispose();
    _fillCorrectController.dispose();
    _fillAlternativesController.dispose();
    for (final c in _eventControllers) {
      c.dispose();
    }
    for (final c in _matchLeftControllers) {
      c.dispose();
    }
    for (final c in _matchRightControllers) {
      c.dispose();
    }
    for (final c in _characterControllers) {
      c.dispose();
    }
    for (final c in _quoteControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Çoktan Seçmeli';
      case 'fill_blank':
        return 'Boşluk Doldurma';
      case 'event_sequencing':
        return 'Olay Sıralaması';
      case 'matching':
        return 'Eşleştirme';
      case 'who_says_what':
        return 'Kim Ne Dedi';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewQuestion ? 'Yeni Soru' : 'Soruyu Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_bookId != null) {
              context.go('/books/$_bookId/quiz');
            } else {
              context.pop();
            }
          },
        ),
        actions: [
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
                : Text(isNewQuestion ? 'Oluştur' : 'Kaydet'),
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
                    // Type dropdown + Points in a row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Soru Türü',
                            ),
                            items: _questionTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(_getTypeLabel(type)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedType = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _pointsController,
                            decoration: const InputDecoration(
                              labelText: 'Puan',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Zorunlu';
                              }
                              final pts = int.tryParse(value.trim());
                              if (pts == null || pts < 1) {
                                return 'En az 1';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question text
                    TextFormField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Soru',
                        hintText: 'Soru metnini girin',
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Soru metni zorunludur';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Dynamic content form
                    Text(
                      'İçerik',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildContentForm(),

                    const SizedBox(height: 24),

                    // Explanation
                    TextFormField(
                      controller: _explanationController,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                        hintText:
                            'Öğrencilerin öğrenmesine yardımcı olmak için doğru cevabı açıklayın',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContentForm() {
    switch (_selectedType) {
      case 'multiple_choice':
        return _buildMultipleChoiceForm();
      case 'fill_blank':
        return _buildFillBlankForm();
      case 'event_sequencing':
        return _buildEventSequencingForm();
      case 'matching':
        return _buildMatchingForm();
      case 'who_says_what':
        return _buildWhoSaysWhatForm();
      default:
        return const Text('Bilinmeyen soru türü');
    }
  }

  // --------------- Multiple Choice ---------------

  Widget _buildMultipleChoiceForm() {
    const labels = ['A', 'B', 'C', 'D'];
    return RadioGroup<String>(
      groupValue: _mcCorrectAnswer,
      onChanged: (value) {
        if (value != null) {
          setState(() => _mcCorrectAnswer = value);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _mcOptionControllers[index],
                decoration: InputDecoration(
                  labelText: 'Seçenek ${labels[index]}',
                  prefixIcon: Radio<String>(
                    value: labels[index],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Seçenek ${labels[index]} zorunludur';
                  }
                  return null;
                },
              ),
            );
          }),
          Text(
            'Doğru cevabın yanındaki radyo düğmesini seçin',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --------------- Fill in the Blank ---------------

  Widget _buildFillBlankForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _fillSentenceController,
          decoration: const InputDecoration(
            labelText: 'Cümle',
            hintText: 'Boşluk için ___ kullanın (örn. "The ___ ran fast.")',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Cümle zorunludur';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fillCorrectController,
          decoration: const InputDecoration(
            labelText: 'Doğru Cevap',
            hintText: 'Boşluğu dolduran kelime',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Doğru cevap zorunludur';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fillAlternativesController,
          decoration: const InputDecoration(
            labelText: 'Kabul Edilen Alternatifler (isteğe bağlı)',
            hintText: 'Virgülle ayrılmış (örn. "Fox, FOX")',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kabul edilmesi gereken alternatif cevaplar',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  // --------------- Event Sequencing ---------------

  Widget _buildEventSequencingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olayları DOĞRU sırayla girin. Öğrenciler karışık sırada görecek.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...List.generate(_eventControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _eventControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Olay ${index + 1}',
                      hintText: 'Olayı açıklayın',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Olay zorunludur';
                      }
                      return null;
                    },
                  ),
                ),
                if (_eventControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () {
                      setState(() {
                        _eventControllers[index].dispose();
                        _eventControllers.removeAt(index);
                        _correctOrder =
                            List.generate(_eventControllers.length, (i) => i);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _eventControllers.add(TextEditingController());
              _correctOrder =
                  List.generate(_eventControllers.length, (i) => i);
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Olay Ekle'),
        ),
      ],
    );
  }

  // --------------- Matching ---------------

  Widget _buildMatchingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eşleştirme çiftlerini girin. Sol öğeler sağ öğelerle eşleştirilecek.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        // Header row
        Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Text(
                'Sol',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sağ (doğru eşleşme)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_matchLeftControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _matchLeftControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Sol öğe ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Zorunlu';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _matchRightControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Sağ öğe ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Zorunlu';
                      }
                      return null;
                    },
                  ),
                ),
                if (_matchLeftControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () {
                      setState(() {
                        _matchLeftControllers[index].dispose();
                        _matchRightControllers[index].dispose();
                        _matchLeftControllers.removeAt(index);
                        _matchRightControllers.removeAt(index);
                      });
                    },
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _matchLeftControllers.add(TextEditingController());
              _matchRightControllers.add(TextEditingController());
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Çift Ekle'),
        ),
      ],
    );
  }

  // --------------- Who Says What ---------------

  Widget _buildWhoSaysWhatForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Karakter-alıntı çiftlerini girin. Öğrenciler karakterleri alıntılarıyla eşleştirecek.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        // Header row
        Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Text(
                'Karakter',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Alıntı (doğru eşleşme)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_characterControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _characterControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Karakter ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Zorunlu';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quoteControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Alıntı ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Zorunlu';
                      }
                      return null;
                    },
                  ),
                ),
                if (_characterControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () {
                      setState(() {
                        _characterControllers[index].dispose();
                        _quoteControllers[index].dispose();
                        _characterControllers.removeAt(index);
                        _quoteControllers.removeAt(index);
                      });
                    },
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _characterControllers.add(TextEditingController());
              _quoteControllers.add(TextEditingController());
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Çift Ekle'),
        ),
      ],
    );
  }
}
