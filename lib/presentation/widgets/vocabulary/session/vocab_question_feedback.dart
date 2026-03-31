import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../domain/entities/vocabulary_session.dart';
import '../../common/feedback_animation.dart';

/// Feedback overlay after answering: green check or red X with correct answer
class VocabQuestionFeedback extends StatefulWidget {
  const VocabQuestionFeedback({
    super.key,
    required this.isCorrect,
    this.correctAnswer,
    this.targetWord,
    this.questionType,
    this.xpGained = 0,
    this.combo = 0,
    this.comboWarning = false,
    this.comboBroken = false,
    required this.onDismiss,
  });

  final bool isCorrect;
  final String? correctAnswer;
  final String? targetWord;
  final QuestionType? questionType;
  final int xpGained;
  final int combo;
  final bool comboWarning;  // First miss: combo preserved but warned
  final bool comboBroken;   // Second miss: combo actually dropped
  final VoidCallback onDismiss;

  @override
  State<VocabQuestionFeedback> createState() => _VocabQuestionFeedbackState();
}

/// Combo milestone thresholds with celebration data
enum _ComboMilestone {
  nice(5, 'NICE STREAK!', Icons.local_fire_department, [Color(0xFFFF8A65), Color(0xFFFF7043)]),
  unstoppable(10, 'UNSTOPPABLE!', Icons.bolt, [Color(0xFFFFB300), Color(0xFFFF8F00)]),
  legendary(15, 'LEGENDARY!', Icons.stars, [Color(0xFFAB47BC), Color(0xFF7B1FA2)]);

  const _ComboMilestone(this.threshold, this.text, this.icon, this.colors);
  final int threshold;
  final String text;
  final IconData icon;
  final List<Color> colors;
}

class _VocabQuestionFeedbackState extends State<VocabQuestionFeedback> {
  Timer? _autoDismissTimer;
  FlutterTts? _tts;

  /// Returns the milestone if combo is exactly at a threshold
  _ComboMilestone? get _comboMilestone {
    if (!widget.isCorrect) return null;
    for (final m in _ComboMilestone.values.reversed) {
      if (widget.combo == m.threshold) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Auto-dismiss for correct answers after delay
    // Longer delay for combo milestones so student can see the celebration
    if (widget.isCorrect) {
      final delay = _comboMilestone != null
          ? const Duration(milliseconds: 3200)
          : const Duration(milliseconds: 2200);
      _autoDismissTimer = Timer(delay, () {
        if (mounted) widget.onDismiss();
      });
    }

    // TTS for wrong "say the word" answers
    if (!widget.isCorrect &&
        widget.questionType == QuestionType.pronunciation &&
        widget.targetWord != null) {
      _tts = FlutterTts();
      _initAndSpeakTts(widget.targetWord!);
    }
  }

  Future<void> _initAndSpeakTts(String word) async {
    await _tts!.setLanguage('en-US');
    if (!mounted) return;
    await _tts!.speak(word);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    // Do NOT call _tts?.stop() — shared platform TTS engine would kill
    // the next question's audio during AnimatedSwitcher transition.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = widget.isCorrect;

    final colorScheme = isCorrect
        ? const ColorScheme.light(
            surface: Color(0xFFD7FFB8),
            onSurface: Color(0xFF58A700),
            primary: Color(0xFF58A700),
            onPrimary: Colors.white,
          )
        : const ColorScheme.light(
            surface: Color(0xFFFFDFE0),
            onSurface: Color(0xFFEA2B2B),
            primary: Color(0xFFEA2B2B),
            onPrimary: Colors.white,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FeedbackAnimation(
                  isCorrect: isCorrect,
                  size: isCorrect ? 60 : 72,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect ? 'Excellent!' : 'Incorrect',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ).animate().fadeIn(duration: 300.ms).moveX(begin: 20, end: 0),
                      if (!isCorrect) ...[
                        if (widget.correctAnswer != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                widget.questionType == QuestionType.imageMatch
                                    ? 'That was: '
                                    : 'Correct answer: ',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  widget.correctAnswer!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.comboWarning) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Careful! x${widget.combo} combo at risk',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().shakeX(duration: 400.ms, hz: 3, amount: 2),
                        ] else if (widget.comboBroken) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department, color: Colors.red.shade400, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Combo broken! x${widget.combo}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 300.ms),
                        ],
                      ] else ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/icons/gem_outline_256.png', width: 20, height: 20, filterQuality: FilterQuality.high),
                                const SizedBox(width: 4),
                                Text(
                                  '+${widget.xpGained}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF58A700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.2, end: 0),
                            if (widget.combo >= 2) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Text(
                                  'COMBO x${widget.combo}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ).animate().scale(curve: Curves.elasticOut),
                            ],
                          ],
                        ),
                        // Combo milestone celebration
                        if (_comboMilestone != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _comboMilestone!.colors,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_comboMilestone!.icon, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _comboMilestone!.text,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(_comboMilestone!.icon, color: Colors.white, size: 20),
                              ],
                            ),
                          ).animate()
                              .fadeIn(duration: 200.ms)
                              .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, curve: Curves.elasticOut),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 12),
              Center(
                child: _GotItButton(onPressed: widget.onDismiss),
              ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _GotItButton extends StatefulWidget {
  const _GotItButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GotItButton> createState() => _GotItButtonState();
}

class _GotItButtonState extends State<_GotItButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const double borderHeight = 4.0;
    final double faceTop = _isPressed ? borderHeight : 0.0;
    final double faceBottom = _isPressed ? 0.0 : borderHeight;

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: 180,
        height: 50 + borderHeight,
        child: Stack(
          children: [
            Positioned(
              left: 0, right: 0,
              top: borderHeight, bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.dangerDark,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeOut,
              left: 0, right: 0,
              top: faceTop,
              bottom: faceBottom,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  'GOT IT',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
