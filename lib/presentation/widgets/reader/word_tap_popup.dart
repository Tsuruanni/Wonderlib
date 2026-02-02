import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/word_definition.dart';
import '../../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/word_definition_provider.dart';

/// Dark-themed popup for word-tap feature.
/// Shows word, pronunciation audio, part of speech, Turkish meaning,
/// and "I didn't know this" button to add to vocabulary.
class WordTapPopup extends ConsumerStatefulWidget {
  const WordTapPopup({
    super.key,
    required this.word,
    required this.position,
    required this.onClose,
    this.onPlayAudio,
  });

  final String word;
  final Offset position;
  final VoidCallback onClose;
  final void Function(String audioUrl)? onPlayAudio;

  @override
  ConsumerState<WordTapPopup> createState() => _WordTapPopupState();
}

class _WordTapPopupState extends ConsumerState<WordTapPopup> {
  bool _isAdding = false;
  bool _wasAdded = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final definitionAsync = ref.watch(wordDefinitionProvider(widget.word));

    // Popup dimensions
    const popupWidth = 280.0;

    // Calculate position
    double left = widget.position.dx - popupWidth / 2;
    double top = widget.position.dy + 20; // Show below the word

    // Adjust if off screen horizontally
    if (left < 16) left = 16;
    if (left + popupWidth > screenSize.width - 16) {
      left = screenSize.width - popupWidth - 16;
    }

    // Show above if not enough space below
    if (top + 200 > screenSize.height - 100) {
      top = widget.position.dy - 180;
    }

    return Stack(
      children: [
        // Dismiss overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black26),
          ),
        ),

        // Popup card
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF2D2D2D), // Dark background
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.all(16),
              child: definitionAsync.when(
                loading: () => _buildLoading(),
                error: (_, __) => _buildError(),
                data: (definition) => _buildContent(definition),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 20),
        CircularProgressIndicator(strokeWidth: 2),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.word,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Could not load definition',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildContent(WordDefinition? definition) {
    final hasDefinition = definition != null && definition.hasDefinition;
    final displayWord = definition?.word ?? widget.word;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: word + speaker icon + close
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    displayWord,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Speaker icon
                  GestureDetector(
                    onTap: (definition?.hasAudio ?? false)
                        ? () => widget.onPlayAudio?.call(definition!.audioUrl!)
                        : null,
                    child: Icon(
                      Icons.volume_up,
                      color: (definition?.hasAudio ?? false)
                          ? Colors.white
                          : Colors.white38,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            // Close button
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Meanings list (supports multiple meanings from different books)
        if (hasDefinition)
          _buildMeaningsList(definition)
        else
          const Text(
            'No definition available',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),

        const SizedBox(height: 16),

        // Action button
        if (hasDefinition && definition.isFromDatabase)
          _buildActionButton(definition)
        else if (!hasDefinition)
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildMeaningsList(WordDefinition definition) {
    final meanings = definition.meanings;

    // If only one meaning, show simple layout
    if (meanings.length == 1) {
      return _buildSingleMeaning(meanings.first);
    }

    // Multiple meanings - show each with book attribution
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Column(
          children: meanings.asMap().entries.map((entry) {
            final index = entry.key;
            final meaning = entry.value;
            return Column(
              children: [
                if (index > 0)
                  const Divider(color: Colors.white24, height: 16),
                _buildMeaningCard(meaning),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSingleMeaning(WordMeaning meaning) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Part of speech badge
        if (meaning.partOfSpeech != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatPartOfSpeech(meaning.partOfSpeech!),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        // Turkish meaning
        Text(
          meaning.meaningTR,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        // Example sentence (if available)
        if (meaning.exampleSentence != null &&
            meaning.exampleSentence!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '"${meaning.exampleSentence}"',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMeaningCard(WordMeaning meaning) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book title (if available)
        if (meaning.sourceBookTitle != null)
          Row(
            children: [
              const Icon(Icons.menu_book, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  meaning.sourceBookTitle!,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (meaning.sourceBookTitle != null) const SizedBox(height: 4),
        // Part of speech + Turkish meaning
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meaning.partOfSpeech != null)
              Text(
                '${meaning.partOfSpeech} • ',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            Expanded(
              child: Text(
                meaning.meaningTR,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        // Example sentence (if available)
        if (meaning.exampleSentence != null &&
            meaning.exampleSentence!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '"${meaning.exampleSentence}"',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton(WordDefinition definition) {
    if (_wasAdded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Added',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isAdding ? null : () => _addToVocabulary(definition),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC107), // Yellow/amber
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isAdding
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                ),
              )
            : const Text(
                "I didn't know this",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _addToVocabulary(WordDefinition definition) async {
    if (definition.id == null) return;

    setState(() => _isAdding = true);

    try {
      final userId = ref.read(currentUserProvider).value?.id;
      if (userId == null) return;

      final useCase = ref.read(addWordToVocabularyUseCaseProvider);
      final result = await useCase.call(
        AddWordToVocabularyParams(userId: userId, wordId: definition.id!),
      );

      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add: ${failure.message}')),
            );
          }
        },
        (_) {
          if (mounted) {
            setState(() => _wasAdded = true);
            // Auto close after showing success
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) widget.onClose();
            });
          }
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  String _formatPartOfSpeech(String pos) {
    // Capitalize first letter
    return pos[0].toUpperCase() + pos.substring(1);
  }
}
