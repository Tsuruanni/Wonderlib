import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../services/book_json_validator.dart';
import 'book_list_screen.dart';

class BookJsonImportScreen extends ConsumerStatefulWidget {
  const BookJsonImportScreen({super.key});

  @override
  ConsumerState<BookJsonImportScreen> createState() =>
      _BookJsonImportScreenState();
}

class _BookJsonImportScreenState extends ConsumerState<BookJsonImportScreen> {
  int _currentStep = 0;
  final _jsonController = TextEditingController();
  String? _fileName;

  // Step 2 state
  BookJsonValidationResult? _validationResult;

  // Step 3 state
  bool _isImporting = false;
  final _importLog = <_ImportLogEntry>[];
  String? _importedBookId;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    try {
      final content = utf8.decode(file.bytes!);
      setState(() {
        _jsonController.text = content;
        _fileName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya okunamadı: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleValidate() async {
    final jsonText = _jsonController.text.trim();
    if (jsonText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON girişi boş'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validator = BookJsonValidator();
    final result = validator.validate(jsonText);

    // Check slug uniqueness in DB
    if (result.isValid) {
      final slug = result.data!.book['slug'] as String;
      final supabase = ref.read(supabaseClientProvider);
      final existing = await supabase
          .from(DbTables.books)
          .select('id')
          .eq('slug', slug)
          .maybeSingle();

      if (!mounted) return;

      if (existing != null) {
        setState(() {
          _validationResult = BookJsonValidationResult.failure(
            ['book.slug: "$slug" zaten mevcut. Farklı bir slug kullanın.'],
          );
          _currentStep = 1;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _validationResult = result;
      _currentStep = 1;
    });
  }

  Future<void> _handleImport() async {
    final data = _validationResult?.data;
    if (data == null) return;

    setState(() {
      _currentStep = 2;
      _isImporting = true;
      _importLog.clear();
    });

    final supabase = ref.read(supabaseClientProvider);
    const uuid = Uuid();
    final bookId = uuid.v4();

    try {
      // 1. Create book
      _addLog('Kitap oluşturuluyor...');
      await supabase.from(DbTables.books).insert({
        'id': bookId,
        'title': (data.book['title'] as String).trim(),
        'slug': (data.book['slug'] as String).trim(),
        'level': data.book['level'],
        'description': data.book['description'],
        'cover_url': data.book['cover_url'],
        'genre': data.book['genre'],
        'age_group': data.book['age_group'],
        'estimated_minutes': data.book['estimated_minutes'],
        'word_count': data.book['word_count'],
        'lexile_score': data.book['lexile_score'],
        'status': data.book['status'] ?? 'draft',
        'metadata': data.book['metadata'] ?? {},
        'chapter_count': data.chapters.length,
      });
      _updateLog('Kitap oluşturuldu ✓');

      // 2. Create chapters + content blocks + inline activities
      for (var i = 0; i < data.chapters.length; i++) {
        final parsedCh = data.chapters[i];
        final ch = parsedCh.chapter;
        final chapterId = uuid.v4();

        _addLog('Bölüm ${i + 1}/${data.chapters.length}: "${ch['title']}"...');

        await supabase.from(DbTables.chapters).insert({
          'id': chapterId,
          'book_id': bookId,
          'title': (ch['title'] as String).trim(),
          'order_index': ch['order_index'],
          'word_count': ch['word_count'],
          'estimated_minutes': ch['estimated_minutes'],
          'vocabulary': ch['vocabulary'] ?? [],
          'use_content_blocks': true,
        });

        // 3. Create inline activities first (need activity_ids for content blocks)
        final activityIdMap = <int, String>{}; // contentBlockIndex -> activityId
        for (final pa in parsedCh.inlineActivities) {
          final activityId = uuid.v4();
          activityIdMap[pa.contentBlockIndex] = activityId;

          await supabase.from(DbTables.inlineActivities).insert({
            'id': activityId,
            'chapter_id': chapterId,
            'type': pa.activity['type'],
            'after_paragraph_index': pa.activity['after_paragraph_index'] ?? 0,
            'content': pa.activity['content'],
            'xp_reward': pa.activity['xp_reward'] ?? 5,
            'vocabulary_words': pa.activity['vocabulary_words'] ?? [],
          });
        }

        // 4. Create content blocks
        for (var j = 0; j < parsedCh.contentBlocks.length; j++) {
          final block = parsedCh.contentBlocks[j];
          await supabase.from(DbTables.contentBlocks).insert({
            'id': uuid.v4(),
            'chapter_id': chapterId,
            'order_index': block['order_index'],
            'type': block['type'],
            'text': block['text'],
            'audio_url': block['audio_url'],
            'word_timings': block['word_timings'] ?? [],
            'audio_start_ms': block['audio_start_ms'],
            'audio_end_ms': block['audio_end_ms'],
            'image_url': block['image_url'],
            'caption': block['caption'],
            'activity_id': activityIdMap[j],
          });
        }

        _updateLog('Bölüm ${i + 1}/${data.chapters.length}: "${ch['title']}" ✓');
      }

      // 5. Create book quiz (if present)
      if (data.bookQuiz != null) {
        final quiz = data.bookQuiz!;
        final quizId = uuid.v4();

        _addLog('Final quiz oluşturuluyor...');
        await supabase.from(DbTables.bookQuizzes).insert({
          'id': quizId,
          'book_id': bookId,
          'title': (quiz['title'] as String).trim(),
          'instructions': quiz['instructions'],
          'passing_score': quiz['passing_score'] ?? 70.0,
          'total_points': quiz['total_points'] ?? 10,
          'is_published': quiz['is_published'] ?? false,
        });

        // 6. Create quiz questions
        final questions = quiz['questions'] as List;
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i] as Map<String, dynamic>;
          await supabase.from(DbTables.bookQuizQuestions).insert({
            'id': uuid.v4(),
            'quiz_id': quizId,
            'type': q['type'],
            'order_index': q['order_index'] ?? i,
            'question': (q['question'] as String).trim(),
            'content': q['content'],
            'explanation': q['explanation'],
            'points': q['points'] ?? 1,
          });
        }

        _updateLog('Final quiz oluşturuldu ✓');
      }

      _addLog('Import tamamlandı!');
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _importedBookId = bookId;
      });

      ref.invalidate(booksProvider);
    } catch (e) {
      // Rollback: delete the partially created book (cascades to chapters, content_blocks, etc.)
      try {
        await supabase.from(DbTables.books).delete().eq('id', bookId);
      } catch (_) {
        // Rollback failed — log but don't mask original error
      }
      _addLog('Hata: $e — değişiklikler geri alındı', isError: true);
      if (!mounted) return;
      setState(() => _isImporting = false);
    }
  }

  void _addLog(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _importLog.add(_ImportLogEntry(message, isError: isError));
    });
  }

