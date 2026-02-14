import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Mixin providing correct/wrong sound effects for inline activities.
///
/// Usage:
/// ```dart
/// class _MyActivityState extends State<MyActivity>
///     with InlineActivitySoundMixin {
///   @override
///   void initState() {
///     super.initState();
///     initSoundPlayer();
///   }
///
///   @override
///   void dispose() {
///     disposeSoundPlayer();
///     super.dispose();
///   }
/// }
/// ```
mixin InlineActivitySoundMixin<T extends StatefulWidget> on State<T> {
  late final AudioPlayer _soundPlayer;

  void initSoundPlayer() {
    _soundPlayer = AudioPlayer();
  }

  void disposeSoundPlayer() {
    _soundPlayer.dispose();
  }

  Future<void> playSound(bool isCorrect) async {
    try {
      await _soundPlayer.setAsset(
        'assets/audio/${isCorrect ? 'correct' : 'wrong'}.mp3',
      );
      await _soundPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }
}
