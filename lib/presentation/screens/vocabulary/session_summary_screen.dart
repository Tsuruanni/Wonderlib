import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/router.dart';
import '../../../domain/entities/system_settings.dart';
import '../../../domain/entities/vocabulary_session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/vocabulary_session_provider.dart';
import '../../utils/app_icons.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/game_button.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({
    super.key,
    required this.listId,
    this.returnRoute,
  });

  final String listId;

  /// When set, "Continue" navigates here instead of popping.
  /// Used by fullscreen learning path to return to the unit page.
  final String? returnRoute;

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  String? _surpriseStat;
  int _comboBonus = 0;

  AudioPlayer? _victoryPlayer;

  @override
  void initState() {
    super.initState();
    _playVictorySound();
    _maybeSurprise();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveSession());
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
    final currentStatus = ref.read(sessionSaveProvider).status;
    if (currentStatus == SessionSaveStatus.saving) return;

    final controller = ref.read(vocabularySessionControllerProvider.notifier);
    final session = ref.read(vocabularySessionControllerProvider);
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) return;

    final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
    final comboBonus = session.maxCombo * settings.comboBonusXp;
    setState(() => _comboBonus = comboBonus);

    final wordResults = controller.buildWordResults();
    final accuracy = session.correctCount + session.incorrectCount > 0
        ? (session.correctCount /
                (session.correctCount + session.incorrectCount)) *
            100
        : 0.0;

    await ref.read(sessionSaveProvider.notifier).save(
          userId: userId,
          listId: widget.listId,
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
        );
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
    final saveState = ref.watch(sessionSaveProvider);
    final saved = saveState.status == SessionSaveStatus.saved;
    final accuracy = session.correctCount + session.incorrectCount > 0
        ? (session.correctCount /
                (session.correctCount + session.incorrectCount)) *
            100
        : 0.0;

    ref.listen<SessionSaveState>(sessionSaveProvider, (prev, next) {
      if (next.status == SessionSaveStatus.error) {
        final detail = next.errorMessage;
        showAppSnackBar(
          context,
          detail != null && detail.isNotEmpty
              ? 'Failed to save session: $detail'
              : 'Failed to save session. Check your connection.',
          type: SnackBarType.error,
          actionLabel: 'Retry',
          onAction: _saveSession,
        );
      }
    });

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final reportSection = _WordStatusList(words: session.words)
        .animate()
        .fadeIn(delay: 800.ms);

    // Trophy + title + button are always centered (full width)
    final headerSection = Column(
      children: [
        const SizedBox(height: 20),
        // Trophy
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
            .shimmer(
                duration: 1200.ms,
                color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(height: 24),
        Text(
          'Session Complete!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 200,
            child: GameButton(
              label: 'Continue',
              onPressed: () {
                    if (widget.returnRoute != null) {
                      context.go(widget.returnRoute!);
                    } else {
                      // Pop back through: summary → session → list detail
                      var count = 0;
                      Navigator.of(context).popUntil((route) {
                        return count++ >= 2;
                      });
                    }
                  },
              variant: GameButtonVariant.primary,
            ),
          ),
        ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
        const SizedBox(height: 32),
      ],
    );

    return PopScope(
      canPop: saved,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header: always centered full width
                headerSection,
                // Stats + Report: side by side on web
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildStatsColumn(session, saveState, accuracy)),
                      const SizedBox(width: 32),
                      Expanded(child: reportSection),
                    ],
                  )
                else ...[
                  _buildStatsColumn(session, saveState, accuracy),
                  const SizedBox(height: 32),
                  reportSection,
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsColumn(
    VocabularySessionState session,
    SessionSaveState saveState,
    double accuracy,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              assetPath: 'assets/icons/gem_outline_256.png',
              label: 'Gems Earned',
              value:
                  '+${saveState.actualXpAwarded ?? (session.xpEarned + _comboBonus)}',
              subtitle: _comboBonus > 0 ? '(+$_comboBonus combo)' : null,
              delay: 500.ms,
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.gps_fixed,
              iconColor: Colors.blue,
              label: 'Accuracy',
              value: '${accuracy.toStringAsFixed(0)}%',
              delay: 600.ms,
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
              delay: 700.ms,
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.timer_outlined,
              iconColor: Colors.teal,
              label: 'Time',
              value: _formatDuration(session.durationSeconds),
              delay: 800.ms,
            ),
          ],
        ),
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
      ],
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
    this.icon,
    this.iconColor,
    this.assetPath,
    required this.label,
    required this.value,
    this.subtitle,
    required this.delay,
  });

  final IconData? icon;
  final Color? iconColor;
  final String? assetPath;
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
            if (assetPath != null)
              Image.asset(assetPath!, width: 28, height: 28, filterQuality: FilterQuality.high)
            else
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
                  color: (iconColor ?? Colors.amber).withValues(alpha: 0.8),
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
                    AppIcons.star(size: 20),
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

