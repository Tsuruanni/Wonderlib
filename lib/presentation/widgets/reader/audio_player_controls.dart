import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/audio_sync_provider.dart';
import '../../providers/reader_provider.dart';

/// Floating audio player controls widget - Gamified "Island" Style
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
    final backgroundColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    const accentColor = Color(0xFF6366F1); // Indigo 500

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed control
            _SpeedButton(
              speed: state.playbackSpeed,
              textColor: textColor,
              onPressed: () {
                ref.read(audioSyncControllerProvider.notifier).cycleSpeed();
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

            // Close button
            _ControlButton(
              icon: Icons.close_rounded,
              color: textColor.withValues(alpha: 0.6),
              onPressed: () {
                ref.read(audioSyncControllerProvider.notifier).stop();
              },
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: -1,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutBack,
    ).fadeIn(duration: 250.ms);
  }
}

class _PlayPauseButton extends StatefulWidget {
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
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: 100.ms,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: 100.ms,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatefulWidget {
  const _SpeedButton({
    required this.speed,
    required this.textColor,
    required this.onPressed,
  });

  final double speed;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  State<_SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<_SpeedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
     return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: 100.ms,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.textColor.withValues(alpha: 0.1)),
          ),
          child: Text(
            '${widget.speed}x',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
