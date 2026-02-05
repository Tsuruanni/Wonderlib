import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/audio_sync_provider.dart';
import '../../providers/reader_provider.dart';

/// Floating audio player controls widget.
/// Shows play/pause, seek bar, speed control, and skip buttons.
class AudioPlayerControls extends ConsumerWidget {
  const AudioPlayerControls({
    super.key,
    required this.settings,
  });

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioSyncControllerProvider);

    // Don't show if no audio is loaded
    if (state.currentBlockId == null) {
      return const SizedBox.shrink();
    }

    final isDark = settings.theme == ReaderTheme.dark;
    final backgroundColor = isDark
        ? const Color(0xFF2D3748)
        : Colors.white;
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF1E293B);
    const accentColor = Color(0xFF4F46E5);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                state.positionFormatted,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProgressBar(
                  progress: state.progress,
                  accentColor: accentColor,
                  trackColor: textColor.withValues(alpha: 0.2),
                  onSeek: (progress) {
                    ref.read(audioSyncControllerProvider.notifier).seekProgress(progress);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.durationFormatted,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Speed button
              _SpeedButton(
                speed: state.playbackSpeed,
                textColor: textColor,
                onPressed: () {
                  ref.read(audioSyncControllerProvider.notifier).cycleSpeed();
                },
              ),

              const SizedBox(width: 16),

              // Skip backward
              _ControlButton(
                icon: Icons.replay_10,
                color: textColor,
                onPressed: () {
                  ref.read(audioSyncControllerProvider.notifier).skipBackward();
                },
              ),

              const SizedBox(width: 8),

              // Play/Pause
              _PlayPauseButton(
                isPlaying: state.isPlaying,
                isLoading: state.isLoading,
                accentColor: accentColor,
                onPressed: () {
                  ref.read(audioSyncControllerProvider.notifier).togglePlayPause();
                },
              ),

              const SizedBox(width: 8),

              // Skip forward
              _ControlButton(
                icon: Icons.forward_10,
                color: textColor,
                onPressed: () {
                  ref.read(audioSyncControllerProvider.notifier).skipForward();
                },
              ),

              const SizedBox(width: 16),

              // Close button
              _ControlButton(
                icon: Icons.close,
                color: textColor.withValues(alpha: 0.5),
                onPressed: () {
                  ref.read(audioSyncControllerProvider.notifier).stop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.onSeek,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;
  final void Function(double) onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) {
            final newProgress = details.localPosition.dx / constraints.maxWidth;
            onSeek(newProgress.clamp(0.0, 1.0));
          },
          onHorizontalDragUpdate: (details) {
            final newProgress = details.localPosition.dx / constraints.maxWidth;
            onSeek(newProgress.clamp(0.0, 1.0));
          },
          child: Container(
            height: 24,
            alignment: Alignment.center,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.accentColor,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.textColor,
    required this.onPressed,
  });

  final double speed;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
