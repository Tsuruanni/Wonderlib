import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/router.dart';
import '../../../domain/entities/system_settings.dart';
import '../../../domain/entities/vocabulary_session.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../../domain/usecases/wordlist/complete_session_usecase.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/daily_quest_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/vocabulary_session_provider.dart';
import '../../utils/ui_helpers.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({
    super.key,
    required this.listId,
  });

  final String listId;

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  bool _saving = false;
  bool _saved = false;
  String? _surpriseStat;
  int? _actualXpAwarded;
  int _comboBonus = 0;

  AudioPlayer? _victoryPlayer;

  @override
  void initState() {
    super.initState();
    _playVictorySound();
    _maybeSurprise();
    _saveSession();
  }

  Future<void> _playVictorySound() async {
    try {
      _victoryPlayer = AudioPlayer();
      await _victoryPlayer!.setAsset('assets/sounds/victory.mp3');
      await _victoryPlayer!.play();
    } catch (_) {
      // Sound is enhancement, not critical
    }
  }

  void _maybeSurprise() {
    // 30% chance of showing a surprise stat
    if (Random().nextDouble() < 0.3) {
      final session = ref.read(vocabularySessionControllerProvider);
      final perfectWords = session.words.where((w) => w.isFirstTryPerfect).toList();
      if (perfectWords.isNotEmpty) {
        final word = perfectWords[Random().nextInt(perfectWords.length)];
        _surpriseStat =
            'You nailed "${word.word}" on every try! Keep it up!';
      }
    }
  }

  Future<void> _saveSession() async {
    if (_saving) return;
    setState(() => _saving = true);

    final controller = ref.read(vocabularySessionControllerProvider.notifier);
    final session = ref.read(vocabularySessionControllerProvider);
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
    final comboBonus = session.maxCombo * settings.comboBonusXp;
    setState(() => _comboBonus = comboBonus);

    final wordResults = controller.buildWordResults();
    final accuracy = session.correctCount + session.incorrectCount > 0
        ? (session.correctCount /
                (session.correctCount + session.incorrectCount)) *
            100
        : 0.0;

    final result = await ref.read(completeSessionUseCaseProvider).call(
          CompleteSessionParams(
            userId: userId,
            wordListId: widget.listId,
            totalQuestions: session.totalQuestionsAnswered,
            correctCount: session.correctCount,
            incorrectCount: session.incorrectCount,
            accuracy: accuracy,
            maxCombo: session.maxCombo,
            xpEarned: session.xpEarned + comboBonus,
            durationSeconds: session.durationSeconds,
            wordsStrong: controller.wordsStrongCount,
            wordsWeak: controller.wordsWeakCount,
            firstTryPerfectCount: controller.firstTryPerfectCount,
            wordResults: wordResults,
          ),
        );

    result.fold(
      (failure) {
        debugPrint('Failed to save session: ${failure.message}');
        if (mounted) {
          setState(() => _saving = false); // Allow retry
          showAppSnackBar(
            context,
            'Failed to save session. Check your connection.',
            type: SnackBarType.error,
            actionLabel: 'Retry',
            onAction: _saveSession,
          );
        }
      },
      (savedResult) {
        if (!mounted) return;
        // Invalidate progress providers so learning path + detail screen update
        ref.invalidate(progressForListProvider(widget.listId));
        ref.invalidate(userWordListProgressProvider);
        ref.invalidate(wordListsWithProgressProvider);
        ref.invalidate(learningPathProvider);
        // Invalidate wordbank providers so Word Bank sees updated words
        ref.invalidate(userVocabularyProgressProvider);
        ref.invalidate(learnedWordsWithDetailsProvider);
        // Refresh user state so XP/level updates in navbar + triggers level-up celebration
        ref.read(userControllerProvider.notifier).refreshProfileOnly();
        // Invalidate leaderboard so rank reflects new XP
        ref.invalidate(leaderboardEntriesProvider);
        // Refresh daily quest progress (vocab_session quest)
        ref.invalidate(dailyQuestProgressProvider);
        // Complete any vocabulary assignments for this word list
        _completeVocabularyAssignment(accuracy);
        setState(() {
          _saved = true;
          _actualXpAwarded = savedResult.xpEarned;
        });
      },
    );
  }

  Future<void> _completeVocabularyAssignment(double accuracy) async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final getActiveAssignmentsUseCase = ref.read(getActiveAssignmentsUseCaseProvider);
      final result = await getActiveAssignmentsUseCase(
        GetActiveAssignmentsParams(studentId: userId),
      );

      final assignments = result.fold(
        (failure) => <StudentAssignment>[],
        (assignments) => assignments,
      );

      for (final assignment in assignments) {
        if (assignment.wordListId == widget.listId &&
            assignment.status != StudentAssignmentStatus.completed) {
          final completeAssignmentUseCase = ref.read(completeAssignmentUseCaseProvider);
          await completeAssignmentUseCase(CompleteAssignmentParams(
            studentId: userId,
            assignmentId: assignment.assignmentId,
            score: accuracy,
          ),);
          ref.invalidate(studentAssignmentsProvider);
          ref.invalidate(activeAssignmentsProvider);
          ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
    } catch (e) {
      debugPrint('Assignment completion failed: $e');
    }
  }

  @override
  void dispose() {
    _victoryPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(vocabularySessionControllerProvider);
    final accuracy = session.correctCount + session.incorrectCount > 0
        ? (session.correctCount /
                (session.correctCount + session.incorrectCount)) *
            100
        : 0.0;

    return PopScope(
      canPop: _saved,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Trophy Animation
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade300, Colors.amber.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events, size: 56, color: Colors.white),
                )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .then(delay: 200.ms)
                .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5)),

                const SizedBox(height: 24),
                
                Text(
                  'Session Complete!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),

                const SizedBox(height: 32),

                // Stats grid
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.monetization_on,
                      iconColor: Colors.amber,
                      label: 'Coins Earned',
                      value: '+${_actualXpAwarded ?? (session.xpEarned + _comboBonus)}',
                      subtitle: _comboBonus > 0 ? '(+$_comboBonus combo)' : null,
                      delay: 400.ms,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.gps_fixed,
                      iconColor: Colors.blue,
                      label: 'Accuracy',
                      value: '${accuracy.toStringAsFixed(0)}%',
                      delay: 500.ms,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: Colors.deepOrange,
                      label: 'Max Combo',
                      value: 'x${session.maxCombo}',
                      delay: 600.ms,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.timer_outlined,
                      iconColor: Colors.teal,
                      label: 'Time',
                      value: _formatDuration(session.durationSeconds),
                      delay: 700.ms,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Per-word status
                _WordStatusList(words: session.words)
                    .animate().fadeIn(delay: 800.ms),

                // Surprise stat
                if (_surpriseStat != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withValues(alpha: 0.1),
                          Colors.blue.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _surpriseStat!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1000.ms).scale(),
                ],

                const SizedBox(height: 48),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      context.go(AppRoutes.vocabulary);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ).animate().fadeIn(delay: 1200.ms).moveY(begin: 40, end: 0),


                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    required this.delay,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: iconColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: delay).moveX(begin: 20, end: 0, curve: Curves.easeOut),
    );
  }
}

class _WordStatusList extends StatelessWidget {
  const _WordStatusList({required this.words});
  final List<WordSessionState> words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Report',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...words.map((word) {
            final status = word.resultStatus;
            Color statusColor;
            IconData statusIcon;

            switch (status) {
              case WordResultStatus.strong:
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
              case WordResultStatus.medium:
                statusColor = Colors.orange;
                statusIcon = Icons.warning_rounded;
              case WordResultStatus.weak:
                statusColor = Colors.red;
                statusIcon = Icons.cancel_rounded;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          word.meaningTR,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (word.isFirstTryPerfect) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

