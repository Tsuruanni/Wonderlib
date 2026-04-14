import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/word_definition.dart';
import '../../utils/app_icons.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/word_definition_provider.dart';
import '../../utils/ui_helpers.dart';
import '../common/game_button.dart';

/// Duolingo-style popup for word-tap feature.
/// Shows word, pronunciation audio, part of speech, Turkish meaning,
/// and "I didn't know this" button to add to vocabulary.
class ReaderWordTapPopup extends ConsumerStatefulWidget {
  const ReaderWordTapPopup({
    super.key,
    required this.word,
    required this.position,
    required this.onClose,
    this.onPlayAudio,
  });

  final String word;
  final Offset position;
  final VoidCallback onClose;
  /// Callback to play word pronunciation using TTS
  final VoidCallback? onPlayAudio;

  @override
  ConsumerState<ReaderWordTapPopup> createState() => _ReaderWordTapPopupState();
}

class _ReaderWordTapPopupState extends ConsumerState<ReaderWordTapPopup> {
  bool _isAdding = false;
  bool _wasAdded = false;

  @override
  Widget build(BuildContext context) {
    final definitionAsync = ref.watch(wordDefinitionProvider(widget.word));

    // Popup dimensions
    const popupWidth = 280.0;

    // Convert global tap position to local coordinates within this Stack
    final renderBox = context.findRenderObject() as RenderBox?;
    final localPos = renderBox != null
        ? renderBox.globalToLocal(widget.position)
        : widget.position;
    final stackSize = renderBox?.size ?? MediaQuery.of(context).size;

    // Calculate position
    double left = localPos.dx - popupWidth / 2;
    double top = localPos.dy + 20; // Show below the word

    // Adjust if off screen horizontally
    if (left < 16) left = 16;
    if (left + popupWidth > stackSize.width - 16) {
      left = stackSize.width - popupWidth - 16;
    }

    // Show above if not enough space below
    if (top + 200 > stackSize.height - 100) {
      top = localPos.dy - 180;
    }

    return Stack(
      children: [
        // Dismiss overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),

        // Popup card — Duolingo style (white, rounded, bold border)
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: popupWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: definitionAsync.when(
              loading: () => _buildLoading(),
              error: (_, __) => _buildError(),
              data: (definition) => _buildContent(definition),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _buildWordHeader(widget.word),
        const SizedBox(height: 16),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWordHeader(widget.word),
        const SizedBox(height: 12),
        Text(
          'Could not load definition',
          style: GoogleFonts.nunito(
            color: AppColors.neutralText,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildWordHeader(String word) {
    return Row(
      children: [
        Expanded(
          child: Text(
            word,
            style: GoogleFonts.nunito(
              color: AppColors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // Speaker icon
        GestureDetector(
          onTap: widget.onPlayAudio,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: AppIcons.soundOn(size: 20),
          ),
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
        _buildWordHeader(displayWord),

        const SizedBox(height: 12),

        // Meanings list
        if (hasDefinition)
          _buildMeaningsList(definition)
        else
          Text(
            'No definition available',
            style: GoogleFonts.nunito(
              color: AppColors.neutralText,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),

        const SizedBox(height: 14),

        // Action button
        if (hasDefinition && definition.isFromDatabase)
          _buildActionButton(definition),
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
                  const Divider(color: AppColors.neutral, height: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatPartOfSpeech(meaning.partOfSpeech!),
                style: GoogleFonts.nunito(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        // Turkish meaning
        Text(
          meaning.meaningTR,
          style: GoogleFonts.nunito(
            color: AppColors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Example sentence
        if (meaning.exampleSentence != null &&
            meaning.exampleSentence!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '"${meaning.exampleSentence}"',
              style: GoogleFonts.nunito(
                color: AppColors.neutralText,
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
        // Book title
        if (meaning.sourceBookTitle != null)
          Row(
            children: [
              AppIcons.book(size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  meaning.sourceBookTitle!,
                  style: GoogleFonts.nunito(
                    color: AppColors.wasp,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                style: GoogleFonts.nunito(
                  color: AppColors.neutralText,
                  fontSize: 13,
                ),
              ),
            Expanded(
              child: Text(
                meaning.meaningTR,
                style: GoogleFonts.nunito(
                  color: AppColors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        // Example sentence
        if (meaning.exampleSentence != null &&
            meaning.exampleSentence!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '"${meaning.exampleSentence}"',
              style: GoogleFonts.nunito(
                color: AppColors.neutralText,
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
      return GameButton(
        label: 'Added',
        onPressed: null,
        variant: GameButtonVariant.primary,
        fullWidth: true,
        icon: const Icon(Icons.check_rounded),
      );
    }

    if (_isAdding) {
      return GameButton(
        label: "I didn't know this",
        onPressed: null,
        variant: GameButtonVariant.wasp,
        fullWidth: true,
      );
    }

    return GameButton(
      label: "I didn't know this",
      onPressed: () => _addToVocabulary(definition),
      variant: GameButtonVariant.wasp,
      fullWidth: true,
    );
  }

  Future<void> _addToVocabulary(WordDefinition definition) async {
    if (definition.id == null) return;

    setState(() => _isAdding = true);

    try {
      final result = await addWordToVocabulary(ref, definition.id!, immediate: true);

      if (!mounted) return;

      if (result.success) {
        setState(() => _wasAdded = true);
        // Auto close after showing success
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) widget.onClose();
        });
      } else {
        showAppSnackBar(context, 'Failed to add: ${result.errorMessage}', type: SnackBarType.error);
      }
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