  void _updateLog(String message) {
    if (!mounted) return;
    setState(() {
      if (_importLog.isNotEmpty) {
        _importLog[_importLog.length - 1] = _ImportLogEntry(message, isComplete: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON ile Kitap İçe Aktar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/books'),
        ),
      ),
      body: Stepper(
        currentStep: _currentStep,
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
    );
  }

  Step _buildStep1() {
    return Step(
      title: const Text('JSON Giriş'),
      subtitle: _fileName != null ? Text(_fileName!) : null,
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.indigo.shade50,
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.upload_file, size: 36, color: Colors.indigo.shade700),
                          const SizedBox(height: 8),
                          Text('Dosya Yükle', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade700)),
                          const SizedBox(height: 4),
                          Text('.json dosyası seç', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('veya', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.content_paste, size: 36, color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        Text('JSON Yapıştır', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Text('Aşağıya yapıştırın', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _jsonController,
              maxLines: 15,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: '{"book": {...}, "chapters": [...]}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade900,
                hintStyle: TextStyle(color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _handleValidate,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Validate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Step _buildStep2() {
    final result = _validationResult;
    return Step(
      title: const Text('Validation & Preview'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1
          ? StepState.complete
          : _currentStep == 1
              ? StepState.indexed
              : StepState.disabled,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: result == null
            ? const Text('Önce JSON girişi yapın.')
            : result.isValid
                ? _buildValidPreview(result.data!)
                : _buildErrorList(result.errors),
      ),
    );
  }

  Widget _buildValidPreview(BookJsonData data) {
    final book = data.book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'JSON geçerli — import\'a hazır',
                style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _previewRow('Kitap', '${book['title']} (${book['level']})'),
        _previewRow('Slug', book['slug'] as String),
        _previewRow('Bölümler', '${data.chapters.length} chapter'),
        _previewRow('Content Blocks', '${data.totalContentBlocks} blok'),
        _previewRow('Inline Aktiviteler', '${data.totalInlineActivities} adet'),
        _previewRow('Final Quiz', data.bookQuiz != null
            ? '${data.totalQuizQuestions} soru'
            : 'Yok'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Geri'),
            ),
            FilledButton.icon(
              onPressed: _handleImport,
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text('Import Et'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildErrorList(List<String> errors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                '${errors.length} hata bulundu',
                style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...errors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border(
                    left: BorderSide(color: Colors.red.shade400, width: 3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(e, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              ),
            )),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep = 0),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('JSON\'u Düzelt'),
          ),
        ),
      ],
    );
  }

  Step _buildStep3() {
    return Step(
      title: const Text('Import'),
      isActive: _currentStep >= 2,
      state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isImporting)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            ..._importLog.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (entry.isError)
                        Icon(Icons.error, size: 18, color: Colors.red.shade600)
                      else if (entry.isComplete)
                        Icon(Icons.check_circle, size: 18, color: Colors.green.shade600)
                      else
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.message,
                          style: TextStyle(
                            color: entry.isError ? Colors.red.shade700 : null,
                            fontWeight: entry.isError ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (_importedBookId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Import başarıyla tamamlandı!',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/books/$_importedBookId'),
                      child: const Text('Kitabı Düzenle'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportLogEntry {
  final String message;
  final bool isComplete;
  final bool isError;

  const _ImportLogEntry(this.message, {this.isComplete = false, this.isError = false});
}
